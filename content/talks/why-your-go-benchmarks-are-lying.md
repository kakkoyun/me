---
title: "talk: Why Your Go Benchmarks Are Lying"
description: "A Go benchmark can report a precise number while measuring removed work, an unstable sample, or an uncontrolled machine — and trusting it requires answering three questions."
date: 2026-08-12T00:00:00Z
publishDate: 2026-08-12T00:00:00Z
categories:
  - talks
tags:
  - talks
  - performance
  - benchmarking
  - observability
cover:
  image: https://img.youtube.com/vi/SMNflDmiYbI/maxresdefault.jpg
  alt: Why Your Go Benchmarks Are Lying
  caption: GopherCon UK 2026
---

A benchmark is a measurement system. It can report a precise number while measuring removed work, an unstable sample, or an uncontrolled machine. This talk argues you should trust a Go benchmark only after answering three questions: Is the compiler measuring real work? Is the sample stable enough? Is the difference large relative to the noise?

We work through three layers. Compiler honesty covers dead-code elimination, sinks, constant folding, inlining, timer ordering, and the `B.Loop` construct, which manages the timer for you and keeps the loop body from being optimized away. Statistical interpretation covers repeated samples, benchstat, coefficient of variation, run-count discipline, and the p-hacking traps that inflate false positives. Environment control covers both local machines and CI: Linux frequency and isolation controls, perflock, benchdiff, and the bare-metal runners that shared CI instances are not.

A war story from dd-trace-go ties the layers together. A benchmark measured code the PR did not touch, the same-machine result reversed the CI sign, and code layout was the likely explanation for the small shift that made the result directionally wrong. The companion repositories ship the captured outputs and the tools that turn those lessons into repeatable checks.

#### Recording

<iframe width="560" height="315" src="https://www.youtube.com/embed/SMNflDmiYbI" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

**Links**

* [gopherconuk-26](https://github.com/kakkoyun/gopherconuk-26) — slides, speaker notes, and demo results
* [benchlab](https://github.com/kakkoyun/benchlab) — the `honestbench`, `benchgate`, and `benchenv` CLIs

**Events**

* [GopherCon UK 2026](https://www.gophercon.co.uk/schedule) — Wednesday 12 August 2026, 15:15, The Google Track
  * [Recording](https://www.youtube.com/watch?v=SMNflDmiYbI)

**Related**

* [Why Your Go Benchmarks Are Lying](/series/why-your-go-benchmarks-are-lying/) — the five-part written series
  * [The Go Benchmark That Measured Nothing: Compiler Honesty in testing.B](/posts/go-benchmarks-lying-compiler-honesty/) — part 1
  * [A Single Benchmark Number Is a Lie](/posts/go-benchmarks-lying-statistics/) — part 2
  * [Before CI: Can You Trust a Benchmark on Your Own Laptop?](/posts/go-benchmarks-lying-local-reproduction/) — part 3
  * [Benchmark CI That Doesn't Lie](/posts/go-benchmarks-lying-ci/) — part 4
  * [Three Questions Before You Trust a Benchmark](/posts/go-benchmarks-lying-three-questions/) — part 5
  * Companion posts
    * [Benchmarking Go, quickly](/posts/go-benchmarks-quickly/) — a primer on writing and reading one benchmark, before part 1
    * [The laptop said 230%](/posts/go-benchmarks-laptop-said-230/) — a macrobenchmark where laptop and CI disagreed, between parts 3 and 4
    * [A PR gate that actually fails](/posts/go-benchmarks-pr-gate-that-fails/) — a PR gate catching a slow commit, between parts 4 and 5
    * [A/B is the wrong model for CI](/posts/go-benchmarks-ab-is-the-wrong-model/) — a benchmark's history as a time series, between parts 4 and 5
* [Measuring Software Performance: Why Your Benchmarks Are Probably Lying](/posts/fosdem-2026-measuring-software-performance/) — full technical blog post expanding on this talk
