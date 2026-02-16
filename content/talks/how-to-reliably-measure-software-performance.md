---
title: "talk: How to Reliably Measure Software Performance"
description: "Why your benchmarks are probably lying to you — controlling hardware noise, statistical methods, and integrating performance into development workflows."
date: 2026-02-01T00:00:00Z
publishDate: 2026-02-13T00:00:00Z
categories:
  - talks
tags:
  - talks
  - performance
  - benchmarking
  - observability
cover:
  image: https://img.youtube.com/vi/8211fNI_nc4/maxresdefault.jpg
  alt: How to Reliably Measure Software Performance
  caption: FOSDEM 2026 — Software Performance Devroom
---

Measuring software performance reliably is remarkably difficult. It's a specialized version of a more general problem: trying to find a signal in a world full of noise. A benchmark that reports a 5% improvement might just be measuring thermal throttling, noisy neighbors, or the phase of the moon.

In this talk, we walk through the full stack of reliable performance measurement — from controlling your benchmarking environment (bare metal instances, CPU affinity, disabling SMT and dynamic frequency scaling) to designing benchmarks that are both representative and repeatable. We cover the statistical methods needed to interpret results correctly (hypothesis testing, change point detection) and show how to integrate continuous benchmarking into development workflows so regressions are caught before they reach production.

Along the way, we share experiments demonstrating how environment control alone can reduce measurement variance by 100x, and practical tips for anyone who writes benchmarks — whether you're optimizing a hot loop or validating a system-wide change.

Co-presented with [Augusto de Oliveira](https://github.com/igoragoli).

#### Recording

<iframe width="560" height="315" src="https://www.youtube.com/embed/8211fNI_nc4" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

**Slides**

* [How to Reliably Measure Software Performance (PDF)](https://github.com/igoragoli/fosdem-2026-software-performance/blob/main/presentation.pdf)
  * [Slides - Markdown](https://github.com/igoragoli/fosdem-2026-software-performance/blob/main/presentation.md)

**Demo/Code**

* [fosdem-2026-software-performance](https://github.com/igoragoli/fosdem-2026-software-performance) — includes Jupyter notebooks in `experiments/` with benchmark design and results interpretation visualizations

**Events**

* [FOSDEM 2026 — Software Performance Devroom](https://fosdem.org/2026/schedule/track/software_performance/)
  * [Recording](https://www.youtube.com/watch?v=8211fNI_nc4)

**Related**

* [Measuring Software Performance: Why Your Benchmarks Are Probably Lying](/posts/fosdem-2026-measuring-software-performance/) — full technical blog post expanding on this talk
