---
title: "Hooking into the Go Toolchain"
description: "How go build -toolexec lets us time, rewrite and instrument every compiler and linker run, from a small stopwatch to OpenTelemetry's otelc."
date: 2026-10-01T00:00:00Z
publishDate: 2026-10-05T00:00:00Z
categories:
  - deep-dive
tags:
  - blog
  - go
  - toolchain
  - toolexec
  - compile-time-instrumentation
  - opentelemetry
  - otelc
showToc: true
tocOpen: false
draft: true
promote: false
substack: false
---

Today we're going to take a look at the Go toolchain, and more specifically at
how we can take part in the compilation process with our own code. We won't
patch the compiler. We'll stand right next to it while it works, watch what it
does, and every now and then hand it something it didn't ask for.

The way in is a single flag, and the cheapest experiment I know looks like this:

```console
$ go build -a -o /tmp/app -toolexec=/usr/bin/time ./app
# internal/unsafeheader
        0.02 real         0.00 user         0.00 sys
# internal/goarch
        0.03 real         0.00 user         0.00 sys
# internal/coverage/rtcov
        0.02 real         0.00 user         0.00 sys
...
```

Each of those little `real user sys` receipts is one program the `go` command
ran on our behalf. For this small program there are 108 of them: 59 compiler
runs, 48 assembler runs and one linker run. `-toolexec` tells `go build` to run
each of those programs through a program we pick, and here we picked
`/usr/bin/time`, which makes it a stopwatch.

