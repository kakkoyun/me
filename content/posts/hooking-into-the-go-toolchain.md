---
title: "Hooking into the Go Toolchain"
description: "How go build -toolexec lets you time, rewrite and instrument every compiler and linker run, from a small stopwatch to OpenTelemetry's otelc."
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

## A stopwatch in the build

Here is the cheapest experiment you can run on a Go toolchain:

```console
$ go build -a -toolexec=/usr/bin/time ./app
# internal/unsafeheader
        0.02 real         0.00 user         0.00 sys
# internal/goarch
        0.03 real         0.00 user         0.00 sys
# internal/coverage/rtcov
        0.02 real         0.00 user         0.00 sys
...
```

*Go 1.27.1, darwin/arm64. First six of 216 lines. [captures/step0-stderr.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step0-stderr.txt)*

Each `real user sys` receipt is one program the `go` command ran on your
behalf. For this small program there are 108 of them: 59 compiler runs, 48
assembler runs and one linker run. `-toolexec` tells `go build` to run each of
those programs through a program you pick. Here we picked a stopwatch.

Timing was not the plan. Russ Cox added the flag in January 2015 so the
toolchain could run "under common testing environments, such as valgrind", or
with alternate tools swapped in, and the commit points at toolstash, his tool
for building with a stashed copy of the compiler.[^h1-cl] Go 1.5 shipped it as
"a custom replacement for `go tool`".[^h2-go15] Five weeks after the flag
landed, toolstash learned a `-t` flag that prints how long each command
takes.[^h1-toolstash-t] Years later Russ called `-toolexec=time` "an accident -
a mostly happy one".[^h1-rsc-accident]

