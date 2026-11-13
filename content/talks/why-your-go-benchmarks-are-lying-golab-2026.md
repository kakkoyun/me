---
title: "talk: Why Your Go Benchmarks Are Lying (And How to Stop Them)"
description: "A benchmark moved that could not have moved. Three real incidents, three questions, and one Monday-morning action per question before you trust a Go benchmark number."
date: 2026-11-03T00:00:00Z
publishDate: 2026-11-03T00:00:00Z
categories:
  - talks
tags:
  - talks
  - performance
  - benchmarking
  - observability
cover:
  image: /uploads/golab26_benchmarking_talk.webp
  alt: Kemal Akkoyun on stage at GoLab 2026, presenting the benchmarking talk
  caption: GoLab 2026
---

A benchmark moved that could not have moved. At Datadog our code runs inside the customer's process: a false red wastes our time, a false green costs the customer CPU. This talk is the set of checks we run before we believe a number, and each check earns its place through an incident.

Every section opens on a real incident and asks one of three questions. Is the benchmark measuring real work? Is the sample stable enough? Is the difference large relative to the noise? On a laptop, the compiler deletes the work you meant to measure and a single run is a point. In CI, one workload is not representative and shared runners move under you. No maths on stage: each section says why a check matters and ends with one action you can take on Monday.

A war story from dd-trace-go ties the layers together: a benchmark measured code the pull request did not touch, the same-machine run reversed the CI sign, and code layout was the likely explanation for the small shift. The closing message is that benchmarking is an investment, in tooling and in discipline, and both Datadog and the Go team pay it. If you ship a library, a tool, or a service on a hot path, pay it too.

**Slides**

* [Slides - Markdown](https://github.com/kakkoyun/golab-26/blob/main/talks/go-benchmarks-lying/slides/presentation.md)
* [Speaker notes](https://github.com/kakkoyun/golab-26/blob/main/talks/go-benchmarks-lying/speaker-notes.md)

**Links**

* [golab-26](https://github.com/kakkoyun/golab-26) — both decks, the script, and captured results
* [public-content](https://github.com/kakkoyun/public-content/blob/main/talks/INDEX.md) — the talk archive; this deck is indexed there
* [benchlab](https://github.com/kakkoyun/benchlab) — the `honestbench`, `benchgate`, and `benchenv` CLIs

**Events**

* [GoLab 2026](https://golab.io/) — Tuesday 3 November 2026, 10:45, room Golab #2
  * [Talk page](https://golab.io/talks/why-your-go-benchmarks-are-lying-and-how-to-stop-them)

**Related**

* [Why Your Go Benchmarks Are Lying](/talks/why-your-go-benchmarks-are-lying/) — the GopherCon UK 2026 version, with recording
* [Measuring Software Performance: Why Your Benchmarks Are Probably Lying](/posts/fosdem-2026-measuring-software-performance/) — full technical blog post expanding on this talk
* [How to Instrument Go Without Changing a Single Line of Code](/talks/instrument-go-without-changing-a-single-line-golab-2026/) — the first talk of the pair, given the day before
