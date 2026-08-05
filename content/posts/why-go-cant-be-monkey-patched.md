---
title: "Why Go can't be monkey-patched (and what people do about it)"
description: "Go is structurally hostile to zero-touch instrumentation, from the missing classloader to a goroutine-local storage hack that patches the runtime at compile time."
date: 2026-07-28T00:00:00Z
publishDate: 2026-07-28T00:00:00Z
draft: true
categories:
  - engineering
tags:
  - blog
  - go
  - observability
  - opentelemetry
  - ebpf
  - compile-time-instrumentation
series:
  - How to Instrument Go Without Changing a Single Line of Code
showToc: true
tocOpen: false
---

If you've spent time on Java or Python instrumentation, the zero-touch story is obvious: intercept the bytecode at load time, or swap out a method at runtime, or use an agent that the JVM already knows how to host. Go has none of that. This is not a gap waiting to be filled. It is a consequence of how Go was designed.

## The structural problem

Go compiles to native machine code. When you run `go build`, you get a self-contained binary. You get no bytecode layer, no classloader, and no intermediate representation sitting between your code and the CPU.

That matters because it closes off the standard instrumentation escape hatches:

- No bytecode means you can't rewrite classes at load time. Java agents work because the JVM can intercept `ClassLoader.defineClass` and transform bytecodes before they execute. Go has no equivalent: the compiler runs on your machine, not on the server.
- No classloader means there's no intercept point between "file on disk" and "code executing."
- Go links statically by default. The `LD_PRELOAD` trick, the classic Linux mechanism for injecting a shared library into any process, requires the dynamic linker to run, and Go's internal linker doesn't invoke it. To use `LD_PRELOAD` with a Go binary, you have to force external linking with `-linkmode=external`. That's not a supported feature; it's a workaround with its own sharp edges. Dynatrace's OneAgent documentation says outright: static Go binaries with cgo are unsupported.
- Go exposes no general runtime hook API. Go has an internal `exithook` mechanism, but it is scoped strictly to program termination, not a general interception surface.

What about `go:linkname`? It lets packages access unexported runtime symbols, and you'll find it used in tracers. But the Go runtime source contains this comment in `proc.go`:

> "gopark should be an internal detail, but widely used packages access it using linkname. Notable members of the hall of shame include…"

The Go team added those stubs reluctantly, because enough widely-used packages had already started abusing them. That is not a hook point. It is a "we can't remove this without breaking widely used packages" accommodation.

## What people actually do

Given that the normal approaches don't work, three different strategies have emerged.

**eBPF from the outside.** Linux's eBPF subsystem can attach probes to function entry and exit points in any running binary without modifying it. You don't need to change the Go binary at all. You attach from a privileged sidecar. The constraint is that you're limited to what's observable at function boundaries: arguments, return values, call counts. You can't see inside a function, and you need Linux 5.8+ with BTF enabled.

**Compile-time AST rewriting.** Instead of intercepting at runtime, intercept the build. Go's `-toolexec` flag lets you replace the `go tool compile` invocation with your own wrapper. That wrapper parses each source file into a syntax tree, injects instrumentation code, and hands the modified source to the real compiler. From the compiler's perspective, you just wrote the instrumentation yourself. No runtime overhead from the mechanism, no kernel privileges, but you need to rebuild.

**Runtime injection with caveats.** Some vendors use binary trampolines or shared-library injection on Go binaries built with external linking. This works in narrow conditions and fails in others. For binaries built with `CGO_ENABLED=0`, it typically doesn't work at all.

Of these, compile-time rewriting is currently the most broadly production-ready. It works across Go versions, requires no kernel support, and can instrument network calls and arbitrary code.

## The goroutine problem nobody talks about

Even compile-time approaches hit a wall that exposes how deep Go's structural hostility goes. Consider distributed tracing: you need to propagate a trace context across goroutines. But Go has no goroutine-local storage. By design. If you write `go func() { ... }()`, there's no built-in way to inherit the parent's trace context.

The way Datadog's compile-time tool, Orchestrion, solves this is striking. It injects a synthetic field directly into the Go runtime's internal `g` struct, the struct that represents each goroutine:

```yaml
# internal/orchestrion/gls.orchestrion.yml
join-point:
  struct-definition: runtime.g
advice:
  - add-struct-field:
      name: __dd_gls_v2
      type: any
```

This YAML aspect tells the compiler to add `__dd_gls_v2 any` to `runtime.g`. Every goroutine gets a copy. Then Orchestrion injects `go:linkname` functions to get and set that field:

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

And to prevent memory leaks, a cleanup hook into `goexit1`:

```go
// Injected into runtime.goexit1:
getg().__dd_gls_v2 = nil
```

The consumer side in dd-trace-go checks whether Orchestrion is present at init time and falls back to a no-op if it isn't.

This is genuinely impressive engineering. It's also a sign of how desperate things are: you're patching the Go runtime struct layout at compile time, using `go:linkname` for variable aliasing (which broke between Go 1.22 and 1.23, tracked in golang/go#72032), and relying on a YAML file that references the Go team's own `HACKING.md`. The Go team considers this access pattern deeply unofficial.

Every other major runtime has a designed hook point for this kind of thing. Thread-local storage in Java, `contextvars` in Python, `AsyncLocalStorage` in Node.js. Go's goroutine-local storage solution is: patch the runtime struct and hope the linker's symbol resolution stays stable.

## The three workarounds people ship today

For GopherCon UK 2026, I'm covering three tools that take these approaches seriously:

- **OBI** (OpenTelemetry eBPF Instrumentation, formerly Grafana Beyla) — the eBPF path, zero rebuild required.
- **otelc** (OTel SIG compile-time instrumentation) — the `-toolexec` path, requires Go 1.25+.
- **Orchestrion** (Datadog) — the same mechanism as otelc, battle-tested, includes the GLS hack above.

None of them is a clean solution. They're all workarounds for a runtime that was built for simplicity rather than observability. But they work, and they're worth understanding.
