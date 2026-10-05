---
title: "Go runtime futures: flight recording, USDT, and the instrumentation hook problem"
description: "Go 1.25's flight recorder shipped and HTTP client tracing has gaps. My tracing and USDT forks are experiments, and context propagation is unsolved."
date: 2026-07-30T00:00:00Z
publishDate: 2026-07-30T00:00:00Z
promote: false
categories:
  - engineering
tags:
  - blog
  - go
  - observability
  - opentelemetry
  - tracing
  - usdt
  - ebpf
  - auto-instrumentation
series:
  - How to Instrument Go Without Changing a Single Line of Code
showToc: true
tocOpen: false
---

Every route in this series goes around the Go runtime: rewrite the source at build time, inject something at process start, or watch from the kernel, because Go gives us no agent API to plug into. This time we ask the runtime what it could hand us. The honest summary for 2026: one long-awaited feature shipped, two open proposals document gaps that have caused real production problems for years, and two experiments of mine are aspirations, not proposals.

This is part 5 of 6 in the [How to Instrument Go Without Changing a Single Line of Code](/series/how-to-instrument-go-without-changing-a-single-line-of-code/) series, the written companion to my [GopherCon UK 2026 talk](/talks/instrument-go-without-changing-a-single-line/). [Part 4](/posts/continuous-profiling-go-without-code-changes/) left us in the kernel with a profiler. Now we step outside the three intervention points and knock on the runtime's door four times (the [FOSDEM 2026 post](/posts/fosdem-2026-auto-instrumenting-go/) covers the last knock at more length).

Disclosure: I work at Datadog, which maintains Orchestrion, and I'm one of otelc's maintainers. The `poc_flight_recorder` and `poc_usdt` forks below are my own experiments.

## Flight recording shipped in Go 1.25

Let's start with the door that opened. [golang/go#63185](https://github.com/golang/go/issues/63185), the flight recorder proposal, is closed. It shipped.

Go 1.25 includes a circular buffer tracer in `runtime/trace`, in the spirit of Java Flight Recorder (which has been around for a while, so allow Go a small victory lap). It records Go's execution trace, not OpenTelemetry spans: goroutine, syscall and GC events, read with `go tool trace`, not Jaeger. Instead of streaming trace data to a file, it keeps the last N seconds in memory and snapshots on demand. Here's a sketch of asking for it, imports left out. The API is a config struct, not setter methods:

```go
fr := trace.NewFlightRecorder(trace.FlightRecorderConfig{
	MinAge:   2 * time.Second,
	MaxBytes: 64 * 1024 * 1024,
})

if err := fr.Start(); err != nil {
	log.Fatal(err)
}

// Later, on a slow request or error:
var buf bytes.Buffer
if _, err := fr.WriteTo(&buf); err != nil {
	log.Println("flight recorder:", err)
}
// buf now holds at least the last 2 seconds of trace data
// (MinAge is a lower bound; MaxBytes wins if they conflict)
```

`Start` begins recording and `WriteTo` copies the buffer out when something goes wrong. Notice that every line of it lives in our service's code. Hold that thought.

