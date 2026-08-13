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
---

The debugging loop is slow. You cannot reproduce the bug locally, so you add a
log line and redeploy. Wrong place. You do it again. An agent alone does not
fix this: it still has to pick a mechanism, and it has to know what that
mechanism costs.

This talk is about three open-source approaches that take the rebuild out of
that loop. Each acts at a different point in the software lifecycle, and each
inherits the strengths and constraints of its intervention point.

**Build time.** [otelc](https://opentelemetry.io/docs/zero-code/go/compile-time/)
rewrites Go code during the build via `-toolexec`, preserving Go-level semantics
across platforms. The rebuild is the cost.

**Process start.** An injector loads a shared library at startup via
`LD_PRELOAD`. No source change, no rebuild. The binary is the constraint.

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

**Links**

* [gopherconuk-26](https://github.com/kakkoyun/gopherconuk-26) — slides, speaker notes, and research
* [zeroins](https://github.com/kakkoyun/zeroins) — offline catalog and agent skill toolkit
* [opentelemetry-agent-skills](https://github.com/ollygarden/opentelemetry-agent-skills) — agent skills for instrumenting Go applications
* [OpenTelemetry community](https://github.com/open-telemetry/community) — SIG calendars, notes, and channels

**Events**

* [GopherCon UK 2026](https://www.gophercon.co.uk/schedule) — Thursday 13 August 2026

**Related**

* [Auto-Instrumenting Go: From eBPF to USDT Probes](/posts/fosdem-2026-auto-instrumenting-go/) — full technical blog post expanding on this talk