Timing wasn't the plan, though. Russ Cox
[added the flag in January 2015](https://github.com/golang/go/commit/83c10b204d619d18100716c9588404200acdf6e0)
so the toolchain could run under tools like valgrind, or with a stashed copy of
the compiler swapped in by toolstash, a tool he wrote for working on the
compiler itself. A few weeks later toolstash learned to time every command it
ran. Years afterwards he described `-toolexec=time` as
["an accident - a mostly happy one"](https://github.com/golang/go/issues/27628#issuecomment-702251208).
This post is about that happy accident, a corner of Go that Daniel Martí once
called
["a space that hasn't been explored much so far"](https://golab.io/talks/diving-into-the-go-toolchain-to-obfuscate-builds).
He had been exploring it with [garble](https://github.com/burrowers/garble), an
obfuscator, and his work turns up all over this post.

We'll follow the stopwatch the whole way. First we'll build our own. Then we'll
teach it to rewrite code before the compiler sees it, sneak in packages the
build never asked for, and call code it isn't allowed to import. Along the way
the build cache will lie to us. At the end we'll look at
[otelc](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation),
a real tool that does all of this for a living, and time it with the same
stopwatch.

Thanks to Jesús for inviting me. His
[series on the Go compiler](https://internals-for-interns.com/series/understanding-the-go-compiler/)
explains what the compiler does with our code; today is about how we get
between the `go` command and the compiler in the first place. Full disclosure:
I work at Datadog and help maintain otelc, so keep that in mind for the last
part. All the code we'll write lives in a
[companion repository](https://github.com/kakkoyun/hooking-into-the-go-toolchain).

## What `go build` actually runs

We can get in front of every step of the build. Great! But what are those
steps? If we run `go build` with `-x`, it narrates every command it runs, and
`-a` makes sure it rebuilds everything instead of reusing the cache:

```console
$ go build -a -x -o /tmp/app ./app
...
$GOROOT/pkg/tool/darwin_arm64/compile -o $WORK/b001/_pkg_.a -trimpath "$WORK/b001=>" \
    -p main -lang=go1.25 -complete -buildid kIewNeZLieJMDX0sK6uO/kIewNeZLieJMDX0sK6uO \
    -goversion go1.27.1 -c=16 -shared -nolocalimports \
    -importcfg $WORK/b001/importcfg -pack ./app/main.go
...
$GOROOT/pkg/tool/darwin_arm64/link -o $WORK/b001/exe/a.out \
    -importcfg $WORK/b001/importcfg.link -buildmode=pie ... $WORK/b001/_pkg_.a
```

That's almost 800 lines for our little program, so I've kept just two of them.
The first compiles our `main` package. The compiler gets the package path
(`-p main`), the list of `.go` files at the end, and a file passed with
`-importcfg`. The second line, the last step of the build, links everything
into a binary.

In other words, `go build` is running a lot of compile commands and linking the results
together at the end. That makes sense, but how does it know what needs to be
compiled, and what goes into the link? The build is actually a graph of
actions, one or more per package, and each action gets its own numbered
directory under `$WORK`, a temporary directory the `go` command creates for the
build. `b001` is our `main` package. Before running the compiler, the `go`
command writes that `importcfg` file into the action's directory. For our
package it looks like this:

```text
# import config
packagefile bytes=$WORK/b002/_pkg_.a
packagefile fmt=$WORK/b042/_pkg_.a
packagefile github.com/kakkoyun/hooking-into-the-go-toolchain/greet=$WORK/b060/_pkg_.a
packagefile os=$WORK/b049/_pkg_.a
packagefile time=$WORK/b054/_pkg_.a
packagefile runtime=$WORK/b009/_pkg_.a
```

One line for each package `main.go` imports, plus `runtime`, each pointing at
the compiled archive of that package. That's the compiler's whole view of the
outside world. It doesn't search a `GOPATH` or read `go.mod`; if a package isn't
in this file, it doesn't exist. (If you're curious what's inside those
archives, Jesús's post on the
[unified IR format](https://internals-for-interns.com/posts/go-compiler-unified-ir/)
opens one up.) The linker gets a similar file listing every package in the
program. Keep the `importcfg` in mind, because it's going to bite us later.

Most of the other lines in that log are the `go` command doing things itself,
like writing those files, creating directories or copying archives around. The
lines that matter to us start a tool from `$GOROOT/pkg/tool/` (`compile`, `asm`
and `link`), and those are exactly the lines `-toolexec` steps into. This is how
`go help build` describes the flag:

```text
-toolexec 'cmd args'
	a program to use to invoke toolchain programs like vet and asm.
	For example, instead of running asm, the go command will run
	'cmd args /path/to/asm <arguments for asm>'.
	The TOOLEXEC_IMPORTPATH environment variable will be set,
	matching 'go list -f {{.ImportPath}}' for the package being built.
```

And that's the entire interface. Our program receives the tool's path as its
first argument and the tool's arguments after it, and it can do whatever it
likes before, after or instead of running the tool. The `TOOLEXEC_IMPORTPATH`
variable tells it which package is being built. That one is
[Daniel's work too](https://github.com/golang/go/commit/de74ea5d740ccc69dbb146578dc8a965351a3d6b),
added in Go 1.16; before that, wrappers had to guess the package from the flags.

## Building our own stopwatch

`/usr/bin/time` gives us numbers, but it doesn't tell us which package each
number belongs to. Let's write a wrapper that does. The heart of it is small:

```go
func main() {
	tool, args := os.Args[1], os.Args[2:]

	cmd := exec.Command(tool, args...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr

	// ... forward SIGINT, SIGTERM, SIGHUP and SIGQUIT to the tool ...
	start := time.Now()
	if err := cmd.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "stopwatch: %v\n", err)
		os.Exit(1)
	}
	err := cmd.Wait()
	logLine(tool, args, time.Since(start)) // appends to $STOPWATCH_LOG
	os.Exit(exitCode(err))
}
```

It runs the real tool with the same standard input and output, measures how
long it took, and appends one line to a log file: the tool, the import path, the
milliseconds. Then it exits with the tool's own status, so `go build` never
notices we're there.

Let's build it and point `go build` at it:

```console
go build -o .bin/stopwatch ./cmd/stopwatch
STOPWATCH_LOG=/tmp/sw.tsv go build -a -o /tmp/app -toolexec=$PWD/.bin/stopwatch ./app
```

Counting the lines in the log by tool, and sorting the compiles by time, gives
us this:

```text
tool           runs    -V=full
asm              48          1
compile          59          1
link              1          1

    ms  package
   860  runtime
   379  reflect
   261  internal/abi
   230  syscall
   195  math
```

No surprise that `runtime` is the slowest package to compile. (Don't add the
milliseconds up and call it the build time, though: the tools ran in parallel,
so their sum is larger than the time we actually waited.)

The interesting part is the last column of the first table. Before building
anything, the `go` command ran each tool once with a single argument,
`-V=full`, and it did that through our wrapper. In our log it looks like this:

```text
compile | - | 8 | -V=full
```

That's the `go` command asking each tool "who are you?". The compiler answers
`compile version go1.27.1`, and that answer becomes the tool's ID. The ID ends
up in the cache key of every package the tool compiles. That key, the action
ID, is a hash of the package's source files, its flags, the tool ID and what
its dependencies produced. Notice what isn't in it: the `-toolexec` flag itself.

Why ask the wrapper instead of just reading the compiler binary? The
[`go` command's source](https://github.com/golang/go/blob/go1.27.1/src/cmd/go/internal/work/buildid.go#L115-L185)
explains: "we want '-toolexec toolstash' to continue working". If a wrapper
swaps in a different compiler, the cache key should know.

Here's the whole picture, from the `-V=full` question to the cache:

![go build asks the stopwatch for each tool's -V=full answer, which becomes the tool ID; each package's action ID is a hash of its sources, flags, the tool ID and its dependencies; on a cache hit the archive is reused and nothing is logged, on a miss the stopwatch runs the real compile, asm or link and logs the call](/uploads/hooking-into-the-go-toolchain-stopwatch.png)

This has a funny consequence for our wrapper: its standard output isn't really
ours anymore. During that `-V=full` question, stdout *is* the answer. Since Go
1.10 the `go` command
[ignores whatever a tool prints to stderr](https://github.com/golang/go/issues/22588)
while answering, as long as stdout has the right line, but stdout gets no such
pass. If our stopwatch says hello on stdout before running the tool, the build
stops right there:

```text
go: parsing buildID from go tool compile -V=full: unexpected output:
	stopwatch: starting compile
compile version go1.27.1
```

If it prints after the tool instead, things get sneakier. The build works, but
our log line contains a millisecond count, so the answer, and with it the tool
ID, changes on every build. A second build recompiles all 59 packages again,
and nothing tells us why.

Our well-behaved wrapper writes only to its log file. Let's run the build
again, without `-a` this time, and look at the log:

```text
compile | - | 6 | -V=full
asm | - | 4 | -V=full
link | - | 5 | -V=full
```

Three questions and nothing else. Every package came straight from the cache,
so no tool ran and our stopwatch had nothing to time. A `-toolexec` wrapper only
sees what the cache lets through. Hold on to that thought; it'll come back.

## Rewriting code before the compiler sees it

Now that we're sitting between the `go` command and the compiler, we can do
more than watch. The compiler gets its source files as arguments, and we see
those arguments first. What if we handed it different files?

Changing Go source from a program sounds scary, but Go makes it surprisingly
friendly. The compiler has its own parser, the one Jesús takes apart in his
[parser post](https://internals-for-interns.com/posts/the-go-parser/), but the
standard library ships a second set of packages just for tools:
[`go/token`](https://pkg.go.dev/go/token) keeps track of positions,
[`go/parser`](https://pkg.go.dev/go/parser) turns source into a syntax tree,
[`go/ast`](https://pkg.go.dev/go/ast) describes every node in that tree, and
[`go/printer`](https://pkg.go.dev/go/printer) and
[`go/format`](https://pkg.go.dev/go/format) turn a tree back into code. These are
the packages
[`gofmt` is built on](https://github.com/golang/go/blob/go1.27.1/src/cmd/gofmt/gofmt.go#L12-L16),
and `go vet`'s checks run on them through the
[analysis framework](https://pkg.go.dev/golang.org/x/tools/go/analysis) that
most Go linters use. If you've ever written a linter, you've already done the
first half of what we need: find the code you care about. As Jesús puts it at
the end of his post, many Go developers use `go/ast`
["to parse Go code programmatically and build powerful tools"](https://internals-for-interns.com/posts/the-go-parser/#using-the-ast-in-your-own-code).

That's exactly what our second toy wrapper, `toyhook`, does. It looks for functions
marked with a `//demo:log` comment, like this one in our app:

```go
//demo:log
func countLines(path string) int {
	data, err := os.ReadFile(path)
	...
```

Finding them takes the same three steps every linter starts with: parse the
file, walk the tree, and check each node. Trimmed down a little, the heart of
`toyhook` looks like this:

```go
fset := token.NewFileSet()
file, err := parser.ParseFile(fset, abs, src, parser.ParseComments)
if err != nil {
	return nil, 0, err
}

for _, decl := range file.Decls {
	fn, ok := decl.(*ast.FuncDecl)
	if !ok || fn.Body == nil || !hasDirective(fn) {
		continue
	}
	lbrace := fset.Position(fn.Body.Lbrace)
	// ... insert our statement right after lbrace.Offset ...
}
```

`parser.ParseFile` reads the file into an `*ast.File`, and `ParseComments`
asks it to keep the comments, which we need because our marker is one. Then we
loop over the file's top-level declarations, keep the functions, and
`hasDirective` checks each function's doc comment for `//demo:log`. The
`token.FileSet` is what turns a node back into a file, line and byte offset, so
`lbrace` tells us exactly where the function's opening brace is.

Now we need to add our log statement. The textbook way is to build it as more
tree: every call, identifier and literal becomes a struct, and we splice them
into the function body. It works, but it's wordy. Here's just `start :=
time.Now()` as AST nodes, from the
[injector I wrote for a talk](https://github.com/kakkoyun/otel-night-berlin-2026/blob/65fc5bb0559331235704dc5707e165175f8c28a2/demo/toolchain/cmd/loginjector/main.go#L113-L124):

```go
startDecl := &ast.AssignStmt{
	Lhs: []ast.Expr{ast.NewIdent("start")},
	Tok: token.DEFINE,
	Rhs: []ast.Expr{
		&ast.CallExpr{
			Fun: &ast.SelectorExpr{
				X:   ast.NewIdent("time"),
				Sel: ast.NewIdent("Now"),
			},
		},
	},
}
```

That injector ended up at 306 lines for two log statements. Printing the tree
back out has a catch too: as the [dst README](https://github.com/dave/dst#readme)
explains, `go/ast` comments "are stored by their byte offset instead of attached
to nodes, so re-arranging nodes breaks the output". That's why serious tools
like otelc rewrite with dst, which keeps comments attached to the nodes they
belong to.

Our toy takes a shortcut. It uses the tree only to find where each marked
function's body starts, and inserts the new statement as plain text right after
that brace, so every byte we didn't touch stays where it was. When the compile
for our package comes through, `toyhook` writes the result into the action's own
`$WORK` directory, which it finds from the compiler's `-o` flag, swaps the new
file into the argument list, and runs the real compiler. Let's build it and use
it the same way as the stopwatch:

```console
go build -o .bin/toyhook ./cmd/toyhook
TOYHOOK_MODE=rewrite go build -o /tmp/app -toolexec=$PWD/.bin/toyhook ./app
```

Here's the difference between what we wrote and what the compiler actually
gets:

```diff
--- app/main.go
+++ $WORK/b001/main.go
@@ -21,6 +21,8 @@
 //
 //demo:log
 func countLines(path string) int {
+	fmt.Fprintf(os.Stderr, "→ %s at %s\n", "countLines", time.Now().Format(time.TimeOnly))
+//line $REPO/app/main.go:24
 	data, err := os.ReadFile(path)
 	if err != nil {
 		fmt.Fprintln(os.Stderr, err)
```

And the program now narrates itself:

```text
hello, toolchain
→ countLines at 14:17:40
go.mod has 3 lines
done in 0s
```

The second line we inserted, the `//line` comment, is easy to miss but
important. It's a
[compiler directive](https://github.com/golang/go/blob/go1.27.1/src/cmd/compile/doc.go#L184-L196)
that resets the file name and line number, so compiler errors, panics and
stack traces after our insertion still point at `app/main.go:24`, and not at a
temporary file that's long gone by the time anyone reads the error. Without it,
every line below our insertion would be off by one, which is a great way to
make people distrust instrumentation.

The wrapper is called for every package in the build, but it only rewrites
one; for the other 58 compiles it gets out of the way and runs the compiler
untouched. Each call is a fresh process that sees a single package, and it can
only change the files of that package. That limitation is exactly what the
next two experiments run into.

## Packages the build never asked for

Our app already imported `fmt`, `os` and `time`, so the code we inserted only
used packages the compiler knew about. Let's get more ambitious and log with
`log/slog`, which our app never imports. With `TOYHOOK_MODE=slog`, `toyhook`
adds the import and the call, and the compiler says:

```text
$WORK/b001/main.go:3:8: could not import log/slog (open : no such file or directory)
```

Remember the `importcfg`? The `go` command wrote it from the imports in the
*original* file, before it ever called us. The compiler looks up `log/slog` in
that file, finds nothing, and tries to open an empty path.

Every tool that adds imports hits this wall. Julio Guerra
[asked about it in 2019](https://github.com/golang/go/issues/35204), and Ian
Lance Taylor's [answer](https://github.com/golang/go/issues/35204#issuecomment-547168404)
was that "the `-toolexec` option is not powerful enough to
support arbitrary source code rewriting." Julio
[did it anyway](https://github.com/golang/go/issues/35204#issuecomment-633996403),
and so will we.

The trick is to write the missing lines ourselves. The `go` command will happily
tell us where the compiled archive of any package lives:

```console
go list -deps -export -f '{{if .Export}}packagefile {{.ImportPath}}={{.Export}}{{end}}' log/slog
```

With `TOYHOOK_IMPORTCFG=patch`, `toyhook` adds the lines the compiler's
`importcfg` is missing. Then, when the link command comes through at the end of
the build, it does the same for the linker's file. That's a separate process,
so `toyhook` saves the `go list` answer in a small state directory the first
time and reads it back here. The linker needs those lines too, because it needs
every package that ends up in the binary, including all of `log/slog`'s own
dependencies. The compiler's file
grows from 7 to 79 lines, the linker's from 60 to 80, and our program logs
through `slog`:

```text
hello, toolchain
2026/10/01 14:17:52 INFO enter func=countLines
go.mod has 3 lines
done in 2ms
```

One thing to be careful about: that `go list` call runs in the middle of our
build. If it inherits our `-toolexec`, through `GOFLAGS` for example, it goes
through our wrapper too, and a wrapper that runs `go list` again from there
calls itself forever. `toyhook` clears `GOFLAGS` before calling it.

## Calling code you are not allowed to import

Until now we've only touched our own package. Real instrumentation has to reach
code we didn't write. Let's make every call to `os.ReadFile`, in the
standard library, report to a function in our own module:

```go
package hooks

func OnReadFile(name string) {
	fmt.Fprintf(os.Stderr, "hooks.OnReadFile(%q)\n", name)
}
```

Here's the problem: package `os` can't import `hooks`. `hooks` imports `fmt`,
`fmt` imports `os`, and Go doesn't allow import cycles. No amount of
`importcfg` patching gets us around that.

The way out is `//go:linkname`. It's a
[compiler directive](https://github.com/golang/go/blob/go1.27.1/src/cmd/compile/doc.go#L268-L300)
that tells the compiler "this name refers to a symbol defined somewhere else",
and leaves it to the linker to connect the two. That's our way in. With
`TOYHOOK_MODE=linkname`, `toyhook` adds one generated file to the compile of
`os`:

```go
package os

import _ "unsafe"

//go:linkname toyhookOnReadFile github.com/kakkoyun/hooking-into-the-go-toolchain/hooks.OnReadFile
func toyhookOnReadFile(name string)
```

This declares a function with no body, and the `//go:linkname` comment says its
body lives in our `hooks` package. Then `toyhook` inserts a call to it at the
top of `ReadFile`, the same way we did with `countLines`:

```diff
 func ReadFile(name string) ([]byte, error) {
+	toyhookOnReadFile(name)
+//line $GOROOT/src/os/file.go:872
 	f, err := Open(name)
```

And our app, which reads its own `go.mod`, now reports every read:

```text
hello, toolchain
hooks.OnReadFile("go.mod")
go.mod has 3 lines
done in 0s
```

The standard library just called into our module without importing it. A
couple of things had to go right for that. First, `os` had to be compiled again,
since standard library packages come from the cache like everything else, so
we build with `-a`. Second, `hooks` had to end up in the binary at all.
Nothing imports it, so the linker has no reason to include it, and without help
the build fails:

```text
os.ReadFile: relocation target github.com/kakkoyun/hooking-into-the-go-toolchain/hooks.OnReadFile not defined
```

The fix is a blank import, `import _ ".../hooks"`, in a file of our `main`
package. This is why instrumentation tools generate a file for your `main`
package.

If you've heard that Go 1.23
[locked down `//go:linkname`](https://go.dev/doc/go1.23#linker), don't worry:
that rule stops code from reaching *into* standard-library internals that
aren't marked for it.
We're going the other way, from the standard library out to a package we own,
and the linker leaves that alone.

## The cache will lie to you

Let's go back to the `/usr/bin/time` build from the beginning of the post, and
run a plain build afterwards, in the same cache and without `-toolexec`:

```console
$ go build -o /tmp/app ./app
# internal/godebugs
        0.01 real         0.00 user         0.00 sys
# internal/coverage/rtcov
        0.01 real         0.00 user         0.00 sys
...
```

It prints all 108 timing receipts again, even though nothing was timed this
time.

What happened? The `go` command saves a tool's output together with its cache
entry, and replays it whenever it reuses that entry. Cherry Mui
[reported exactly this case](https://github.com/golang/go/issues/27628) in
2018, using `-toolexec=/usr/bin/time`, and the issue is still open. Our
stopwatch only escapes it because it writes to a file.

Replayed timings are just noise. Replayed object code is a real problem.
Remember that the cache key contains the tool ID, but not the `-toolexec` flag.
What happens, then, if our wrapper changes what the compiler produces, but answers
`-V=full` exactly like the real compiler?

Our demo has a small package, `greet`, shared by two programs, `app` and
`other`. Let's build `app` with `toyhook` rewriting `greet`, and then build
`other` the normal way, without any wrapper, in the same cache:

```console
$ export GOCACHE=$(mktemp -d)   # keep the poisoned entries out of your real cache
$ TOYHOOK_MODE=rewrite TOYHOOK_TARGET=github.com/kakkoyun/hooking-into-the-go-toolchain/greet \
    go build -o /tmp/app -toolexec=$PWD/.bin/toyhook ./app
$ go build -o /tmp/other ./other && /tmp/other
→ Hello at 14:18:08
hello, other
```

`other` was never built with `-toolexec`, and it's instrumented anyway. Both
builds computed the same cache key for `greet`, from the same sources, the same
flags and the same tool ID, so the plain build happily reused our rewritten
version. Build them in the opposite order and it's just as wrong, the other way
around: the plain build fills the cache first, `toyhook` is never even called
for `greet`, and `app` ends up with no instrumentation at all. There's the thought we held on
to earlier: a wrapper only sees what the cache lets through. And the `toyhook`
we've been using all along has exactly this flaw.

Daniel ran into this while building garble. In 2020 he
[proposed a way](https://github.com/golang/go/issues/41145) for `-toolexec`
tools to opt into caching, and Russ
[replied](https://github.com/golang/go/issues/41145#issuecomment-694612401) that
"the tool that is altering the
behavior of the compiler should be responsible for altering the -V=full output
as well". Daniel withdrew the proposal, and that's exactly what garble does. Its
[answer to the question](https://github.com/burrowers/garble/blob/v0.18.0/hash.go#L56-L90)
is the compiler's own answer with a garble hash appended:

```go
fmt.Printf("%s +garble buildID=_/_/_/%s\n", line, encodeBuildIDHash(contentID))
```

`toyhook` can do the same thing. With `TOYHOOK_MARK=1`, it appends a shorter
marker, a hash of its own settings:

```text
compile version go1.27.1 toyhook@v1/0e25ba9b
```

The answer is different, so the tool ID is different, so every cache key is
different, and `other` stays clean whichever order we build in. Every tool built
this way depends on that one line. Daniel later said that what garble does
there "is in
[undocumented territory](https://github.com/golang/go/issues/41145#issuecomment-2405558244)".

## From toy to tool: otelc

Everything `toyhook` does, badly and for one package at a time, otelc does for
a whole program. It's OpenTelemetry's compile-time instrumentation tool for Go,
built by a special interest group that
[Alibaba, Datadog and Quesma started together](https://opentelemetry.io/blog/2025/go-compile-time-instrumentation/)
in January 2025.

Let's point it at a small HTTP server that has no OpenTelemetry code at all. Its
`/hello` handler calls `/world` on the same server, so one request makes two
hops. We build it by putting `otelc` in front of the usual command:

```console
otelc go build -o hello .
```

That one command does its work in two phases. First, otelc does a dry run of
the build with `go build -a -x -n`, which prints the same narration we read at
the start without running anything, so it can see which packages are going to
be compiled and match its rules against them. Then it runs the real build with
itself as the `-toolexec` wrapper, rewriting the packages that matched.

![otelc go build runs in two phases: setup takes a build lock, backs up go.mod, does a dry run of the build, adds the hook modules, matches rules and generates otelc.runtime.go; instrument runs go build with otelc as -toolexec, marks the -V=full answer, rewrites matched packages and patches the link; finally go.mod is restored](/uploads/hooking-into-the-go-toolchain-otelc-phases.png)

If we run the server and send it a single request, we get three spans, all in
the same trace:

```text
GET /hello   server  trace f6411a6c…  span 26d028cb…  parent (root)
GET          client  trace f6411a6c…  span 6db51783…  parent 26d028cb…
GET /world   server  trace f6411a6c…  span edab8b01…  parent 6db51783…
```

The incoming `/hello` request, the outgoing call to `/world`, and `/world`
itself, each pointing at its parent. Nobody wrote a line of tracing code. otelc
keeps its `$WORK` directory around, so we can open it and see what it did to
`net/http`:

```go
func (sh serverHandler) ServeHTTP(rw ResponseWriter, req *Request) {
	//line <generated>:1
	if hookContext4219161129, _ := OtelBeforeTrampoline_ServeHTTP4219161129(&sh, &rw, &req); false {
	} else {
		defer OtelAfterTrampoline_ServeHTTP4219161129(hookContext4219161129)
	}
	//line server.go:3405:2
	handler := sh.srv.Handler
	...
```

This is the method the standard library's HTTP server runs for every request,
and it now calls a "before" function on the way in and defers an "after"
function for the way out. Those functions reach a hook package through the same
`//go:linkname` trick we used for `os.ReadFile`, and the hooks themselves are
ordinary Go: the before hook starts a server span, and the after hook ends it.

The call doesn't go straight to the hook, though. It goes through a small
generated function called a trampoline, which builds the hook's context and
catches any panic, so a broken hook can't take the request down with it. One
request through the instrumented method looks like this:

![Sequence diagram: the caller calls serverHandler.ServeHTTP, which calls the before trampoline; the trampoline calls the BeforeServeHTTP hook through //go:linkname and returns the hook context, recovering any panic; the original body runs; the deferred after trampoline calls the AfterServeHTTP hook before returning to the caller](/uploads/hooking-into-the-go-toolchain-trampoline.png)

That odd `if …; false {} else { defer … }` shape is deliberate too. In general
a hook can tell otelc to skip the original function entirely. When a hook
doesn't need that, otelc rewrites the condition to `false` and leaves the rest
to the compiler's dead code elimination, one of the SSA passes Jesús walks
through in his [SSA post](https://internals-for-interns.com/posts/the-go-ssa/),
which reduces the whole thing to a plain call and a `defer`.

The rest of our toy's tricks are in there too. otelc patches the `importcfg`
files, and the trampolines it generates
[don't import anything at all](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/instrument/trampoline.go#L60-L71),
for exactly the reason we ran into earlier. It answers the `-V=full` question
with its own marker, so instrumented builds never share cache entries with
plain ones:

```text
compile version go1.27.1 otelc@v1.1.0/55ec54fb480c0c69
```

The suffix is a hash of the rules that matched, so changing a rule changes
every cache key as well. And remember our `//demo:log` toy? In otelc, that
whole wrapper becomes a rule in a YAML file:

```yaml
demo_log:
  target: main
  where:
    directive: "demo:log"
  do:
    - expand_directive:
        template: |-
          start := time.Now()
          slog.Info("function entry", "func", "{{ .FuncName }}")
          defer func() {
            slog.Info("function exit", "func", "{{ .FuncName }}",
              "duration", time.Since(start))
          }()
  imports:
    slog: "log/slog"
    time: "time"
```

Look at the `imports` block at the bottom: that's our `importcfg` problem,
solved with three lines of configuration. We build with
`otelc --rules log.otelc.yml go build`, call the handler, and get:

```text
2026/10/01 14:28:30 INFO function entry func=world
2026/10/01 14:28:30 INFO function exit func=world duration=232.041µs
```

My favourite rules reach into the runtime itself. One adds two fields to the
runtime's goroutine struct, and another copies them every time a new goroutine
starts. That way the trace context follows `go` statements even when nobody
passes a `context.Context` along. Two small fields in a struct we were never
meant to touch, all from a wrapper sitting in front of the compiler.

## Back to the stopwatch

We started with a stopwatch, so let's use it one last time. Here's a full
rebuild of our HTTP server, with no wrapper, with our stopwatch, and with otelc:

```text
plain, no wrapper:    real 5.97 s
plain, stopwatch:     real 5.76 s
otelc --stats:        real 18.16 s
```

It's one run on one machine, so take the exact numbers with a pinch of salt;
the stopwatch run even came out faster than the plain one. Starting an extra
process for every tool call is cheap next to running a compiler, so a wrapper
costs us almost nothing.

otelc takes about three times as long, but it isn't building the same program.
The instrumented server pulls in the OpenTelemetry SDK, so the build compiles
511 compiler runs instead of 188. And look at that `--stats` flag: it's a hidden
otelc option that times every tool call from inside otelc's own `-toolexec`
wrapper. Our stopwatch, all grown up.

Building on undocumented corners like these isn't comfortable, and the people
who build these tools know it. The Orchestrion team at Datadog
[asked the Go team for better hooks](https://github.com/golang/go/issues/69887)
in 2024, and the answer so far is that dedicated support for source rewriting
would add a lot of complexity to the `go` command. For
now, `-toolexec` is the interface, and everything in this post is how we live
with it.

## Try it yourself

Every output above comes from a real run. The
[companion repository](https://github.com/kakkoyun/hooking-into-the-go-toolchain)
has the stopwatch, `toyhook`, the small programs and the HTTP server, with one
`make` target per experiment:

```console
git clone https://github.com/kakkoyun/hooking-into-the-go-toolchain
cd hooking-into-the-go-toolchain
make help
make step2         # the stopwatch
make step6-poison  # watch the cache lie
make otelc-install # otelc v1.1.0 into ./.bin
make step7         # otelc on the HTTP server
```

Each target uses its own build cache and output path, so your real build cache
stays clean (otelc's modules still land in your module cache). You'll need Go
1.25 or newer.

The quickest experiment, though, is still the one we started with. Point a stopwatch
at a project you work on, sort the log by milliseconds, and see which package
you've been waiting for all along. Then ask yourself what else you'd do, now
that you know you can stand right there, next to the compiler.
