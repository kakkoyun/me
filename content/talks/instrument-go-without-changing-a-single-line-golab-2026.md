---
title: "talk: How to Instrument Go Without Changing a Single Line of Code"
description: "Zero-touch Go instrumentation mapped onto the lifecycle of a process: build-time rewriting at compile time, the injector at startup, eBPF in the kernel, and a live probe when the baseline cannot answer the question."
date: 2026-11-02T00:00:00Z
publishDate: 2026-11-02T00:00:00Z
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
  image: /uploads/golab26_zero_touch_talk.webp
  alt: Kemal Akkoyun on stage at GoLab 2026, presenting the zero-touch instrumentation talk
  caption: GoLab 2026
---

A production bug, a service you cannot touch, and a debugging loop measured in deploys. This talk follows one Go process through its lifecycle and finds an instrumentation point at each station: at build time, at process start, and in the kernel.

At build time, otelc rewrites the code during compilation, so the binary ships already instrumented. At process start, the OpenTelemetry injector loads an agent into the process without a rebuild. In the kernel, OBI attaches eBPF probes to a static Go binary and collects traces and metrics from outside the process. Along the way we pick up CPU profiles, see where request correlation across goroutines and connections breaks down, and when the baseline still cannot answer the question, a live debugging probe captures the missing logs and variables within explicit limits.

Zero-touch does not mean zero operational cost. Build-time instrumentation still needs a rebuild, injection needs a compatible loader, and eBPF needs privileges and platform support. The closing sections carry four asks for the Go team, from goroutine-local storage to USDT probes, and the decision table that picks the layer your constraints still allow. Then the talk returns to the opening bug: an agent can close the loop once the evidence is there to act on.

**Slides**

* [Slides - Markdown](https://github.com/kakkoyun/golab-26/blob/main/talks/without-a-single-line/slides/presentation.md)
* [Speaker notes](https://github.com/kakkoyun/golab-26/blob/main/talks/without-a-single-line/speaker-notes.md)

**Links**

* [golab-26](https://github.com/kakkoyun/golab-26) — both decks, speaker notes, and research
* [public-content](https://github.com/kakkoyun/public-content/blob/main/talks/INDEX.md) — the talk archive; this deck is indexed there
* [zeroins](https://github.com/kakkoyun/zeroins) — the `obi-integration`, `otelc-aspect`, `kubectl-obi`, and `kubectl-profiler` commands

**Events**

* [GoLab 2026](https://golab.io/) — Monday 2 November 2026, 15:30, room Golab #1
  * [Talk page](https://golab.io/talks/how-to-instrument-go-without-changing-a-single-line-of-code)

**Related**

* [Instrument Go Without Changing a Single Line](/talks/instrument-go-without-changing-a-single-line/) — the GopherCon UK 2026 version, with recording
* [Why Your Go Benchmarks Are Lying (And How to Stop Them)](/talks/why-your-go-benchmarks-are-lying-golab-2026/) — the second talk, plugged at the end of this one
* [Auto-Instrumenting Go: From eBPF to USDT Probes](/posts/fosdem-2026-auto-instrumenting-go/) — full technical blog post expanding on this talk
* [Hooking into the Go Toolchain](https://internals-for-interns.com/posts/hooking-into-the-go-toolchain/) — `-toolexec` from a stopwatch to otelc, a guest post on Internals for Interns