In 2020, Daniel Martí described the territory in his GoLab talk abstract:
"there's a space that hasn't been explored much so far - modifying Go builds,
in particular by hooking straight into the 'go build' command and its
components, such as the compiler and linker."[^d6-golab] He had been exploring
it with [garble](https://github.com/burrowers/garble), an obfuscator, and his
work shows up all over this post.

We'll start with the stopwatch, then make the wrapper rewrite code before the
compiler sees it, add packages the build never asked for, call code we're not
allowed to import, and get lied to by the build cache. At the end we'll look at
[otelc](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation),
OpenTelemetry's compile-time instrumentation tool for Go, which does all of that
for a living, and we'll time it with the same stopwatch.

Thanks to Jesús Espino for the invitation. His
[Understanding the Go Compiler](https://internals-for-interns.com/series/understanding-the-go-compiler/)
series explains what the compiler does with your code; this post is about how
to get between the `go` command and the compiler in the first place.
Disclosure: I work at Datadog and I'm one of otelc's maintainers, so treat me
as a friendly witness for the last third.[^o3-sig]

Everything below runs. The programs, the Makefile and every captured output
live in a companion repository,
[kakkoyun/hooking-into-the-go-toolchain](https://github.com/kakkoyun/hooking-into-the-go-toolchain).
The commands below are shown as you'd type them. The Makefile also gives each
build a private `GOCACHE` and an `-o` path: in the repository root, a bare
`go build ./app` refuses to run because `app` is already a directory.

## What `go build` actually runs

Ask the `go` command to narrate with `-x`, keep its scratch directory with
`-work`, and force a full rebuild with `-a`:

```console
$ go build -a -x -work ./app
WORK=$REPO/.cache/step1/tmp/go-build3768285036
...
$GOROOT/pkg/tool/darwin_arm64/compile -o $WORK/b001/_pkg_.a -trimpath "$WORK/b001=>" \
    -p main -lang=go1.25 -complete -buildid kIewNeZLieJMDX0sK6uO/kIewNeZLieJMDX0sK6uO \
    -goversion go1.27.1 -c=16 -shared -nolocalimports \
    -importcfg $WORK/b001/importcfg -pack ./app/main.go
...
$GOROOT/pkg/tool/darwin_arm64/link -o $WORK/b001/exe/a.out \
    -importcfg $WORK/b001/importcfg.link -buildmode=pie ... $WORK/b001/_pkg_.a
```

*Excerpt of 793 lines; line breaks added, the link flags and env prefix trimmed. [captures/step1-x.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step1-x.txt)*

A build is a graph of actions, one or more per package, and each action gets
a numbered directory under `$WORK`. `b001` is our `main` package. The
compiler is called once per package with three things that matter for us: the
package path (`-p`), the list of `.go` files at the end, and an
`-importcfg` file. That file is the compiler's whole view of the outside world:

```text
# import config
packagefile bytes=$WORK/b002/_pkg_.a
packagefile fmt=$WORK/b042/_pkg_.a
packagefile github.com/kakkoyun/hooking-into-the-go-toolchain/greet=$WORK/b060/_pkg_.a
packagefile os=$WORK/b049/_pkg_.a
packagefile time=$WORK/b054/_pkg_.a
packagefile runtime=$WORK/b009/_pkg_.a
```

*The full `$WORK` path is shortened to `$WORK`. [captures/step1-importcfg.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step1-importcfg.txt)*

Six `packagefile` lines: the five packages `app/main.go` imports, plus `runtime`. The
compiler doesn't search a `GOPATH` or read `go.mod`. If a package isn't in
this file, it doesn't exist. Jesús's post on the
[unified IR format](https://internals-for-interns.com/posts/go-compiler-unified-ir/)
shows what lives inside those `_pkg_.a` archives. The linker gets the same
treatment with `importcfg.link`, which lists every package in the program.

The log has 207 lines ending in `# internal`. Those are things the `go` command
does itself, such as writing an importcfg, packing an archive or stamping a
build ID. Most of the remaining lines are shell narration too, such as `mkdir`
and `cd`, plus a few `git` calls for version stamping. The lines that matter
run a program from `$GOROOT/pkg/tool/`: 108 runs of `compile`, `asm` and `link`. Those are the
lines `-toolexec` sits in front of. In the words of `go help build`:

```text
-toolexec 'cmd args'
	a program to use to invoke toolchain programs like vet and asm.
	For example, instead of running asm, the go command will run
	'cmd args /path/to/asm <arguments for asm>'.
	The TOOLEXEC_IMPORTPATH environment variable will be set,
	matching 'go list -f {{.ImportPath}}' for the package being built.
```

That's the entire interface.[^g7-help] Your program receives the tool's path as
its first argument and the tool's arguments after it, and it can do anything
it likes before, after or instead of running the tool. `TOOLEXEC_IMPORTPATH`
tells it which package is being built. Daniel added it in Go 1.16, so wrappers
no longer had to reverse-engineer the package from the flags.[^d4-importpath]
For test builds the value carries a suffix, such as
`example.com/pkg [example.com/pkg.test]`, so compare it with care.[^importpath-test]

The same hook sits in front of every Go toolchain program the `go` command
starts: `compile`, `asm` and `link`, plus `cgo`, `cover` and `vet` when a build
needs them. The C compiler that cgo packages use and the `git` calls are not
wrapped.[^exec-tools] Two more properties
of the interface will matter later. The tools run in parallel, up to `-p`
programs at once (by default, the number of CPUs), so a wrapper may be running
in a dozen copies at the same time. And each call is a fresh process that knows
nothing about the calls before it. If a wrapper needs to remember something
between the compile of one package and the link of the program, it has to
write it down somewhere.

One more flag is worth knowing: `-n` prints the same commands as `-x` without
running any of them.[^g7-help] It's a dry run of the whole build plan, and otelc
will put it to work [later on](#from-toy-to-tool-otelc).

## Building our own stopwatch

`/usr/bin/time` tells us how long things took, but not which package each
number belongs to. Our own wrapper can do better. Here's the heart of it:

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

*Excerpt. [cmd/stopwatch/main.go](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/cmd/stopwatch/main.go)*

It runs the real tool with the same standard streams, measures wall time,
appends one tab-separated line per call to the file named by `$STOPWATCH_LOG`
(tool, `TOOLEXEC_IMPORTPATH`, milliseconds, a short summary of the arguments),
and exits with the tool's status. Because a dozen copies may run at once, each
record goes to the file in a single append, so lines from parallel compiles
don't interleave. Writing to a file and leaving the tool's streams alone turns
out to matter a lot, as we'll see in a moment.

```console
go build -o .bin/stopwatch ./cmd/stopwatch
STOPWATCH_LOG=/tmp/sw.tsv go build -a -toolexec=$PWD/.bin/stopwatch ./app
```

Daniel ran this experiment on stage, `-x` first and then `-toolexec=time`, in
his GopherCon UK 2022 talk on the build system.[^d5-talk]

The per-tool counts and the slowest packages:

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

*[captures/step2-counts.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step2-counts.txt), [captures/step2-slowest.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step2-slowest.txt)*

No surprise that `runtime` is the slowest package to compile. Don't add the
column up and call it the build time, though: the tools ran in parallel, so the
sum of their times is larger than the time you spent waiting. The interesting
column in the first table is the last one. Before building anything, the `go`
command ran each tool once with a single argument, `-V=full`, and it did that
through our wrapper. Call it the probe:

```text
compile | - | 8 | -V=full
```

*Excerpt; tabs shown as `|`. [captures/step2-vfull.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step2-vfull.txt)*

Remember this line; it comes back twice. The answer to the probe, here
`compile version go1.27.1`, becomes the *tool ID*. Every action's cache key,
its *action ID*, is a hash of its source files, its flags, the tool ID and the
content IDs of its dependencies. What the action produces gets a *content ID*.
Note what isn't in the key: the `-toolexec` string itself. The `go` command asks
the wrapper rather than reading the compiler binary because, in the words of
the source, "we want '-toolexec toolstash' to continue working". If a wrapper
swaps in a different compiler, the cache key should know.[^h4-toolid]

![Flowchart: go build sends each tool's -V=full probe through the stopwatch, hashes the answer with sources and flags into an action ID, and on a cache miss runs the real tool through the stopwatch](/uploads/hooking-into-the-go-toolchain-d1.svg)

*Where the stopwatch sits in a build. Diagram: [diagrams/D1.mmd](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/diagrams/D1.mmd).*

It also means the wrapper's *stdout* is no longer just output: during a probe,
it's the answer. In 2017, just before the build cache shipped, Russ fixed the
`go` command to ignore a tool's stderr during the probe, so long as stdout carries
the expected line.[^h3-22588] Stdout got no such pass. If our stopwatch
announces itself on stdout before running the tool, the build stops cold:

```text
go: parsing buildID from go tool compile -V=full: unexpected output:
	stopwatch: starting compile
compile version go1.27.1
```

*`STOPWATCH_STDOUT=first`. [captures/step2-stdout-bug.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step2-stdout-bug.txt)*

The sneakier variant prints the log line on stdout *after* the tool. On a
release toolchain the `go` command only checks that the first words look like
`compile version go1.27.1` and then uses the whole output as the ID. The build
succeeds. But our log line contains a millisecond count, so the tool ID changes
on every build, and a second build in the same cache recompiled all 59
packages:[^h4-toolid]

```text
compile lines printed by the first build:  59
compile lines printed by a second build:   59
(a plain warm build runs no compile at all)
```

*`STOPWATCH_STDOUT=1`. [captures/step2-stdout-after-summary.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step2-stdout-after-summary.txt)*

Nothing failed and nothing was cached. With the well-behaved wrapper, run the
build again, this time without `-a`:

```text
compile | - | 6 | -V=full
asm | - | 4 | -V=full
link | - | 5 | -V=full
```

*Second build, same `GOCACHE`, output file kept; tabs shown as `|`. [captures/step2-warm.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step2-warm.txt)*

Three probes and nothing else. Every package was a cache hit, so no tool ran
and the stopwatch had nothing to time. **A `-toolexec` wrapper only sees what
the cache lets through.**

If you only want to know where a build spends its time, the `go` command has
an undocumented flag for that, `-debug-trace=trace.json`, which writes a trace
you can open in a trace viewer.[^g4-debugtrace] Our wrapper earns its keep
because it can do more than watch.

## Rewriting code before the compiler sees it

The compiler gets its source files as arguments, and our wrapper sees those
arguments first. Nothing stops it from handing over different files.

The toy wrapper in the companion repo is called `toyhook`. In its first mode
it looks for functions marked with a `//demo:log` comment:

```go
// countLines reads path with os.ReadFile, which step 5 hooks.
//
//demo:log
func countLines(path string) int {
	data, err := os.ReadFile(path)
	...
```

When a `compile` call arrives for the package named in `TOOLEXEC_IMPORTPATH`,
toyhook does four things:

1. Parses each `.go` argument with `go/parser` and finds the marked functions.
2. Inserts a statement right after each function's opening brace.
3. Writes the result into the action's own `$WORK/bNNN/` directory, which it
   finds from the `-o` flag.
4. Swaps the new path into the argument list and runs the real compiler.

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

*[captures/step3-diff.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step3-diff.txt)*

The program now narrates:

```text
hello, toolchain
→ countLines at 14:17:40
go.mod has 3 lines
done in 0s
```

*[captures/step3-run.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step3-run.txt)*

The wrapper runs for every package, but it only rewrites one. For the other
58 compile calls it must get out of the way quickly and run the tool
untouched, which is why the target check comes first. It also can't see the
whole program: each call hands it one package, and it can only change the
files that package is being compiled from. That's why the next two sections need
importcfg patching and `//go:linkname`.

Two details are easy to miss. The first is the `//line` comment. It's a
compiler directive that resets the file name and line number, so stack traces,
panics and compiler errors after the inserted line still point at
`app/main.go:24`, not at a temporary file that is gone by the time anyone reads
the error.[^line-directive] Without it, every line below the insertion would be
off by one, which is the kind of bug that makes people distrust instrumentation.

The second is how the file gets rewritten. toyhook splices bytes at offsets that
`go/parser` reports instead of printing a modified syntax tree. That keeps every
untouched byte where it was. Printing a modified `go/ast` tree tends to move
comments around, because comments in `go/ast` are tied to positions rather than
to the nodes they describe. Serious tools solve that differently: otelc
rewrites with [dst](https://github.com/dave/dst), a decorated syntax tree that
keeps comments attached to nodes, and marks the generated code with `//line`
directives like ours.[^dst]

Jesús's [parser post](https://internals-for-interns.com/posts/the-go-parser/)
is a good companion here. toyhook works on the `go/ast` tree from the standard
library's parser, just before the compiler parses the same files into a tree of
its own.

## Packages the build never asked for

`fmt`, `os` and `time` are already imported by `app/main.go`, which made the
last step easy. Let's be more ambitious and log with `log/slog`, which `app`
doesn't import. toyhook adds the import and the call:

```text
$WORK/b001/main.go:3:8: could not import log/slog (open : no such file or directory)
```

*Last line. [captures/step4-broken.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step4-broken.txt)*

The `go` command wrote the importcfg from the imports in the *original* file
before it called us. The compiler looks up `log/slog` in that file, finds
nothing, and tries to open an empty path. Every tool that adds an import hits
this wall. Julio Guerra reported it in 2019, and Ian Lance Taylor's
reply was that "the `-toolexec` option is not powerful enough to support
arbitrary source code rewriting. This is not a bug, it's just the way the
option works."[^g6-35204] Julio went on to do compile-time instrumentation with
`-toolexec` anyway.

The way around it is to supply the missing lines ourselves. The `go` command
will tell us where the compiled archive of any package lives:

```console
go list -deps -export -f '{{if .Export}}packagefile {{.ImportPath}}={{.Export}}{{end}}' log/slog
```

toyhook appends the `-deps` lines the compile importcfg is missing, then does
the same for the link step. The compiler only reads the `log/slog` line, but the
linker needs every package that ends up in the binary, including `log/slog`'s
own dependencies. The link happens in a different process, long after the compile
that introduced the import, so the wrapper has to remember what it added. otelc
writes the added packages to tracking files during compilation and reads them
back when the link command arrives.[^o2c-importcfg]

```text
compile importcfg: 7 lines before, 79 after
link importcfg:    60 lines before, 80 after
```

*Summarised from [captures/step4-compile-importcfg-summary.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step4-compile-importcfg-summary.txt), [captures/step4-link-importcfg-summary.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step4-link-importcfg-summary.txt)*

```text
hello, toolchain
2026/10/01 14:17:52 INFO enter func=countLines
go.mod has 3 lines
done in 2ms
```

*[captures/step4-run.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step4-run.txt)*

The patch assumes the outer build uses default flags. If you build with
`-race` or `-tags`, the `go list` call has to use them too, or the archives it
points at won't match the rest of the build.

One trap: that `go list` call is itself a Go command running inside a build.
If it inherits our `-toolexec`, through `GOFLAGS` for example, it runs through
the wrapper too, and a wrapper that calls `go list` again would recurse. toyhook
clears `GOFLAGS` and caches the answer. otelc takes the opposite approach: it
deliberately runs its child `go` commands under itself, in a mode that only
answers the `-V=full` probe, so their cache keys match the outer
build's.[^o2b-nested]

## Calling code you are not allowed to import

Until now we've only touched our own package. Real instrumentation has to reach
code you didn't write. Let's make every call to
`os.ReadFile` report to a function in our module:

```go
package hooks

func OnReadFile(name string) {
	fmt.Fprintf(os.Stderr, "hooks.OnReadFile(%q)\n", name)
}
```

*Excerpt. [hooks/hooks.go](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/hooks/hooks.go)*

Package `os` can't import `hooks`. `hooks` imports `fmt`, which imports `os`,
and Go doesn't allow import cycles. The importcfg trick doesn't help either:
the compiler would reject the cycle no matter what the config says.

The way out is `//go:linkname`. It tells the compiler that a local name refers
to a symbol defined somewhere else, and leaves it to the linker to connect the
two.[^linkname-doc] toyhook adds one generated file to the `os` compile:

```go
package os

import _ "unsafe"

//go:linkname toyhookOnReadFile github.com/kakkoyun/hooking-into-the-go-toolchain/hooks.OnReadFile
func toyhookOnReadFile(name string)
```

*[captures/step5-toyhook_linkname.go.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step5-toyhook_linkname.go.txt)*

It also inserts the call into `ReadFile` itself:

```diff
 func ReadFile(name string) ([]byte, error) {
+	toyhookOnReadFile(name)
+//line $GOROOT/src/os/file.go:872
 	f, err := Open(name)
```

*Excerpt. [captures/step5-os-file.diff](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step5-os-file.diff)*

```text
hello, toolchain
hooks.OnReadFile("go.mod")
go.mod has 3 lines
done in 0s
```

*[captures/step5-run.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step5-run.txt)*

The standard library just called into our module without importing it. Three
things had to line up.

First, `os` had to be recompiled. Standard library packages are cached like any
other, so the demo builds with `-a`. otelc goes further and keeps a cache of its
own, as we'll see.

Second, `hooks` had to end up in the binary. Nothing imports it, so the linker
has no reason to include it, and the build fails:

```text
os.ReadFile: relocation target github.com/kakkoyun/hooking-into-the-go-toolchain/hooks.OnReadFile not defined
```

*Last line. [captures/step5-nohook.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step5-nohook.txt)*

The fix is a blank import, `import _ ".../hooks"`, in a file of the main
package. That's also why instrumentation tools generate a file for your
`main` package.

Third, the compiler had to accept a function with no body. The `go` command
normally passes `-complete` to packages made only of Go files. Under that flag
the compiler rejects bodyless functions, unless they carry a `//go:linkname`,
which has been allowed since Go 1.12.[^g2-23311] `os` doesn't get the flag at
all: it's one of ten standard-library packages whose missing bodies the runtime
provides behind the scenes.[^g8-complete] I wrote code to strip `-complete`
before I read that, and it never fired. otelc strips the flag from every
package it instruments, to be safe.[^o2d-complete]

```text
cmd/go passed -complete to the os compile: no
wrapper: toyhook: -complete not present, nothing to strip
```

*Excerpt. [captures/step5-complete.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step5-complete.txt)*

You may have heard that Go 1.23 locked down `//go:linkname`. It did, but in the
other direction: the linker now refuses references *into* standard-library
internals that aren't marked for it, and `-checklinkname=0` turns the check
off.[^g1-linkname] Our reference points from the standard library *out* to a
package we own, which the check leaves alone.

## The cache will lie to you

Remember that `/usr/bin/time` build from the start? Run a plain `go build ./app`
afterwards, in the same cache and without `-toolexec`:

```text
timed lines (' real ') in the cold build:                    108
timed lines (' real ') in the plain build with no -toolexec:  108
```

*Excerpt. [captures/step0-replay-summary.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step0-replay-summary.txt)*

The plain build prints all 108 timing receipts again, though nothing was
timed. The `go` command stores a tool's output with its cache entry and replays
it on a hit. With `-x` you can watch it `cat` 60 cache files marked
`# internal`. Cherry Mui reported this exact case in 2018, using
`-toolexec=/usr/bin/time`. A counter-proposal to stop caching output like this
was accepted in 2020, and the issue is still open.[^h5-27628] Our stopwatch only escapes this because it writes to a file.

Replayed timings are just noise. Replayed object code is a real problem.
Remember that the action ID includes the tool ID, which comes from the
`-V=full` answer, and not the `-toolexec` string.[^h4-toolid] What happens if a wrapper changes what the compiler produces but not what it
says on `-V=full`?

The demo has a shared package, `greet`, used by both `./app` and `./other`.
We build `./app` with toyhook rewriting `greet`, then build `./other` the
plain way, in the same cache:

```console
$ go build -o .bin/toyhook ./cmd/toyhook
$ export GOCACHE=$(mktemp -d)   # keep the poisoned entries out of your real cache
$ TOYHOOK_MODE=rewrite TOYHOOK_TARGET=github.com/kakkoyun/hooking-into-the-go-toolchain/greet \
    go build -o /tmp/app -toolexec=$PWD/.bin/toyhook ./app
$ go build -o /tmp/other ./other && /tmp/other
→ Hello at 14:18:08
hello, other
```

*Commands simplified from [scripts/step6.sh](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/scripts/step6.sh); output from [captures/step6-poison-1-run-other.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step6-poison-1-run-other.txt).*

`./other` was never built with `-toolexec`, and it's instrumented anyway. Both
builds computed the same key for `greet` from the same sources, flags and tool
ID, `compile version go1.27.1`, so the plain build happily reused the rewritten
archive. Reverse the order and it gets stranger: the plain build fills the cache
first, toyhook is never even called for `greet`, and nothing is instrumented
at all:

```text
order 1: wrapped ./app, then plain ./other (same GOCACHE)
  app  : injected code PRESENT
  other: injected code PRESENT
order 2: plain ./other, then wrapped ./app (same GOCACHE)
  other: injected code absent
  app  : injected code absent
```

*Excerpt. [captures/step6-poison-verdict.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step6-poison-verdict.txt)*

Daniel ran into this while building garble, and in 2020 he proposed a way for
`-toolexec` tools to opt into build caching. Russ replied that the tool "that is
altering the behavior of the compiler should be responsible for altering the
-V=full output as well", and Daniel withdrew the proposal three weeks after
opening it.[^d3-41145] This is what garble does today:

```go
contentID := addGarbleToHash(toolID)
// The part of the build ID that matters is the last, since it's the
// "content ID" which is used to work out whether there is a need to redo
// the action (build) or not. Since cmd/go parses the last word in the
// output as "buildID=...", we simply add "+garble buildID=_/_/_/${hash}".
// The slashes let us imitate a full binary build ID, but we assume that
// the other hashes such as the action ID are not necessary, since the
// only reader here is cmd/go and it only consumes the content ID.
fmt.Printf("%s +garble buildID=_/_/_/%s\n", line, encodeBuildIDHash(contentID))
```

*garble v0.18.0, `hash.go`, BSD-3-Clause, © The Garble Authors.[^d2-garble]*

toyhook does the same with a shorter marker built from a hash of its settings.
The ID changes, so every key changes, and `./other` stays clean in both orders:

```text
compile version go1.27.1 toyhook@v1/0e25ba9b
```

*Excerpt. [captures/step6-fixed-vfull.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step6-fixed-vfull.txt), [captures/step6-fixed-verdict.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step6-fixed-verdict.txt)*

Release toolchains use the whole line as the ID; development toolchains only
use the content ID inside a trailing `buildID=` field, which is why garble
dresses its marker up as one.[^h4-toolid] Daniel later wrote that what garble
does to overload Go caching "is in undocumented territory" and has "broken
slightly a couple of times".[^d2-garble-mvdan] Every tool built this way
depends on that one line.

## From toy to tool: otelc

Everything toyhook does, badly and on one package, otelc does for a whole
program. It came out of OpenTelemetry's special interest group (SIG) for Go
compile-time instrumentation, announced in January 2025. Alibaba and Datadog
had each proposed donating a tool of their own; instead they joined forces in
a new SIG, with Quesma bringing its experience from instrgen.[^o3-sig] The new
tool was rebuilt from the ground up rather than renamed.[^o3-rebuilt] otelc
v1.0.0 came out in July 2026, and v1.1.0 in August. It needs Go 1.25 or
newer.[^o1-release]

```console
otelc go build -o hello .
```

That one command runs in two phases:

![Flowchart of otelc's two phases: setup runs a dry-run build plan, matches rules and generates files; instrument runs go build with otelc as -toolexec, marking -V=full, rewriting matched compiles and patching the link](/uploads/hooking-into-the-go-toolchain-d2.svg)

*Drawn from otelc v1.1.0's source. Diagram: [diagrams/D2.mmd](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/diagrams/D2.mmd).*

The setup phase asks the `go` command for the full build plan with a dry run
(`go build -a -x -n`), the same narration we read in
[What `go build` actually runs](#what-go-build-actually-runs), and works out
which packages will be compiled.[^o2e-plan] It also adds the hook modules to
`go.mod` for the duration of the build and restores the file afterwards; the
companion checks that `go.mod` comes out byte-identical.[^gomod-check] Then it runs the real build with
itself as `-toolexec`. Every trick from the toy shows up:

| In this post | In otelc v1.1.0 |
| --- | --- |
| stopwatch log | hidden `--stats` flag, timed inside `toolexec.go`[^o2l-stats] |
| rewrite the `compile` arguments | rule-driven AST rewrite of matched packages |
| patch compile and link importcfg | `updateImportConfig` and `interceptLink`[^o2c-importcfg] |
| linkname into the standard library | generated `//go:linkname` declarations to hook packages |
| blank import in `main` | generated `otelc.runtime.go`[^o2f-runtime] |
| `-V=full` marker | `otelc@v1.1.0/<rules hash>`[^o2a-marker] |

Here's otelc's answer to the probe:

```text
compile version go1.27.1 otelc@v1.1.0/55ec54fb480c0c69
```

*Excerpt. [captures/step7-vfull.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step7-vfull.txt)*

The suffix is a hash of the matched rules, so editing a rule invalidates the
cache as well. On top of that, `otelc go build` uses a private cache under
`.otelc-build/` unless you set `GOCACHE` yourself.[^o2h-cache]

### Rules are data

toyhook's rules were an `if` statement. otelc's are YAML. Each rule names a
target package and one or more of eight modifiers: inject hooks into a function, inject
raw code, add struct fields, add a file, wrap a call, expand a directive, assign
a value, or set fields.[^o2m-modifiers] Our `//demo:log` trick fits in one
rule:

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

*Excerpt. [hello/log.otelc.yml](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/hello/log.otelc.yml)*

```text
2026/10/01 14:28:30 INFO function entry func=world
2026/10/01 14:28:30 INFO function exit func=world duration=232.041µs
```

*`otelc --rules log.otelc.yml go build`. [captures/step7-log-run.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step7-log-run.txt)*

The `imports` block is the
[importcfg problem](#packages-the-build-never-asked-for), solved with three
lines of configuration.

### Spans without a single line of tracing code

The companion's `hello` server has no OpenTelemetry imports at all. Its
`/hello` handler calls `/world` on itself over HTTP. Built with the default
rules, seven of them match, and one request produces three spans in one
trace:

```text
GET /hello   server  trace f6411a6c…  span 26d028cb…  parent (root)
GET          client  trace f6411a6c…  span 6db51783…  parent 26d028cb…
GET /world   server  trace f6411a6c…  span edab8b01…  parent 6db51783…
```

*Reformatted from [captures/step7-spans.tsv](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step7-spans.tsv); rule names in [captures/step7-matched.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step7-matched.txt).*

Because otelc always passes `-work`,[^o2g-work] we can open `$WORK` and read what it did to
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

*Excerpt. [captures/step7-serverhandler.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step7-serverhandler.txt)*

And next to it, the generated declarations that reach into the hook package:

```go
//go:linkname BeforeServeHTTP go.opentelemetry.io/otelc/instrumentation/net/http/server.BeforeServeHTTP
func BeforeServeHTTP(hookContext HookContext, recv0 interface{}, param0 ResponseWriter, param1 *Request)
```

*Excerpt. [captures/step7-linkname.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step7-linkname.txt)*

That's our [linkname trick](#calling-code-you-are-not-allowed-to-import), hook
package and all, applied to a method deep inside the standard library. The rule that asked for it is short:

```yaml
server_hook:
  target: net/http
  where:
    func: ServeHTTP
    recv: serverHandler
  do:
    - inject_hooks:
        before: BeforeServeHTTP
        after: AfterServeHTTP
        path: "go.opentelemetry.io/otelc/instrumentation/net/http/server"
```

*otelc v1.1.0, [`instrumentation/net/http/server/otelc.yaml`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/instrumentation/net/http/server/otelc.yaml), Apache-2.0.*

The hooks are ordinary Go in an ordinary package. `BeforeServeHTTP` extracts
any trace context from the request headers, starts a server span and stores it
in the hook context. `AfterServeHTTP` takes the span back out, renames it once
the router has matched a route, records the status code and ends it.[^server-hook]
The client span comes from a similar rule on the HTTP client. `init_sdk` sets
up the OpenTelemetry SDK from the standard `OTEL_*` environment variables, and
the capture above used `OTEL_TRACES_EXPORTER=console`.[^init-sdk]

The call goes through a trampoline rather than calling the hook directly. The
trampoline builds the hook context, recovers any panic in a hook so a broken
hook can't take the request down with it, and lets hooks change parameters and
return values:[^impl-doc]

![Sequence diagram: ServeHTTP calls the before trampoline, which calls BeforeServeHTTP through //go:linkname; the deferred after trampoline calls AfterServeHTTP when the original body returns](/uploads/hooking-into-the-go-toolchain-d3.svg)

*One instrumented call to `serverHandler.ServeHTTP`. Diagram: [diagrams/D3.mmd](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/diagrams/D3.mmd).*

The trampoline is generated into the instrumented package itself, so its
template obeys a strict rule: "It should not import any package because there
is no guarantee that package is existed in import config during the
compilation".[^o2j-template] That's the importcfg problem again, solved by
never importing anything. The odd `if …; false {} else { defer … }` shape is also deliberate. The
general form lets a hook skip the original function. When a hook never does,
otelc rewrites the condition to `false` and relies on the compiler's
dead-code elimination, one of the SSA passes Jesús walks through in his
[SSA post](https://internals-for-interns.com/posts/the-go-ssa/), to reduce the
whole thing to a call and a `defer`.[^o2i-tjump] The source comment calls this pass "fragile", which is
refreshingly honest.

### A bonus field in every goroutine

Three of the seven matched rules target the runtime itself. `add_gls_field`
adds two fields to the runtime's goroutine struct, `g`, to carry the current
trace context and baggage. `gls_linker` adds a file of accessor functions the
hooks use to reach them. `goroutine_propagate` injects a `defer` into
`newproc1`, the function that creates goroutines, to copy both fields from the
parent goroutine.[^o2k-gls] Trace context and baggage now follow `go`
statements even when your code doesn't pass a `context.Context` around. Two
small fields in a struct you were never meant to touch, all from a wrapper
sitting in front of `compile`.

### A surprise at shutdown

One more surprise from writing the demos: an otelc-built binary catches the
first SIGINT or SIGTERM to flush telemetry, and then deliberately doesn't exit,
leaving that decision to the application.[^otelc-signal] In the capture you can
see it happen, on stdout next to the spans:

```text
{"time":"2026-10-01T14:28:16.202979+02:00","level":"INFO","msg":"received signal, flushing telemetry","signal":"terminated"}
{"time":"2026-10-01T14:28:16.20307+02:00","level":"INFO","msg":"OpenTelemetry SDK shutdown completed successfully"}
```

*[captures/step7-spans.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step7-spans.txt), lines 9–10.*

My first `hello` had no shutdown handling of its own, ignored `kill` for four
minutes, and hung the capture script. Give your servers a
`signal.NotifyContext`, and wait for `Shutdown` to return before `main` does.

## The bill, timed with the same stopwatch

Instrumentation isn't free, and we built a stopwatch, so let's use it. One
run, one machine, Go 1.27.1, `go build -a` of `hello`:

```text
plain, no wrapper:    real 5.97 s
plain, stopwatch:     real 5.76 s
otelc --stats:        real 18.16 s
```

*Excerpt. [captures/stats-summary.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/stats-summary.txt)*

The stopwatch itself costs nothing measurable; the stopwatch run even came in
faster, which tells you how noisy a single run is. Starting one extra process
per tool call is cheap next to running a compiler. otelc's own stopwatch, the hidden
`--stats` flag, wraps each tool call in a timer just like ours and logs it to
`.otelc-build/debug.log`. It reports 4.5 s of setup and 13.6 s of build.

*[captures/stats-otelc-totals.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/stats-otelc-totals.txt), [captures/stats-plain-stopwatch.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/stats-plain-stopwatch.txt)*

Don't read that as "the wrapper is three times slower". The instrumented
program is a different, bigger program: it pulls in the OpenTelemetry SDK, and
the build ran 511 compiles instead of 188. That cost is paid on every cold
build, and the separate cache means the first instrumented build is always
cold. The otelc repository's CI fails if instrumented compile time grows more
than 150% above the plain build measured in the same run.[^o2n-gate]

Build time is only part of the bill. Tools like these lean on undocumented
behavior: the format of a version line, the layout of `$WORK`, the fact that
`os` never gets `-complete`. In 2024 the Orchestrion team at Datadog filed an
issue, titled as a proposal, describing what such tools have to work around,
from the `-V=full` trick to importcfg patching, and asking for better hooks.
Michael Matloob replied that dedicated support for source-rewriting tools
"would result in a significant increase in complexity in the go command", and
the issue is still open.[^g5-69887] For now, `-toolexec` is the interface.

## Try it

Clone the companion repository and ask the Makefile what it can do:

```console
git clone https://github.com/kakkoyun/hooking-into-the-go-toolchain
cd hooking-into-the-go-toolchain
make help
make step2         # the stopwatch
make step6-poison  # watch the cache lie
make otelc-install # otelc v1.1.0 into ./.bin
make step7         # otelc on ./hello (needs jq, curl and python3)
```

Every target uses its own fresh `GOCACHE` inside the repository, so it won't
disturb your real cache, though otelc's modules still land in your module
cache. You need Go 1.25 or newer. The captures were made with
Go 1.27.1 on macOS, and steps two through six were also checked with Go 1.26.8.

If you want to keep going:

- Ehden Sinai's GopherCon 2024 lightning talk builds a code coverage tool with
  `-toolexec`, importcfg patching included.[^x2-ehden]
- Romain Marcadier's walkthrough of the `go build` process covers `-toolexec`
  and its interaction with `GOCACHE` from the Orchestrion side.[^x1-romain]
- Daniel Martí's
  [GopherCon UK 2022 talk on Go's build system](https://www.youtube.com/watch?v=sTXc_JxmvV0)
  covers the rest of what `go build` does, beyond `-toolexec`.[^d5-talk]
- otelc's
  [getting-started guide](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/docs/getting-started.md)
  shows how to use it on your own service, including through `GOFLAGS`.
- [garble](https://github.com/burrowers/garble),
  [Orchestrion](https://github.com/DataDog/orchestrion) and the
  [Apache SkyWalking Go agent](https://github.com/apache/skywalking-go) are three
  more real tools built on the same flag.[^x-tools]

The quickest experiment is still the one we started with. Point the stopwatch
at a project you work on, sort the log by milliseconds, and see which package
you've been waiting for all along. Then ask yourself what else you'd do if you
were standing where the stopwatch is.

## References

[^h1-cl]: golang/go commit [`83c10b2`](https://github.com/golang/go/commit/83c10b204d619d18100716c9588404200acdf6e0), "cmd/go: add build flag -toolexec", Russ Cox, authored 26 January 2015 ([CL 3351](https://go-review.googlesource.com/c/go/+/3351)).
[^h2-go15]: The [Go 1.5 release notes](https://go.dev/doc/go1.5), go command section. Go 1.5 was released on 19 August 2015.
[^h1-toolstash-t]: rsc/toolstash commit [`e6326ef`](https://github.com/rsc/toolstash/commit/e6326efff9), "toolstash: add -t flag for timing", 3 March 2015. Today toolstash lives at [golang.org/x/tools/cmd/toolstash](https://github.com/golang/tools/blob/v0.50.0/cmd/toolstash/main.go#L5-L99).
[^h1-rsc-accident]: Russ Cox on [golang/go#27628](https://github.com/golang/go/issues/27628#issuecomment-702251208), 1 October 2020: "I added -toolexec specifically for toolstash" and "The design of -toolexec was not directly intended for -toolexec=time or -toolexec=gdb. That was an accident - a mostly happy one, but an accident nonetheless."
[^d6-golab]: Daniel Martí, "Diving into the Go toolchain to obfuscate builds", GoLab 2020, 19 October 2020: [talk abstract](https://golab.io/talks/diving-into-the-go-toolchain-to-obfuscate-builds); [video](https://www.youtube.com/watch?v=-uDnciABNOQ), published 14 December 2020.
[^o3-sig]: OpenTelemetry Governance Committee, [announcement of the Go compile-time instrumentation SIG](https://opentelemetry.io/blog/2025/go-compile-time-instrumentation/), OpenTelemetry blog, 24 January 2025; maintainers listed in the [otelc README at v1.1.0](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/README.md#L89-L103).
[^g7-help]: `go help build`, Go 1.27.1; source in [`cmd/go/internal/work/build.go`](https://github.com/golang/go/blob/go1.27.1/src/cmd/go/internal/work/build.go#L202-L207).
[^d4-importpath]: golang/go commit [`de74ea5`](https://github.com/golang/go/commit/de74ea5d740ccc69dbb146578dc8a965351a3d6b), "cmd/go: set TOOLEXEC_IMPORTPATH for -toolexec tools", Daniel Martí ([CL 263357](https://go-review.googlesource.com/c/go/+/263357)); [Go 1.16 release notes](https://go.dev/doc/go1.16).
[^exec-tools]: Go 1.27.1: compile, asm and link pass `cfg.BuildToolexec` first in [`gc.go`](https://github.com/golang/go/blob/go1.27.1/src/cmd/go/internal/work/gc.go#L136) (also L332, L676); vet and cgo in [`exec.go`](https://github.com/golang/go/blob/go1.27.1/src/cmd/go/internal/work/exec.go#L1490) (also L3088); cover in [`exec.go`](https://github.com/golang/go/blob/go1.27.1/src/cmd/go/internal/work/exec.go#L2102-L2110) and covdata in [`cover.go`](https://github.com/golang/go/blob/go1.27.1/src/cmd/go/internal/work/cover.go#L26). The C compiler call at [exec.go L2382](https://github.com/golang/go/blob/go1.27.1/src/cmd/go/internal/work/exec.go#L2382) does not. The `-p` default is documented in `go help build`.
[^importpath-test]: `TOOLEXEC_IMPORTPATH` is set from the package's description in [`shell.go`](https://github.com/golang/go/blob/go1.27.1/src/cmd/go/internal/work/shell.go#L639-L646), Go 1.27.1.
[^h4-toolid]: `toolID` in [`cmd/go/internal/work/buildid.go`](https://github.com/golang/go/blob/go1.27.1/src/cmd/go/internal/work/buildid.go#L115-L185), Go 1.27.1, including the release and `devel` parsing rules at L171–L182; tool IDs are hashed into action IDs in [`exec.go`](https://github.com/golang/go/blob/go1.27.1/src/cmd/go/internal/work/exec.go#L367-L369). The `-toolexec` value itself is not hashed. The build cache arrived in [Go 1.10](https://go.dev/doc/go1.10).
[^h3-22588]: Issue [golang/go#22588](https://github.com/golang/go/issues/22588), "cmd/go: toolID should separate stdout/stderr, ignore stderr if possible", Russ Cox, November 2017; fixed by [CL 76017](https://go-review.googlesource.com/c/go/+/76017), "cmd/go: ignore stderr from tool version checks", first released in Go 1.10.
[^g4-debugtrace]: golang/go commit [`52b0ea2`](https://github.com/golang/go/commit/52b0ea20ff10fdcfe570ef407bd462d23e13d782), "cmd/go: add a debug-trace flag to generate traces" ([CL 237683](https://go-review.googlesource.com/c/go/+/237683)), first in Go 1.16; listed under "Undocumented, unstable debugging flags" in [`build.go`](https://github.com/golang/go/blob/go1.27.1/src/cmd/go/internal/work/build.go#L358-L361).
[^line-directive]: Line directives are documented in [`cmd/compile/doc.go`](https://github.com/golang/go/blob/go1.27.1/src/cmd/compile/doc.go#L184-L196), Go 1.27.1.
[^dst]: The [dave/dst README](https://github.com/dave/dst#readme). otelc adds its `//line <generated>:1` markers in [`apply_func.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/instrument/apply_func.go#L216-L237), v1.1.0.
[^g6-35204]: Issue [golang/go#35204](https://github.com/golang/go/issues/35204), "Build-time source modification using -toolexec", Julio Guerra, 28 October 2019, and [Ian Lance Taylor's reply](https://github.com/golang/go/issues/35204#issuecomment-547168404); Julio's [later comment](https://github.com/golang/go/issues/35204#issuecomment-633996403) of 26 May 2020 on doing it with `-toolexec` and `//go:linkname`.
[^linkname-doc]: The `//go:linkname` directive is documented in [`cmd/compile/doc.go`](https://github.com/golang/go/blob/go1.27.1/src/cmd/compile/doc.go#L268-L300), Go 1.27.1.
[^o2b-nested]: `Toolexec` and `EnableNestedToolexec` in otelc's [`toolexec.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/instrument/toolexec.go#L478-L563), v1.1.0.
[^g8-complete]: See [`cmd/go/internal/work/gc.go`](https://github.com/golang/go/blob/go1.27.1/src/cmd/go/internal/work/gc.go#L85-L102), Go 1.27.1: `bytes`, `internal/poll`, `net`, `os`, `runtime/metrics`, `runtime/pprof`, `runtime/trace`, `sync`, `syscall` and `time`.
[^g2-23311]: Issue [golang/go#23311](https://github.com/golang/go/issues/23311), "cmd/compile: allow body-less functions under -complete flag if they have a //go:linkname attribute", fixed in Go 1.12 by [CL 151318](https://go-review.googlesource.com/c/go/+/151318).
[^o2d-complete]: `stripCompleteFlag` in otelc's [`toolexec.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/instrument/toolexec.go#L87-L95), applied at [L137–L139](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/instrument/toolexec.go#L137-L139).
[^g1-linkname]: The [Go 1.23 release notes](https://go.dev/doc/go1.23#linker), linker section; tracking issue [golang/go#67401](https://github.com/golang/go/issues/67401). The check only applies to symbols defined in the standard library: see [`loader.go`](https://github.com/golang/go/blob/go1.27.1/src/cmd/link/internal/loader/loader.go#L2545-L2550), Go 1.27.1.
[^h5-27628]: Issue [golang/go#27628](https://github.com/golang/go/issues/27628), "cmd/go: do not cache tool output if tools print to stdout/stderr", Cherry Mui, 11 September 2018; counter-proposal [accepted](https://github.com/golang/go/issues/27628#issuecomment-713727252) on 21 October 2020; open, milestone Backlog, as of 1 October 2026.
[^d3-41145]: Issue [golang/go#41145](https://github.com/golang/go/issues/41145), "proposal: cmd/go: allow -toolexec tools to opt in to build caching", Daniel Martí, opened 31 August 2020, closed 22 September 2020; [Russ Cox's reply](https://github.com/golang/go/issues/41145#issuecomment-694612401).
[^d2-garble]: Function [`alterToolVersion`](https://github.com/burrowers/garble/blob/v0.18.0/hash.go#L56-L90) in garble v0.18.0, called from [`main.go`](https://github.com/burrowers/garble/blob/v0.18.0/main.go#L292-L293). Excerpt shows L80–L88.
[^d2-garble-mvdan]: Daniel Martí on [golang/go#41145](https://github.com/golang/go/issues/41145#issuecomment-2405558244), 10 October 2024.
[^o3-rebuilt]: Romain Marcadier on [golang/go#69887](https://github.com/golang/go/issues/69887#issuecomment-3116802115), 25 July 2025: "The new tool is being (re)built from the ground up together with the other SIG members".
[^o1-release]: The [otelc releases](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/releases): v1.0.0 and v1.0.1 on 14 July 2026 (v1.0.0 is retracted), v1.1.0 on 24 August 2026; [`go.mod`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/go.mod) at v1.1.0 declares `go 1.25.0`.
[^gomod-check]: otelc [`setup/setup.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/setup/setup.go#L326-L327) ("setup edits go.mod for the injected hook modules") and [L629–L633](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/setup/setup.go#L629-L633) (restore), v1.1.0; capture [captures/step7-gomod-check.txt](https://github.com/kakkoyun/hooking-into-the-go-toolchain/blob/7eff7fc83c6b1efd3d2c3d2cf71a696f8f2b488f/captures/step7-gomod-check.txt).
[^o2e-plan]: `listBuildPlan` in otelc's [`setup/find.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/setup/find.go#L80-L125), v1.1.0.
[^o2l-stats]: otelc [`tool/cmd/otelc/main.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/cmd/otelc/main.go#L69-L74) (`Hidden: true`) and [`toolexec.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/instrument/toolexec.go#L507-L521), v1.1.0.
[^o2c-importcfg]: otelc [`toolexec.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/instrument/toolexec.go#L147-L354), v1.1.0.
[^o2f-runtime]: otelc [`setup/add.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/setup/add.go#L20-L50), v1.1.0.
[^o2a-marker]: `toolVersionLine` and `markedToolVersion` in otelc's [`toolexec.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/instrument/toolexec.go#L427-L458), v1.1.0.
[^o2h-cache]: `setupGoCache` in otelc's [`setup/setup.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/setup/setup.go#L416-L434) and [getting-started.md](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/docs/getting-started.md#L72-L74), v1.1.0.
[^o2g-work]: otelc [`setup/setup.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/setup/setup.go#L551-L552), v1.1.0.
[^o2m-modifiers]: otelc [docs/rules.md](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/docs/rules.md#L273-L286), v1.1.0: `inject_hooks`, `inject_code`, `add_struct_fields`, `add_file`, `wrap_call`, `expand_directive`, `assign_value`, `set_fields`.
[^init-sdk]: otelc [`instrumentation/go.opentelemetry.io/otel/init/otelc.yaml`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/instrumentation/go.opentelemetry.io/otel/init/otelc.yaml) [`pkg/runtime/otel_setup.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/pkg/runtime/otel_setup.go#L23-L30) (`OTEL_TRACES_EXPORTER` is `otlp`, `console` or `none`), v1.1.0, and the [configuration docs](https://opentelemetry.io/docs/zero-code/go/compile-time/configuration/).
[^impl-doc]: otelc [docs/implementation.md](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/docs/implementation.md#L15-L30) on panics and context, and [L125–L137](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/docs/implementation.md#L125-L137) on `SetParam` and `SetReturnValue`, v1.1.0.
[^o2j-template]: otelc [`trampoline.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/instrument/trampoline.go#L60-L71) and [`impl.tmpl`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/instrument/impl.tmpl), v1.1.0.
[^o2i-tjump]: otelc [`optimize.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/tool/internal/instrument/optimize.go#L15-L78), v1.1.0.
[^o2k-gls]: otelc [`instrumentation/runtime/otelc.yaml`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/instrumentation/runtime/otelc.yaml#L1-L30), v1.1.0.
[^server-hook]: `BeforeServeHTTP` and `AfterServeHTTP` in otelc's [`instrumentation/net/http/server/server_hook.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/instrumentation/net/http/server/server_hook.go#L55-L128), v1.1.0.
[^otelc-signal]: `setupSignalHandler` and `handleShutdownSignal` in otelc's [`pkg/runtime/setup.go`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/pkg/runtime/setup.go#L310-L347), v1.1.0.
[^o2n-gate]: otelc [docs/benchmarking.md](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/docs/benchmarking.md#L117-L123), v1.1.0.
[^g5-69887]: Issue [golang/go#69887](https://github.com/golang/go/issues/69887), "proposal: cmd/go: compile-time instrumentation and `-toolexec`", Romain Marcadier, 15 October 2024; see [Michael Matloob's reply](https://github.com/golang/go/issues/69887#issuecomment-2549714056) of 17 December 2024.
[^x2-ehden]: Ehden Sinai, ["Implementing Code Coverage with -toolexec"](https://www.youtube.com/watch?v=kUcP9bu3nLQ), GopherCon 2024; [materials](https://github.com/cixel/gc2024).
[^x1-romain]: Romain Marcadier, ["The go build process"](https://romainmuller.dev/posts/2024-04-04/), 4 April 2024.
[^d5-talk]: Daniel Martí, talk on Go's build system at GopherCon UK 2022: [video](https://www.youtube.com/watch?v=sTXc_JxmvV0), [slides](https://docs.google.com/presentation/d/1tIb04KIka3sTmsF0G8v3RbzKG632oB1UObTmPQ80oq4/edit). The slides include "demo 2: build with -x, then with -toolexec=time".
[^x-tools]: garble [`main.go`](https://github.com/burrowers/garble/blob/v0.18.0/main.go#L374-L375); Orchestrion [`internal/cmd/toolexec.go`](https://github.com/DataDog/orchestrion/blob/v1.13.1/internal/cmd/toolexec.go#L36-L39); SkyWalking Go [hybrid compilation](https://github.com/apache/skywalking-go/blob/v0.7.0/docs/en/concepts-and-designs/hybrid-compilation.md).
