---
title: "Go runtime futures: flight recording, USDT, and the instrumentation hook problem"
description: "Go 1.25's flight recorder shipped, HTTP client tracing still has gaps, and USDT probes show one possible future for Go runtime observability."
date: 2026-08-02T00:00:00Z
publishDate: 2026-08-02T00:00:00Z
draft: true
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
series: "How to Instrument Go Without Changing a Single Line of Code"
showToc: true
tocOpen: false
---

The honest summary of Go's instrumentation story in 2026: one long-awaited feature shipped, one proof of concept shows what's possible, and two open proposals document gaps that have caused real production problems for years.

## Flight recording shipped in Go 1.25

[golang/go#63185](https://github.com/golang/go/issues/63185), the flight recorder proposal, is closed. It shipped.

Go 1.25 includes a JFR-style circular buffer tracer in the `runtime/trace` package. Instead of streaming trace data to a file continuously, it keeps the last N seconds of execution trace data in memory and snapshots on demand. The API is a config struct, not setter methods:

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
// buf now contains the last ~2 seconds of trace data
```

The `go.dev/blog/flight-recorder` post (published September 2025) covers the design. One constraint worth knowing: only one goroutine can call `WriteTo` at a time; concurrent snapshots return an error. Set `MinAge` to roughly 2x the time window of the event you're trying to capture.

This is directly useful for production debugging. OBI and the eBPF profiler tell you something is slow; flight recording tells you what the Go runtime was doing during that window, on demand, without always-on trace overhead. You deploy the flight recorder, wire `WriteTo` to your error handler or a debug HTTP endpoint (`net/http/pprof`-style), and get trace data only when something goes wrong.

## The httptrace gap that breaks HTTP/2 spans

[golang/go#75654](https://github.com/golang/go/issues/75654) is an open proposal for a hook called `GotResponseEnd` on `httptrace.ClientTrace`. The missing hook matters because the absence of this hook has a concrete, ongoing production impact on OTel Go users.

The gap: there is no reliable, protocol-agnostic hook for when an HTTP client response body is fully consumed. `PutIdleConn` is the workaround OTel Go currently uses to detect response completion, but `PutIdleConn` is never called for HTTP/2 or HTTP/3 connections. The result is that OTel Go client spans never finish on HTTP/2. They hang open indefinitely. This is tracked in [OpenTelemetry Go contrib issue #4876](https://github.com/open-telemetry/opentelemetry-go-contrib/issues/4876), and it's still open.

The proposed fix is simple:

```go
// Add to httptrace.ClientTrace:
GotResponseEnd func(err error)
// Fires exactly once per request when resp.Body.Read returns io.EOF,
// a non-nil error, or the body is closed early.
```

This gap has existed in some form since [golang/go#16400](https://github.com/golang/go/issues/16400) in 2016. The newer proposal (#75654, filed September 2025) reframes it with the OTel use case as the concrete motivation. No acceptance decision yet.

## #69887: why compile-time instrumentation has rough edges

[golang/go#69887](https://github.com/golang/go/issues/69887) is Romain Marcadier's proposal for improvements to `-toolexec`, the mechanism that Orchestrion and otelc use to intercept the Go compilation pipeline. It documents two specific gaps that explain why these tools have sharper edges than they should.

First: there's no way for a `-toolexec` tool to influence the build cache on a per-package basis. The only hook point forces cache invalidation at the full-build level. Every untouched package gets rebuilt from scratch because there's no way to say "I didn't transform this package, use the cache." This is why `otelc go build` is slower than `go build` even when most of your packages don't need instrumentation.

Second: the toolchain doesn't tell `-toolexec` tools what the full build arguments are. Orchestrion currently crawls its own process tree looking for a parent `go build` invocation and parses its arguments. That's the kind of workaround you write when the API doesn't give you what you need.

Go team member Austin Clements engaged substantively on the issue, confirming the gaps are real. No acceptance verdict yet, but it's on the incoming proposals list.

## USDT: a proof of concept worth watching

USDT (User Statically-Defined Tracing) probes are compiled into a binary as NOP instructions. When unattached, overhead is essentially zero. When a consumer attaches, whether bpftrace, perf, or a custom eBPF program, the NOP is replaced with an INT3 interrupt and the kernel delivers the event. It's the same kernel path as uprobes once attached; the advantage is that the probe sites are stable, named, and documented as part of the binary's interface rather than tied to internal function addresses.

The Go runtime doesn't ship USDT probes. As of late 2024, the Go team was at an initial-inquiry stage on [golang/go#57175](https://github.com/golang/go/issues/57175) with no roadmap commitment.

My `poc_usdt` fork ([GitHub](https://github.com/kakkoyun/go/tree/poc_usdt)) is a proof of concept that adds USDT probes to `net/http`, `database/sql`, `crypto/tls`, and `net` via a `go tool usdt` subcommand. You can build a Go binary from the fork and list its probes:

```bash
$ go tool usdt list ./myserver
PROVIDER   NAME                  ADDRESS     ARGUMENTS
net_http   server_request_start  0x63296c    8@%rsi -8@%r8

$ go tool usdt bpftrace ./myserver > trace.bt
$ sudo bpftrace trace.bt
```

Any binary built with the fork gets standard library instrumentation automatically — no SDK import, no application code changes. The probe sites follow the standard `.note.stapsdt` ELF format, so existing eBPF tooling works without modification.

For Go bindings to libstapsdt (for runtime probe creation rather than compile-time), the canonical library is [`github.com/mmcshane/salp`](https://github.com/mmcshane/salp). Note: `github.com/mmcloughlin/salp` returns 404; it is `mmcshane`, not `mmcloughlin`.

This is still a proof of concept. The fork isn't proposed for upstream acceptance, ARM64 argument parsing in bpftrace has issues, and the salp library has compatibility problems with Go 1.25+. But it demonstrates that the approach is technically sound. The standard library hooks are there; the question is whether the Go team will commit to maintaining them.

## What is already usable

Flight recording is the concrete win: it shipped, you can use it today with Go 1.25. The other threads are open proposals with real use cases behind them: the httptrace hook gap causing open spans on HTTP/2, the `-toolexec` improvements needed to make compile-time instrumentation production-grade, and USDT probes in the standard library.

The gap between "Go is easy to operate" and "Go is easy to instrument" is narrowing. It's just narrowing slowly.
