---
canonical_url: https://www.polarsignals.comhttps://www.polarsignals.com/blog/posts/2022/01/27/fantastic-symbols-and-where-to-find-them-part-2
categories:
- symbolization
- debugging
- profiling
- analysis
- perf
- symbols
- interpreters
- JIT
- just-in-time-compiler
- python
- ruby
- NodeJS
- JavaScript
- JVM
- Java
- .Net
- Erlang
date: "2022-01-27T00:00:00Z"
published: false
title: Fantastic Symbols and Where to Find Them - Part 2
---

> This is a blog post series. If you haven’t read [Part 1](https://www.polarsignals.com/blog/posts/2022/01/13/fantastic-symbols-and-where-to-find-them) we recommend you to do so first!

_Originally published on polarsignals.com/blog on 27.01.2022_

In [the first blog post](https://www.polarsignals.com/blog/posts/2022/01/13/fantastic-symbols-and-where-to-find-them), we learned about the fantastic symbols ([debug symbols](https://en.wikipedia.org/wiki/Debug_symbol)), how the symbolization process works and lastly, how to find the symbolic names of addresses in a compiled binary.

The actual location of the symbolic information depends on the programming language implementation the program is written in.
We can categorize the programming language implementations into three groups: compiled languages (with or without a runtime), interpreted languages, and [JIT-compiled](https://en.wikipedia.org/wiki/Just-in-time_compilation) languages.

In this post, we will continue our journey to find fantastic symbols. And we will look into where to find them for the other types of programming language implementations.

## JIT-compiled language implementations

Examples of JIT-compiled languages include Java, .NET, Erlang, JavaScript (Node.js) and many others.

[Just-In-Time](https://en.wikipedia.org/wiki/Just-in-time_compilation) compiled languages compile the source code into [bytecode](https://en.wikipedia.org/wiki/Bytecode), which is then compiled into [machine code](https://en.wikipedia.org/wiki/Machine_code) at runtime,
often using direct feedback from runtime to guide compiler optimizations on the fly.

Because functions are compiled on the fly, there is no pre-built, discoverable symbol table in any object files. Instead, the symbol table is created on the fly.
The symbol mappings (location to symbol) are usually stored in the _memory_ of the [runtime](<https://en.wikipedia.org/wiki/Runtime_(program_lifecycle_phase)>) or [virtual machine](https://en.wikipedia.org/wiki/Virtual_machine)
and used for rendering human-readable stack traces when it is needed _, e. g._ when an exception occurs, the runtime will use the symbol mappings to render a human-readable stack trace.

The good thing is that most of the runtimes provide supplemental symbol mappings for the just-in-time compiled code for Linux to use `perf`.

`perf` defines [an interface](https://github.com/torvalds/linux/blob/master/tools/perf/Documentation/jit-interface.txt) to resolve symbols for dynamically generated code by a JIT compiler.
These files usually can be found in `/tmp/perf-$PID.map`, where `$PID` is the process ID of the process of the runtime that is running on the system.

The runtimes usually don't enable providing symbol mappings by default.
You might need to change a configuration, run the virtual machine with a specific flag/environment variable or run an additional program to obtain these mappings.
For example, JVM needs an agent to provide supplemental symbol mapping files, called [perf-map-agent](https://github.com/jvm-profiling-tools/perf-map-agent).

Let's see an example `perf map` file for NodeJS. The runtimes out there output this file with _more or less_ the same format, [more or less!](https://github.com/parca-dev/parca-agent/issues/139)

To generate a similar file for [Node.js](https://en.wikipedia.org/wiki/Node.js), we need to run `node` with `--perf-basic-prof` option.

```shell
# With Node.js >=v0.11.15 the following command will create a map file for NodeJS:
node --perf-basic-prof your-app.js
```

This will create a map file at `/tmp/perf-<pid>.map` that looks like this:

```text
3ef414c0 398 RegExp:[{(]
3ef418a0 398 RegExp:[})]
59ed4102 26 LazyCompile:~REPLServer.self.writer repl.js:514
59ed44ea 146 LazyCompile:~inspect internal/util/inspect.js:152
59ed4e4a 148 LazyCompile:~formatValue internal/util/inspect.js:456
59ed558a 25f LazyCompile:~formatPrimitive internal/util/inspect.js:768
59ed5d62 35 LazyCompile:~formatNumber internal/util/inspect.js:761
59ed5fca 5d LazyCompile:~stylizeWithColor internal/util/inspect.js:267
4edd2e52 65 LazyCompile:~Domain.exit domain.js:284
4edd30ea 14b LazyCompile:~lastIndexOf native array.js:618
4edd3522 35 LazyCompile:~online internal/repl.js:157
4edd37f2 ec LazyCompile:~setTimeout timers.js:388
4edd3cca b0 LazyCompile:~Timeout internal/timers.js:55
4edd40ba 55 LazyCompile:~initAsyncResource internal/timers.js:45
4edd42da f LazyCompile:~exports.active timers.js:151
4edd457a cb LazyCompile:~insert timers.js:167
4edd4962 50 LazyCompile:~TimersList timers.js:195
4edd4cea 37 LazyCompile:~append internal/linkedlist.js:29
4edd4f12 35 LazyCompile:~remove internal/linkedlist.js:15
4edd5132 d LazyCompile:~isEmpty internal/linkedlist.js:44
4edd529a 21 LazyCompile:~ok assert.js:345
4edd555a 68 LazyCompile:~innerOk assert.js:317
4edd59a2 27 LazyCompile:~processTimers timers.js:220
4edd5d9a 197 LazyCompile:~listOnTimeout timers.js:226
4edd6352 15 LazyCompile:~peek internal/linkedlist.js:9
4edd66ca a1 LazyCompile:~tryOnTimeout timers.js:292
4edd6a02 86 LazyCompile:~ontimeout timers.js:429
4edd7132 d7 LazyCompile:~process.kill internal/process/per_thread.js:173
```

> Each line has `START`, `SIZE` and `symbolname` fields, separated with spaces. `START` and `SIZE` are hex numbers without 0x.
> `symbolname` is the rest of the line, so it could contain special characters.

With the help of this mapping file, we have everything we need to symbolize the addresses in the stack trace. Of course, as always, this is just an oversimplification.

For example, these mappings might change as the runtime decides to recompile the bytecode. So we need to keep an eye on these files and keep track of the changes to resolve the address correctly with their most recent mapping.

Each runtime and virtual machine has its peculiarities that we need to adapt. But those are out of the scope of this post.

## Interpreted language implementations

Examples of interpreted languages include Python, Ruby, and again many others.
There are also languages that commonly use interpretation as a stage before [JIT compilation](https://en.wikipedia.org/wiki/Just-in-time_compilation), e. g. Java.
Symbolization for this stage of compilation is similar to interpreted languages.

Interpreted language runtimes do not compile the program to machine code.
Instead, interpreters and virtual machines parse and execute the source code using their [REPL](https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop) routines.
Or execute their own virtual processor. So they have their own way of executing functions and managing stacks.

If you observe (profile or debug) these runtimes using something like `perf`,
you will see symbols for the runtime. However, you won't see the language-level context you might be expecting.

Moreover, the interpreter itself is probably written in a more low-level language like C or C++.
And when you inspect the object file of the runtime/interpreter, the symbol table that you would find would show the internals of the interpreter, not the symbols from the provided source code.

### Finding the symbols for our runtime

The runtime symbols are useful because they allow you to see the internal routines of the interpreter. e. g. how much time your program spends on garbage collection.
And it's mostly like the stack traces you would see in the debugger or profiler will have calls to the internals of the runtime.
So these symbols are also helpful for debugging.

![Node Stack Trace](https://www.polarsignals.com/blog/posts/2022/01/node_stack_trace.png)

> Most of the runtimes are compiled with `production` mode, and they most likely lack the debug symbols in their release binaries.
> You might need to manually compile your runtime in `debug mode` to actually have them in the resulting binary.
> Some runtimes, such as Node.js, already have them in their `production` distributions.

Lastly, to completely resolve the stack traces of the runtime, we might need to obtain the debug information for the linked libraries.
If you remember from [the first blog post](/blog/posts/2022/01/13/fantastic-symbols-and-where-to-find-them), debuginfo files can help us.
Debuginfo files for software packages are available through package managers in Linux distributions.
Usually for an available package called `mypackage` there exists a `mypackage-dbgsym`, `mypackage-dbg` or `mypackage-debuginfo` package.
There are also [public servers](https://sourceware.org/elfutils/Debuginfod.html) that serve debug information.
So we need to find the debuginfo files for the runtime we are using and all the linked libraries.

### Finding the symbols for our target program

The symbols that we look for in our own program likely are stored in a memory table that is specific to the runtime.
For example, in Python, the symbol mappings can be accessed using [`symtable`](https://docs.python.org/3/library/symtable.html).

As a result, you need to craft a specific routine for each interpreter runtime (in some cases, each version of that runtime) to obtain symbol information.
Educated eyes might have already noticed, it's not an easy undertaking considering the sheer amount of interpreted languages out there.
For example, a very well known Ruby profiler, [rbspy](https://github.com/rbspy/rbspy/blob/master/ARCHITECTURE.md), generates code for reading internal structs of the Ruby runtime for each version.

If you were to write a general-purpose profiler, _like us_, you would need to write a special subroutine in your profiler for each runtime that you want to support.

## _Again_, don't worry, we got you covered

The good news is we got you covered. If you are using [Parca Agent](https://github.com/parca-dev/parca-agent), we already do [the heavy lifting](https://www.parca.dev/docs/symbolization) for you to symbolize captured stack traces.
And we keep extending our support for the different languages and runtimes.
For example, Parca has already support for parsing `perf` JIT interface to resolve the symbols for collected stack traces.

Check [Parca](https://www.parca.dev/) out and let us know what you think, on [Discord](https://discord.gg/ZgUpYgpzXy) channel.

### Further reading

- [perf JIT Interface](https://github.com/torvalds/linux/blob/master/tools/perf/Documentation/jit-interface.txt)
- [perf JIT Symbols](https://www.brendangregg.com/perf.html#JIT_Symbols)
- [Node.js profiling tips and tricks](https://joyeecheung.github.io/blog/2018/12/31/tips-and-tricks-node-core/)
- [Node.js Flamegraphs](https://www.brendangregg.com/blog/2014-09-17/node-flame-graphs-on-linux.html)
