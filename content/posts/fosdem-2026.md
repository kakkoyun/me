---
title: "FOSDEM 2026: Even Bigger, Even Better"
description: "FOSDEM 2026 highlights — OTel Unplugged, Go Devroom, Software Performance Devroom, and the hallway track that never disappoints."
date: 2026-02-13T00:00:00Z
publishDate: 2026-02-13T00:00:00Z
categories:
  - journal
tags:
  - blog
  - fosdem
  - open-source
  - go
  - opentelemetry
  - observability
  - performance
cover:
  image: /uploads/fosdem26_ebpf_devroom.jpeg
  alt: eBPF Devroom at FOSDEM 2026
  caption: eBPF Devroom at FOSDEM 2026
---

### Another Year, Another FOSDEM

**FOSDEM** — the annual Brussels pilgrimage. If you've been, you know the drill: too many talks, too little time, questionable coffee, and the kind of conversations that only happen when you pack thousands of open-source developers into a university campus in the dead of winter.

This year was different for me, though. Two talks in two devrooms, three sessions at OTel Unplugged — and this time, I brought the whole family. My wife and our toddler (who has graduated from "can barely walk" to "can absolutely destroy a hotel room in under four minutes") came along, and we turned it into a proper trip — FOSDEM, then a few days exploring **Ghent** and **Antwerp** before heading home.

The conference part was incredible. The journey home... well, we'll get to that.

### Saturday Morning: eBPF Devroom

Last year the eBPF Devroom was impenetrable — nobody leaves, nobody gets in. This year I made it in early and spent the morning there.

Three sessions stood out:

- **"[eBPF Hookpoint Gotchas: Why Your Program Fires (or Fails) in Unexpected Ways](https://fosdem.org/2026/schedule/event/8GVBN7-ebpf-hooks-gotchas/)"** — Donia Chaiehloudj and Chris Tarazi walked through the subtle behaviors of kprobes, fentry, tracepoints, and uprobes that catch everyone off guard. The kind of talk where half the room is nodding along because they've hit these exact edge cases in production. If you write eBPF programs, this is required viewing.

- **"[Performance and Reliability Pitfalls of eBPF](https://fosdem.org/2026/schedule/event/H3LM7G-performance_and_reliability_pitfalls_of_ebpf/)"** — Usama Saqib shared hard-won lessons from running eBPF at scale: kprobe performance varying across kernel versions, fentry stability issues, and the challenges of scaling uprobes. Directly relevant to anyone using eBPF-based auto-instrumentation — the kind of detail you don't find in documentation.

- **"[OOMProf: Profiling Go Heap Memory at OOM Time](https://fosdem.org/2026/schedule/event/VTXQSK-oomprof/)"** — Tommy Reilly presented OOMProf, a Go library that uses eBPF to hook into Linux OOM tracepoints and capture heap profiles right before the kernel kills your process. Exports to pprof or Parca. The intersection of Go, eBPF, and profiling — three things I care deeply about.

The eBPF Devroom continues to be one of the most technically dense tracks at FOSDEM. Every talk assumes you already know the basics and goes straight to the edge cases and production realities.

### Sunday: Two Talks, Two Devrooms

Sunday was a double-header. Two talks in two devrooms.

**Augusto de Oliveira** and I co-presented **"How to Reliably Measure Software Performance"** in the **Software Performance Devroom**.

![Kemal and Augusto presenting at the Software Performance Devroom](/uploads/fosdem26_perf_talk_close.jpeg)

The talk opened with one of my favorite stories in science: the OPERA experiment that appeared to show neutrinos traveling faster than the speed of light, only for the root cause to be a single fiber-optic cable that wasn't fully plugged in. That's benchmarking in a nutshell — a world where loose cables are everywhere and your numbers are lying to you until you prove otherwise.

We covered the full stack of what it takes to measure reliably. **Environment control**: bare metal instances, disabling SMT, CPU affinity, cache management. **Benchmark design**: making measurements representative and repeatable. **Statistical rigor**: because if you're not thinking about variance, you're not thinking. And then the part I'm most excited about — **integrating benchmarks into development workflows**. Performance quality gates on PRs, auto-generated regression comments, continuous benchmarking infrastructure. We showed what we've built at Datadog and pointed to the open-source alternatives available today.

> "Performance matters. It's not always the first thing we think about when building software. But in the end, performance is what users experience."

The Performance Devroom had a strong lineup all day. The audience was deeply technical — people who care about p99 latencies and can argue for an hour about whether your benchmark harness is introducing measurement bias. My kind of crowd.

The [technical blog post](/posts/fosdem-2026-measuring-software-performance/) goes deeper, and the [talk page](/talks/how-to-reliably-measure-software-performance/) has the slides and recording.

Then I crossed campus to the **Go Devroom**. My kind of room.

**Hannah S. Kim** and I presented **"How to Instrument Go Without Changing a Single Line of Code"** — a talk comparing every strategy available today for zero-touch Go observability.

