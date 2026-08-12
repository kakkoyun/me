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

Go has no universal startup hook for instrumentation, so the available approaches act at different points in the software lifecycle. This talk maps three practical intervention points (build, process start, and kernel) and explains why they complement one another rather than compete.

We cover OBI (OpenTelemetry eBPF Instrumentation), which observes running processes from the Linux kernel without rebuilding them; compile-time instrumentation via otelc and Orchestrion, which rewrites Go code during the build and preserves Go-level semantics across platforms; and the OpenTelemetry eBPF Profiler, which samples whole-node CPU activity without changing applications. Each inherits the strengths and constraints of its intervention point: OBI reaches deployed workloads but cannot infer arbitrary business semantics, while compile-time instrumentation moves earlier where source structure and dependency information are still available.

We connect the signals. Tracing follows requests, profiling finds CPU cost, and the two become much stronger when they share request context. Go cannot use the native thread-local mechanism directly, so pprof labels become the bridge. The talk closes with a decision framework: start with the constraint you cannot change, then add the next layer only when its signal pays for its operational cost.

**Links**

* [gopherconuk-26](https://github.com/kakkoyun/gopherconuk-26) — slides, speaker notes, and repository tooling
* [zeroins](https://github.com/kakkoyun/zeroins)

**Events**

* [GopherCon UK 2026](https://www.gophercon.co.uk/schedule) — Thursday 13 August 2026

**Related**

* [Auto-Instrumenting Go: From eBPF to USDT Probes](/posts/fosdem-2026-auto-instrumenting-go/) — full technical blog post expanding on this talk
