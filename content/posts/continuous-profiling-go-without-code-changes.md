---
title: "The third signal: continuous profiling without code changes"
description: "Why stripped Go binaries still carry enough runtime metadata for eBPF profiling, and where OpenTelemetry's profiling signal fits in a zero-touch observability stack."
date: 2026-07-31T00:00:00Z
publishDate: 2026-07-31T00:00:00Z
draft: true
categories:
  - engineering
tags:
  - blog
  - go
  - observability
  - opentelemetry
  - ebpf
  - profiling
series:
  - How to Instrument Go Without Changing a Single Line of Code
showToc: true
tocOpen: false
---

Most tools that profile Go binaries have one dependency you can't avoid in production: debug symbols. Strip your binary, as you should to cut image size and reduce attack surface, and the profiler can't symbolize the stack frames. You get addresses, not function names.

The `opentelemetry-ebpf-profiler` doesn't have this problem. The reason is specific to Go, and it's worth understanding why.

## .gopclntab: the debug info Go can't remove

Go's runtime needs to walk the call stack at any time: for panics, for the garbage collector, for goroutine dumps. It does this using an internal table called `.gopclntab`, the program-counter-to-line-number table. This table maps raw instruction addresses to function names, file names, and line numbers.

The critical property: the runtime always needs `.gopclntab`, so it survives `strip`. Even a fully static, stripped production binary retains this table. The profiler documentation says that table lets it symbolize and unwind production executables even when they are static and stripped.

This is the opposite of almost every other profiler's situation. Tools that rely on DWARF debug info or frame pointers fail silently on stripped binaries. The eBPF profiler reads `.gopclntab` instead, so it works correctly on exactly the binaries you actually ship.

For C and C++ code, the profiler takes a different path. It uses `.eh_frame` data, the exception handling table, which is also present in stripped binaries. Neither path requires frame pointers or separate debug symbol packages. Your production containers don't need to change.

## What the profiler actually is

The project started as Elastic Universal Profiling Agent. Elastic donated it to OpenTelemetry in June 2024, completing the transfer via [OTel community issue #1918](https://github.com/open-telemetry/community/issues/1918). It now lives at `github.com/open-telemetry/opentelemetry-ebpf-profiler` and ships as an official OpenTelemetry Collector receiver called `otelcol-ebpf-profiler`. The current version tag is `v0.0.202627` — the project uses calendar-week versioning (ISO week 27 of 2026) rather than numbered releases.

The mechanism is straightforward: an eBPF program fires on CPU sample events at the kernel level and reads process-internal data structures from outside the target process. No LD_PRELOAD, no ptrace, no agent injection. The profiler attaches from the kernel side; the profiled application is completely unaware. The README states it plainly: "No need to load agents or libraries into the processes that are being profiled. No need for any reconfiguration, instrumentation or restarts."

You deploy it as a DaemonSet: one instance per node, covering every workload running on that node.

## What "zero code changes" actually means

The profiled applications need nothing. No rebuild, no restart, no SDK import. That part is real.

The profiler node does require extra privileges: root, or at minimum `CAP_BPF` and `CAP_PERFMON`. You also need a minimum Linux kernel version with eBPF support (check the current README for the exact number before deploying). On macOS, you need a Linux VM or container runtime because eBPF is a Linux kernel feature.

This is a deployment requirement, not a per-service requirement. You run the profiler once per node and it covers everything. That's what makes it useful at scale: one configuration change instruments an entire Kubernetes cluster.

## The signal status: Alpha

The OTel profiling signal occupies an interesting position in the spec maturity matrix.

| Layer | Status |
|-------|--------|
| OTel specification (`/docs/specs/otel/profiles/`) | **Alpha** |
| OTLP wire format (OTLP 1.11.0) | **Development** |
| Traces / Metrics / Logs (for comparison) | Stable / Stable / Stable |

The profiler's README is explicit: "Implements the Alpha OTel Profiles signal." Do not read "OTel Collector receiver" and assume this is production-stable in the OTel spec sense. Alpha means evolving, not backward-compatibility-guaranteed.

What the profiler does produce today, reliably: CPU profiling at the OS-thread level, with correct Go function names via `.gopclntab`. goroutine-level profiling (as distinct from OS threads) is not confirmed in the current release. Neither is allocation profiling. The core use case works: always-on CPU flame graphs for production Go services with zero source changes.

## The third signal

If you're building a zero-touch observability stack for Go, the shape looks like this:

- **OBI** (OpenTelemetry eBPF Instrumentation): traces and RED metrics for HTTP/gRPC, no rebuild required, runtime attach.
- **otelc** (OTel compile-time instrumentation): granular spans with exact function-level detail, local dev, requires a rebuild.
- **OpenTelemetry eBPF profiler**: always-on CPU profiles, whole-system, DaemonSet deploy.

These three cover the full signal triad, traces, metrics, and profiles, without a single source change in the application code.

The useful move is concrete: jump from a slow trace to the flame graph for the same time window. Traces tell you a request was slow. Profiles tell you where the CPU actually went during that slow period. Having both signals correlate via OTel's data model (profiles include trace context) means you can pivot from a slow trace directly into the flame graph for that time window.

It's still Alpha. The signal spec will evolve. But the underlying capability is real and running in production today: continuous CPU profiling with correct symbolization of stripped Go binaries, deployed as a DaemonSet, exported as OTLP.
