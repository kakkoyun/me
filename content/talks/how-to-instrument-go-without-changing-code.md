---
title: "talk: How to Instrument Go Without Changing a Single Line of Code"
description: "Comparing eBPF, compile-time, runtime injection, and USDT approaches to zero-touch Go instrumentation — with benchmarks across 7 scenarios."
date: 2026-02-01T00:00:00Z
publishDate: 2026-02-13T00:00:00Z
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
  image: https://img.youtube.com/vi/0TvrSebuDPk/maxresdefault.jpg
  alt: How to Instrument Go Without Changing a Single Line of Code
  caption: FOSDEM 2026 — Go Devroom
---

Zero-touch observability for Go is finally becoming real. In this talk, we walk through the different strategies you can use to instrument Go applications without changing a single line of code, and what they cost you in terms of overhead, stability, and security.

We compare several concrete approaches and projects: eBPF-based auto-instrumentation using OpenTelemetry's Go auto-instrumentation agent and OBI (OpenTelemetry eBPF Instrumentation), compile-time manipulation using tools like Orchestrion and the OpenTelemetry Compile-Time Instrumentation SIG, runtime injection via Frida/ptrace, and USDT (User Statically-Defined Tracing) probes — both via libstapsdt and a custom Go runtime fork.

Beyond what exists today, we look at how ongoing work in the Go runtime and diagnostics ecosystem could unlock cleaner, safer hooks for future auto-instrumentation, including flight recording proposals and native USDT support in the Go toolchain.

Throughout the talk, we use benchmark results and small, realistic services to compare these strategies along three axes: performance overhead (latency, allocations, CPU impact), robustness and upgradeability across Go versions and container images, and operational friction (rollout complexity, debugging, and failure modes).

#### Recording

<iframe width="560" height="315" src="https://www.youtube.com/embed/0TvrSebuDPk" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

**Slides**

* [How to Instrument Go Without Changing a Single Line of Code (PDF)](https://github.com/kakkoyun/fosdem-2026/blob/main/presentation.pdf)
  * [Slides - Markdown](https://github.com/kakkoyun/fosdem-2026/blob/main/presentation.md)

**Demo/Code**

* [fosdem-2026](https://github.com/kakkoyun/fosdem-2026)

**Events**

* [FOSDEM 2026 — Go Devroom](https://fosdem.org/2026/schedule/track/go/)
  * [Recording](https://www.youtube.com/watch?v=0TvrSebuDPk)

**Related**

* [Auto-Instrumenting Go: From eBPF to USDT Probes](/posts/fosdem-2026-auto-instrumenting-go/) — full technical blog post expanding on this talk