![Hannah and Kemal presenting at the Go Devroom](/uploads/fosdem26_go_crowd.jpeg)

We walked through eBPF-based auto-instrumentation with OBI, compile-time manipulation with tools like Orchestrion and the OTel Go compile-time instrumentation project, runtime injection via LD_PRELOAD, and the emerging world of USDTs for Go.

The core of the talk was practical: benchmark results and small realistic services, compared along three axes — **performance overhead**, **robustness across Go versions**, and **operational friction**. We showed the trade-offs honestly. eBPF gives you zero code changes but needs kernel privileges. Compile-time rewriting gives you the deepest instrumentation but requires a rebuild. The Injector abstracts complexity but is currently Kubernetes-only. There's no silver bullet, just choices with different costs.

We also looked forward at how upcoming work in the Go runtime — flight recording, improved diagnostics primitives, USDT probe generation — could unlock cleaner hooks for future instrumentation. The room was full. The questions were sharp. Hannah handled the eBPF deep-dives while I covered the compile-time and operational integration angles. It worked.

If you want the full technical breakdown, I wrote a [companion blog post](/posts/fosdem-2026-auto-instrumenting-go/) and the [talk page has the slides and recording](/talks/how-to-instrument-go-without-changing-code/).

### Monday: OTel Unplugged

The day after FOSDEM, about a hundred of us gathered at **Sparks Meeting** on Rue Ravenstein for [OTel Unplugged EU 2026](https://opentelemetry.io/blog/2025/otel-unplugged-fosdem/) — an unconference dedicated entirely to OpenTelemetry. No slides, no prepared talks, just session brainstorming, dot-voting, and then splitting into nine rooms across four breakout slots.

I led or co-led **three sessions**: one on **Prometheus and OTel convergence**, one on **OBI/eBPF-based auto-instrumentation**, and one on **the Injector and OBI coordination for Go**. The thread connecting all three was the same question that keeps me up at night: *how do we make applications observable without asking developers to change their code?*

I wrote a [dedicated post covering the full day](/posts/otel-unplugged-eu-2026/), so I won't repeat it here. The short version: the community is converging. Prometheus and OTel maintainers are charting a path together, the Injector vision is expanding beyond Kubernetes, and the various auto-instrumentation approaches for Go are finally being treated as complementary layers rather than competing camps. Read the post for the details.

### The Hallway Track

As always — **the hallway track is the real conference.**

Some of the best conversations happened between sessions, over coffee, during the frantic sprints between ULB buildings. Catching up with **Prometheus maintainers** about v3 adoption and the road ahead. Talking auto-instrumentation strategy with OTel contributors who I'd only known through GitHub issues. Comparing notes on performance engineering practices with people running infrastructure at wildly different scales.

The informal **Prometheus maintainers gathering** was a highlight. Getting the people who build and maintain the project into the same room, away from structured agendas, just talking about what's working and what isn't — that's where real alignment happens. No Zoom call will ever replicate that.

I'm incredibly grateful for the people I managed to see this year. And as always, slightly heartbroken about the ones I missed. FOSDEM is four thousand developers in one place for a weekend, and no matter how fast you move, you can't see everyone.

### Travel and Logistics: The Sequel Nobody Asked For

A FOSDEM without travel drama is, apparently, not something the universe allows for me.

We flew **Berlin to Brussels** on Friday and had a great time — FOSDEM all weekend, OTel Unplugged on Monday, then a few days of family time in **Ghent** and **Antwerp**. Belgian frites, Belgian waffles, Belgian everything. The toddler approved.

Then came Thursday. Our flight home from Brussels to Berlin: first delayed, then cancelled. **Berlin airport shut down.** The coldest winter in twenty years had frozen the city solid. We ended up at a hotel near Brussels airport with a very tired toddler and no plan B.

Friday morning we flew to **Frankfurt** instead. Surely a train from Frankfurt to Berlin would be straightforward? Of course not. The Frankfurt-to-Berlin flight: also cancelled. We rebooked on a train, but our checked luggage was... somewhere. The airline couldn't tell us where. We waited two hours at the airport, watching the carousel go around empty, then gave up and headed to the train station.

Four and a half hours of train ride later, we were finally home. **Antwerp to Berlin: 29.5 hours, door to door.** With a toddler. In the coldest week Germany had seen in two decades.

The luggage? It arrived ten days later. Intact, thankfully. But ten days.

Last year's transport chaos was cute by comparison.

### Looking Forward

**FOSDEM 2026** was my best one yet. Two talks across the weekend, three unconference sessions on Monday, and more hallway track conversations than I can count. The open-source observability community is in a remarkable place right now — Prometheus and OpenTelemetry converging, auto-instrumentation maturing across multiple approaches, and performance engineering finally getting the attention it deserves.

Already thinking about next year. If you're into open source and haven't experienced FOSDEM, just go. You won't regret it.
