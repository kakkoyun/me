---
title: "Why Go can't be monkey-patched (and what people do about it)"
description: "Go has no bytecode, no classloader and no runtime hook. That is why zero-touch instrumentation happens at build time, at process start or in the kernel."
date: 2026-07-02T00:00:00Z
publishDate: 2026-07-02T00:00:00Z
promote: false
categories:
  - engineering
tags:
  - blog
  - go
  - observability
  - opentelemetry
  - ebpf
  - compile-time-instrumentation
  - auto-instrumentation
series:
  - How to Instrument Go Without Changing a Single Line of Code
showToc: true
tocOpen: false
---

Start a Java service with one extra flag and it gets traced, with no source change and no rebuild:

```sh
java -javaagent:agent.jar -jar app.jar
```

The JVM offers each class's bytes to the agent's [`ClassFileTransformer`](https://docs.oracle.com/en/java/javase/21/docs/api/java.instrument/java/lang/instrument/ClassFileTransformer.html) before it defines the class, so the agent can rewrite a method on its way in. Python lets you swap a method at runtime, which is the monkey-patching of the title. That flag is Java's agent slot, and Python doesn't even need one. Go has no such slot, and that follows from how Go was designed.

This is part 1 of 6 in the [How to Instrument Go Without Changing a Single Line of Code](/series/how-to-instrument-go-without-changing-a-single-line-of-code/) series, the written companion to my [GopherCon UK 2026 talk](/talks/instrument-go-without-changing-a-single-line/). We'll hunt for that missing slot the whole way. First we'll see why it isn't there, then visit the three places people stand instead (build time, process start and the kernel) and watch how far each bends to fake it. Parts 2 to 4 take the tools one at a time, part 5 asks what Go itself might add, and part 6 ends with a runbook an agent can follow.

Disclosure: I work at Datadog, which maintains Orchestrion and dd-trace-go, and I'm one of otelc's maintainers, so read my comparisons with that in mind.

## The structural problem

Where would an agent hook in? Go compiles to native machine code, and `go build` gives you a self-contained binary: no bytecode, no classloader, nothing between your code and the CPU. With no bytecode there is nothing to rewrite at load time, and with no classloader there is no moment between "file on disk" and "code executing" to grab. `LD_PRELOAD`, the classic way to push a shared library into any process, needs the dynamic linker, and Go links pure-Go programs statically by default ([more below](#process-start-the-injector)). And Go has no general runtime hook API. The internal `exithook` covers only program termination.

What about `go:linkname`, which lets a package reach unexported runtime symbols? Tracers use it, but listen to how the runtime talks about it. Above `gopark` in [`proc.go`](https://github.com/golang/go/blob/go1.26.0/src/runtime/proc.go#L435-L442):

> "gopark should be an internal detail, but widely used packages access it using linkname. Notable members of the hall of shame include…"

The Go team added those annotations reluctantly. The comment says "Do not remove or change the type signature" and points at [golang/go#67401](https://github.com/golang/go/issues/67401), which locked down future linkname uses. That is an accommodation, not a hook. A hall of shame is an odd place to look for a feature.

No slot, then. If nobody will hand us one, where do people stand instead?

## Three places to intervene

At build time, we intercept the build instead of the program. Go's `-toolexec` flag puts a wrapper in front of every `go tool compile` call. The wrapper parses each source file into a syntax tree, injects instrumentation, and hands the modified source to the real compiler, which thinks you wrote it yourself. The wrapper itself adds no runtime overhead and needs no kernel privilege, but you have to rebuild. I wrote a [guest post](https://internals-for-interns.com/posts/hooking-into-the-go-toolchain/) that builds this mechanism up from a stopwatch.

At process start, we load a library before `main`, with no rebuild. That's the closest cousin of `-javaagent`, and for Go the hardest.

In the kernel, Linux's eBPF subsystem can attach probes to function entry and exit points in a running binary without modifying it. A privileged agent on the node attaches and the Go binary never knows. The price is visibility: you see function boundaries (arguments, return values, call counts), and each tool brings its own kernel and privilege requirements. [Part 2](/posts/obi-ebpf-auto-instrumentation-go/#what-it-requires) has OBI's.

None of them wins outright, so the series treats them as layers. The middle one is the agent slot in its purest form, so we try it first.

## Process start: the injector

An injector is a shared library that the dynamic loader maps in before `main`, so it acts before any of your code does. On a host, Datadog's [Single Step Instrumentation](https://docs.datadoghq.com/tracing/trace_collection/single-step-apm/linux/) arms itself through `/etc/ld.so.preload`, and so does the [OpenTelemetry injector](https://github.com/open-telemetry/opentelemetry-injector/blob/v0.10.1/README.md). The OTel one is a smaller trick than it sounds: it sets variables like `JAVA_TOOL_OPTIONS` and `NODE_OPTIONS`, and the runtime loads its own agent. It types our `-javaagent` flag for us. It covers Java, Node.js, .NET, Ruby, and Python (disabled by default), and its [design notes](https://github.com/open-telemetry/opentelemetry-injector/blob/v0.10.1/DESIGN.md) say statically linked executables "will not be affected by `LD_PRELOAD` at all." Go has no agent slot for such a variable to point at.

Why can't Go take `LD_PRELOAD`? A pure-Go build is a static ELF with no interpreter (the dynamic loader a binary names in its headers), so the loader never runs. With cgo disabled there is no escape hatch, because `-linkmode=external`, which hands the final link to the system C linker, needs cgo. (cgo binaries, including those using the default `net` resolver on Linux, are dynamically linked and take `LD_PRELOAD` on glibc.) [golang/go#28909](https://github.com/golang/go/issues/28909) is still open as of October 2026, and Ian Lance Taylor was ["perfectly comfortable in saying that anybody who wants to use `LD_PRELOAD` must force the use of external linking."](https://github.com/golang/go/issues/28909#issuecomment-441823877) External linking is supported, but forcing it just for `LD_PRELOAD` is a workaround with sharp edges.

To check yours, run `file ./myapp`. For a small `net/http` program on Go 1.27.1 (linux/arm64), `CGO_ENABLED=0` printed `statically linked` and `CGO_ENABLED=1` printed `dynamically linked, interpreter /lib/ld-linux-aarch64.so.1`. Even the dynamic one offers no slot: a preloaded library interposes on dynamic symbols such as libc's `read`, and `readelf --dyn-syms` shows no `net/http` function to wrap.

Datadog has a Go injector hook in development, which I'll show on a slide at GopherCon UK. It isn't released, so I'm not going into how it works yet.

For a pure-Go binary the slot stays empty. That leaves build time, and even that route has to fake something Java ships with: a place to keep the current request's context.

## The goroutine problem

Distributed tracing is where it bites. A request often hops goroutines (Go's lightweight threads), and its trace context has to hop with it. Go has no goroutine-local storage, so after `go func() { ... }()` there is no built-in way to inherit arbitrary values from the parent (pprof labels aside, which are string pairs for profiles). The usual answer is to pass a `context.Context` down by hand, which is the code change this series is trying to avoid. Code injected into a library function often has no `ctx` in scope anyway, so the tracer needs somewhere else to keep the context.

Orchestrion, Datadog's `-toolexec` tool from [part 3](/posts/otelc-compile-time-go-traces/), answers with something striking: give the tracer somewhere to keep it. dd-trace-go [v2.0.0 ships an aspect](https://github.com/DataDog/dd-trace-go/blob/v2.0.0/internal/orchestrion/gls.orchestrion.yml) that injects a synthetic field into the runtime's internal `g` struct, the one that represents each goroutine. The start of it, abridged:

```yaml
aspects:
  - id: __dd_gls_v2
    join-point:
      struct-definition: runtime.g
    advice:
      - add-struct-field:
          name: __dd_gls_v2
          type: any
```

The join point says where to cut and the advice says what to add: a field `__dd_gls_v2 any` on `runtime.g`. Orchestrion rewrites the `runtime` source before the compiler sees it, so every goroutine gets one. The same aspect injects a getter and a setter as `go:linkname`d function variables. Here is that template, re-indented the way gofmt would print it:

```go
//go:linkname __dd_orchestrion_gls_get __dd_orchestrion_gls_get.V2
var __dd_orchestrion_gls_get = func() any {
	return getg().m.curg.__dd_gls_v2
}

//go:linkname __dd_orchestrion_gls_set __dd_orchestrion_gls_set.V2
var __dd_orchestrion_gls_set = func(val any) {
	getg().m.curg.__dd_gls_v2 = val
}
```

`getg()` asks the runtime for the current goroutine, and `.m.curg` goes through the `m` (the OS thread running it) to make sure it's yours and not a system one, per the runtime's [`HACKING.md`](https://github.com/golang/go/blob/go1.26.0/src/runtime/HACKING.md). A second aspect sets the field to nil at the top of `goexit1`, so finished goroutines don't leak their context.

The field doesn't follow a `go` statement by itself: dd-trace-go still carries a [`TODO: handle cross-goroutine context values`](https://github.com/DataDog/dd-trace-go/blob/v2.0.0/internal/orchestrion/context_stack.go#L10) in its context stack. [otelc goes further](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.0.1/instrumentation/runtime/otelc.yaml). It adds its own fields to `g` (`otel_trace_context` and `otel_baggage_container`) and copies them in `newproc1` when a goroutine starts, so trace context and baggage follow `go` statements. That is still not the request's `context.Context`: its values, deadline and cancellation stay behind, and carrying trace context from an incoming connection to an outgoing one is unsolved; [Context across goroutines and connections](/posts/go-context-across-goroutines/) shows where it breaks in a small program. [Part 5](/posts/go-runtime-futures-flight-recording-usdt/#observing-isnt-propagating) comes back to it.

Back to the agent slot. Other runtimes have a designed hook point for this: thread-local storage in Java, `contextvars` in Python, `AsyncLocalStorage` in Node.js. Go's answer is to patch the runtime's struct layout at build time and hope the runtime keeps allowing it. Impressive engineering, and a fair measure of how far you bend to fake what Java ships with.

Who is standing on those three spots?

## The tools in this series

Four tools. OBI (OpenTelemetry eBPF Instrumentation, which started life as Grafana Beyla) is the kernel path with no rebuild: [part 2](/posts/obi-ebpf-auto-instrumentation-go/). otelc (OpenTelemetry Go compile-time instrumentation) takes the `-toolexec` path and needs Go 1.25 or newer, and Orchestrion uses the same mechanism with the goroutine hack above: [part 3](/posts/otelc-compile-time-go-traces/). The OpenTelemetry eBPF profiler is the kernel path for profiles: [part 4](/posts/continuous-profiling-go-without-code-changes/).

None of them is clean. They're workarounds for a runtime built for simplicity, not observability, but they work. The kernel route needs no rebuild, so that's where we go next.

Versions, links and commands checked on 2 October 2026.

## Up next

[Part 2, OBI: eBPF auto-instrumentation for Go in production](/posts/obi-ebpf-auto-instrumentation-go/), takes the kernel route: what OBI covers, what it needs, and what it costs. Java gets a flag. Go gets a kernel probe and some paperwork.