OBI (OpenTelemetry eBPF Instrumentation) tells you something is slow; flight recording tells you what the runtime was doing at the time. "On demand" has a catch: the recorder traces continuously, so you pay for tracing and for the in-memory buffer all the time ([the Go blog post](https://go.dev/blog/flight-recorder) puts a busy service at around 10 MB/s of trace data, and suggests a `MinAge` of about 2x the event window). Only writing and keeping the data is on demand: wire `WriteTo` to your error handler or a debug HTTP endpoint (`net/http/pprof`-style; only one goroutine may call `WriteTo` at a time, and a concurrent call returns an error), and you keep a trace only when something goes wrong.

I pushed on this API too. My [`poc_flight_recorder` fork](https://github.com/kakkoyun/go/tree/1f6836932a219381e4088d61cafdfefadd0dd03c) adds an `EventFilter` bitmask (`FilterHTTP`, `FilterSQL`, `FilterNet` and friends) with `SetEventFilter`, `SetSampleRate`, W3C `TraceContext` parsing, and `HTTPServerRequest` and `HTTPClientRequest` spans to `runtime/trace`, aiming at always-on distributed tracing. That's an aspiration. I don't expect the Go team to extend the flight recorder this way. The [FOSDEM post](/posts/fosdem-2026-auto-instrumenting-go/) has the longer write-up.

The runtime handed us a way to watch itself. The libraries built on it are another story, and the HTTP client is where it hurts.

## The httptrace gap that breaks HTTP/2 spans

[golang/go#75654](https://github.com/golang/go/issues/75654) is an open proposal for a hook called `GotResponseEnd` on `httptrace.ClientTrace`. No hook reliably tells the client, on every protocol, that a response body has been fully consumed. `PutIdleConn` is the workaround OTel Go uses, but the standard library documents that hook as not used for HTTP/2, so on HTTP/2 OTel Go's `http.receive` client span is never ended. That's tracked in [OpenTelemetry Go contrib issue #4876](https://github.com/open-telemetry/opentelemetry-go-contrib/issues/4876), which was still open in October 2026. In the sources I read, otelc's `net/http` client hook (v1.1.0) doesn't reference `httptrace`, and OBI watches `net/http` with uprobes instead, so neither should hit this, though I haven't tested HTTP/2 spans from either.

As filed, the fix is simple. This is the proposal's pseudo-code, not something `httptrace` has today:

```go
// Add to httptrace.ClientTrace:
GotResponseEnd func(err error)
// Fires exactly once per request when resp.Body.Read returns io.EOF,
// a non-nil error, or the body is closed early.
```

One callback, fired once. The shape is still being argued over, with commenters asking about responses with no body and bodies the application never reads, and there's no acceptance decision yet.

That's one hook a library can't get. The next ask is about how the tools from part 3 get between us and the compiler.

## Why compile-time instrumentation has rough edges

Orchestrion and otelc (OpenTelemetry Go compile-time instrumentation) intercept the compilation pipeline with `-toolexec`, as we saw in [part 3](/posts/otelc-compile-time-go-traces/). [golang/go#69887](https://github.com/golang/go/issues/69887) is Romain Marcadier's proposal to improve it. Two of its gaps explain why these tools have sharper edges than they should.

First, a `-toolexec` tool can't influence the build cache per package. The only hook point is intercepting the `-V=full` version probe, which works at the level of the complete build, so the issue describes excessively frequent cache invalidation for untransformed packages. otelc changes every tool's version line, so instrumented builds never share cache entries with plain `go build`; its own cache keeps warm rebuilds fast. My [guest post](https://internals-for-interns.com/posts/hooking-into-the-go-toolchain/#the-cache-will-lie-to-you) shows what the cache does to `-toolexec` tools, and [what that costs](https://internals-for-interns.com/posts/hooking-into-the-go-toolchain/#back-to-the-stopwatch). Second, the toolchain doesn't tell `-toolexec` tools the full build arguments, so Orchestrion crawls its own process tree looking for a parent `go build` invocation and parses its arguments. That's the workaround you write when the API won't give you what you need.

Did the Go team agree? Two members replied, leaning different ways. Michael Matloob said dedicated support for source-rewriting tools would add a lot of complexity to the `go` command and that he doesn't think the costs are worth it. Austin Clements called it a useful problem report and line-information handling a known weakness, and suggested `go list` plus `-overlay` as a way around the build-graph changes. As of October 2026 it's still at Incoming on the proposals project. A neighbouring ask, a hook on goroutine start ([golang/go#73798](https://github.com/golang/go/issues/73798)), was closed as not planned on the day of filing, with a first reply that pointed at `toolexec` rewrites.

Both asks are about things Go already has. Our last stop is something it doesn't: probes.

## USDT: an experiment toward tracepoints

USDT (User Statically-Defined Tracing) probes are named sites compiled into a binary as NOP instructions, which do nothing. When a consumer such as bpftrace, perf, or a custom eBPF program attaches, the NOP is replaced with an INT3 interrupt and the kernel delivers the event, the same kernel path as uprobes.

What does that buy us over a bare uprobe? Not speed: a USDT site is a uprobe on a NOP, so it still costs a trap per hit, and my fork computes its arguments even with nothing attached, which I haven't benchmarked. It buys less work for the tool, which reads site addresses and argument locations from the note instead of hunting for every `RET` (no uretprobes, which Go's moving stacks can't survive), and a probe name that can outlive refactors; [What a uprobe costs, and what USDT buys](/posts/go-uprobe-vs-usdt/) has the sources and the numbers.

The Go runtime doesn't ship USDT probes. The closest thing to a discussion is in the notes for the 2024-12-19 performance and diagnostics sync, recorded in [golang/go#57175](https://github.com/golang/go/issues/57175), where Felix Geisendörfer asked whether the Go team had considered USDT support. That's a brainstorm, not a plan, and I'm not aware of a proposal filed since.

Asking nicely only goes so far, so I built one. My [`poc_usdt` fork, pinned at commit `c739f4e`](https://github.com/kakkoyun/go/tree/c739f4e38a792c85c22ab79ec6b44c9bcd0ca691), adds USDT probes to `net/http`, `database/sql`, `crypto/tls`, and `net` via a `go tool usdt` subcommand. Once we build a binary from the fork, we can list its probes and generate a bpftrace script:

```bash
$ go tool usdt list ./myserver
PROVIDER   NAME                  ADDRESS     ARGUMENTS
net_http   server_request_start  0x63296c    8@%rsi -8@%r8 8@%rdx -8@%r9
net_http   server_request_end    0x631c5c    -4@%ecx

$ go tool usdt bpftrace ./myserver > trace.bt
$ sudo bpftrace trace.bt
```

That listing is abridged from the fork's [README](https://github.com/kakkoyun/go/blob/c739f4e38a792c85c22ab79ec6b44c9bcd0ca691/src/runtime/trace/usdt/README.md).

On Linux, a binary built with the fork and the internal linker gets standard library instrumentation automatically, with no SDK import and no application code changes. (On darwin the probes compile to nothing, and external linking currently drops them.) The probes are standard `.note.stapsdt` ELF notes, so `readelf -n` can read them. bpftrace's `usdt:` attach doesn't find the probes in a static Go binary, so the script `go tool usdt bpftrace` generates uses `uprobe:` probes at the probe addresses instead.

ARM64 argument parsing in bpftrace also has issues with the probe argument notation the fork emits. Nothing here is proposed upstream.

The idea I'd argue for is bigger than USDT: generic tracepoints. Safe, named instrumentation points that the standard library and runtime expose on purpose, with stable arguments external tools can consume. USDT is one way to build them. It needs more work from me (the open items above) and the Go runtime team would have to accept it.

That's all four doors. Only one of them opened. 🚪

## Observing isn't propagating

Tracepoints let a tool see a request. Distributed tracing also has to carry trace headers from the incoming connection to the outgoing ones. Without threading `context.Context` by hand, that needs some goroutine-associated storage, and it must not lose what the request's context already carries: deadlines, cancellation, and values the application attached. [Part 1](/posts/why-go-cant-be-monkey-patched/#the-goroutine-problem) showed tools hacking a field into `g` for this. My fork's `WithSpan` and `SpanFromContext` show the gap from the other side: they ride on `context.Context`, so the context still has to be threaded. [Context across goroutines and connections](/posts/go-context-across-goroutines/) walks that gap with a small program. I have no solution. This is the unsolved part.

## What is already usable

Back to our question: what could the runtime hand us? Shipped: flight recording, on Go 1.25 or newer. Experimental, and mine: the tracing fork and the USDT probes. Unsolved: propagation without threading the context.

Remember the thought we held on to? The answer that shipped wants a few lines in our service, and the probes that need no application changes exist only in my fork. For a series about not changing a single line, that's the gap in a sentence. It's narrowing, just slowly.

Versions, links and commands checked on 2 October 2026.

## Up next

[Part 6, Making zero-touch Go observability agent-actionable](/posts/zero-touch-go-observability-agent-actionable/), pulls the tools together into a decision rule and a skill an agent can run. The runtime may get there on its own schedule. Part 6 is for those of us with a service to debug today.
