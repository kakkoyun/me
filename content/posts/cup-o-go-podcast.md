---
title: "podcast: Cup o' Go — Instrumentation and Blast Radius"
description: I joined Jonathan Hall and Shay Nehmad on Cup o' Go to talk about what APM actually measures, the three ways to instrument Go, and why blast radius is the trade-off that decides between them.
date: 2026-08-11T00:00:00Z
publishDate: 2026-08-17T00:00:00Z
draft: false
categories:
  - talks
tags:
  - talks
  - blog
  - podcast
  - go
  - observability
  - opentelemetry
  - instrumentation
cover:
  image: https://img.youtube.com/vi/EVpax0L5GgQ/maxresdefault.jpg
  alt: Jonathan Hall, Kemal Akkoyun and Shay Nehmad recording an episode of Cup o' Go
  caption: Cup o' Go — Episode 167
showToc: false
tocOpen: false
showCanonicalLink: false
substack: false
---

Jonathan Hall and Shay Nehmad had me on Cup o' Go for episode 167, straight after their GopherCon US recap. We spent about forty minutes on instrumentation: what an APM tool is actually measuring, and the three ways you can get telemetry out of a Go program without asking every team to rewrite their handlers.

The part I enjoyed arguing about most was blast radius. Manual instrumentation is precise and tedious, and it never finishes. eBPF buys you one agent covering every language on the box, at the cost of running code in the kernel, where a bad program can take the whole host down with it. Compile-time instrumentation rewrites the syntax tree behind `go build` through the `-toolexec` hook, which keeps failures scoped to one service and works anywhere Go compiles. People love this dark magic, which I find either reassuring or alarming depending on the day.

We also got into why a trace and a pprof profile answer different questions, how Orchestrion ended up under OpenTelemetry governance, and the least intimidating route into a SIG if you want to start contributing. Shay's bicycle makes an appearance. I was speaking for myself rather than reading from a Datadog brochure, which I hope comes through.

#### Listen

<iframe width="560" height="315" src="https://www.youtube.com/embed/EVpax0L5GgQ" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

**Episode**

* [Cup o' Go E167 — Quick GopherCon recap, and interview with Kemal of Datadog](https://cupogo.dev/episodes/quick-gophercon-recap-and-interview-with-kemal-of-datadog)
    - [Watch on YouTube](https://www.youtube.com/watch?v=EVpax0L5GgQ)
    - [Transcript](https://cupogo.dev/episodes/quick-gophercon-recap-and-interview-with-kemal-of-datadog/transcript)
* [Apple Podcasts](https://podcasts.apple.com/us/podcast/cup-o-go/id1665967724)
* [Spotify](https://open.spotify.com/show/1mVIbuzr22V6fgZwxPj3uv)

**Topics**

* GopherCon US recap, and Austin's talk on fixing the proposal process
* What APM measures, and how request tracing differs from pprof sampling
* Manual, eBPF, and compile-time instrumentation, and what each one costs you
* Orchestrion moving to OpenTelemetry, plus how to find your way into a SIG
* Checklocks, the gVisor static lock checker I keep recommending to people

**Related**

* [talk: Instrument Go Without Changing a Single Line](/talks/instrument-go-without-changing-a-single-line/) — GopherCon UK 2026
* [talk: How to Instrument Go Without Changing a Single Line of Code](/talks/how-to-instrument-go-without-changing-code/) — FOSDEM 2026
* [talk: Unleashing the Go Toolchain](/talks/unleashing-the-go-toolchain/) — what `-toolexec` makes possible
* [Auto-Instrumenting Go: From eBPF to USDT Probes](/posts/fosdem-2026-auto-instrumenting-go/)
* [OpenTelemetry Go Compile-time Instrumentation v1](/posts/go-compile-time-instrumentation-v1/)
