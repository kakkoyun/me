---
title: "talk: Instrument Go Without Changing a Single Line"
description: "Zero-touch Go instrumentation across build-time, process-start, and kernel intervention points — and why the approaches complement one another rather than compete."
date: 2026-08-13T00:00:00Z
publishDate: 2026-08-13T00:00:00Z
categories:
  - talks
tags:
  - talks
  - go
  - opentelemetry
  - auto-instrumentation
  - ebpf
  - observability
cover:
  image: https://img.youtube.com/vi/tidmOddZOao/maxresdefault.jpg
  alt: Instrument Go Without Changing a Single Line
  caption: GopherCon UK 2026
---

The debugging loop is slow. You cannot reproduce the bug locally, so you add a
log line and redeploy. Wrong place. You do it again. An agent alone does not
fix this: it still has to pick a mechanism, and it has to know what that
mechanism costs.

This talk is about three approaches that take the source edit out of that
loop. Each acts at a different point in the software lifecycle, and each
inherits the strengths and constraints of its intervention point.

**Build time.** [otelc](https://opentelemetry.io/docs/zero-code/go/compile-time/)
rewrites Go code during the build via `-toolexec`, preserving Go-level semantics
across platforms. The rebuild is the cost.

**Process start.** An injector loads a shared library at startup via
`LD_PRELOAD`. No source change, no rebuild. The binary is the constraint. The
Go injector I showed is in development and not released.

**Kernel.** [OBI](https://opentelemetry.io/docs/zero-code/obi/) (OpenTelemetry
eBPF Instrumentation) observes running processes from the Linux kernel without
rebuilding them. Linux, privileges, and kernel contracts are the cost.

We connect the signals. Tracing follows requests, profiling finds CPU cost,
and the two become much stronger when they share request context. Go cannot use
the native thread-local mechanism directly, so [pprof labels become the
bridge](https://github.com/open-telemetry/opentelemetry-specification/blob/main/oteps/profiles/4947-thread-ctx.md#alternative-for-go-support).
The [OpenTelemetry eBPF Profiler](https://github.com/open-telemetry/opentelemetry-ebpf-profiler)
samples whole-node CPU activity without changing applications, and `.gopclntab`
survives even fully stripped static binaries.

The talk closes with a decision framework: start with the constraint you
cannot change, then add the next layer only when its signal pays for its
operational cost.

#### Recording

<iframe width="560" height="315" src="https://www.youtube.com/embed/tidmOddZOao" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

**Links**

* [gopherconuk-26](https://github.com/kakkoyun/gopherconuk-26) — slides, speaker notes, and research
* [zeroins](https://github.com/kakkoyun/zeroins) — offline catalog and agent skill toolkit
* [opentelemetry-agent-skills](https://github.com/ollygarden/opentelemetry-agent-skills) — agent skills for instrumenting Go applications
* [OpenTelemetry community](https://github.com/open-telemetry/community) — SIG calendars, notes, and channels

**Events**

* [GopherCon UK 2026](https://www.gophercon.co.uk/schedule) — Thursday 13 August 2026
  * [Recording](https://www.youtube.com/watch?v=tidmOddZOao)

**Related**

* [How to Instrument Go Without Changing a Single Line of Code](/series/how-to-instrument-go-without-changing-a-single-line-of-code/) — the six-part written series
  * [Why Go can't be monkey-patched (and what people do about it)](/posts/why-go-cant-be-monkey-patched/) — part 1
  * [OBI: eBPF auto-instrumentation for Go in production](/posts/obi-ebpf-auto-instrumentation-go/) — part 2
  * [otelc: zero-touch Go traces at compile time](/posts/otelc-compile-time-go-traces/) — part 3
  * [The fourth signal: continuous profiling without code changes](/posts/continuous-profiling-go-without-code-changes/) — part 4
  * [Go runtime futures: flight recording, USDT, and the instrumentation hook problem](/posts/go-runtime-futures-flight-recording-usdt/) — part 5
  * [Making zero-touch Go observability agent-actionable](/posts/zero-touch-go-observability-agent-actionable/) — part 6
  * Companion posts:
    * [What a uprobe costs, and what USDT buys](/posts/go-uprobe-vs-usdt/) — between parts 2 and 3
    * [See it run: OBI and the eBPF profiler without Kubernetes](/posts/go-instrumentation-see-it-run/) — after part 4
    * [Context across goroutines and connections](/posts/go-context-across-goroutines/) — between parts 4 and 5
* [Auto-Instrumenting Go: From eBPF to USDT Probes](/posts/fosdem-2026-auto-instrumenting-go/) — full technical blog post expanding on this talk
* [Hooking into the Go Toolchain](https://internals-for-interns.com/posts/hooking-into-the-go-toolchain/) — `-toolexec` from a stopwatch to otelc, a guest post on Internals for Interns
