---
title: "Three Questions Before You Trust a Benchmark"
description: "A closing synthesis of the Why Your Go Benchmarks Are Lying series — the OPERA analogy, a real CI regression that turned out to be a speedup, and three questions you can answer with three CLIs before you merge."
date: 2026-09-29T00:00:00Z
publishDate: 2026-09-29T00:00:00Z
draft: true
categories:
  - engineering
tags:
  - blog
  - go
  - performance
  - benchmarking
  - tooling
series:
  - Why Your Go Benchmarks Are Lying
showToc: true
tocOpen: false
---

### A Loose Cable

In September 2011, the OPERA collaboration announced that muon neutrinos appeared to travel faster than the speed of light. Months of rechecking (the math, the sensors, the calibration) found nothing wrong. The root cause, eventually, was an improperly seated fibre-optic connector in the GPS timing chain — which introduced a ~73 ns bias that made neutrinos appear to arrive early. There was also a second fault, an oscillator defect pushing in the opposite direction — partially masking the first. Once both were corrected, the July 2012 re-measurement showed neutrino speed consistent with the speed of light.

The epistemological point is not about physics. A systematic measurement error can hide in plain sight, look exactly like signal, and survive review by people far more careful than you. An international collaboration of particle physicists rechecked that result for months — and found not one error but two, each partially cancelling the other.

Your Go benchmark has `testing.B`, a laptop, and background Chrome tabs. The cables are your compiler, your OS scheduler, and your statistics.

---

### The CI Regression That Was a Speedup

In June 2026, a restructure of `context.go` in the `ddtrace/tracer` package landed as [dd-trace-go #4891](https://github.com/DataDog/dd-trace-go/pull/4891). It was compile-time instrumentation plumbing — more files touched than a sibling two-line change, but structurally similar work. Shortly after pushing, the benchmark bot flagged `BenchmarkOTLPProtoSize` as **6–9% slower than main** and commented on the PR.

First instinct: something in the restructure was hurting the OTLP encoding path. The right move before touching anything is to read what the benchmark actually measures.

```go
// The entire timed loop inside BenchmarkOTLPProtoSize:
proto.Size(tracesData)
```

That is a protobuf size computation on a struct assembled entirely before `b.ResetTimer()`. It never calls `ContextWithSpan`, `SpanFromContext`, or any code the PR modified. So the reported regression had no plausible causal path through the diff — whatever the bot was measuring, it was not the changed code doing more work. Hold that thought; the mechanism turns out to be real, and stranger.

Step two: check local variance. Running `BenchmarkOTLPProtoSize` repeatedly on the development machine gave **<0.1% run-to-run variance**. The CI signal of 6–9% was not generic runner noise on this box — it was specific to CI.

Step three: build `main` and `#4891` on the same machine and compare with `benchstat`:

| Build | 1 span | 10 spans |
|-------|--------|----------|
| main | 883.3 ns/op | 7115 ns/op |
| #4891 | 840.7 ns/op | 6775 ns/op |

**#4891 was faster.** CI had flagged a regression; the same-machine A/B showed the opposite.

The mechanism: restructuring `context.go` shifted function addresses across the `ddtrace/tracer` package. That moved the hot `proto.Size` loop's instruction fetch window relative to cache-line and branch-target buffer boundaries. At ~390 ns per iteration, small alignment shifts produce several-percent swings in either direction — enough to flip the verdict from "improvement" to "regression" on a shared runner that cannot lock CPU frequency.

The resolution: nothing. No code change. The PR shipped as written. Pushing a speculative "fix" to quiet the benchmark would have been chasing shadows.

The same benchmark triggered again on a subsequent PR eleven days later. That time it was dismissed in under a minute: "known `BenchmarkOTLPProtoSize` false positive: code-layout/alignment artifact; local A/B was ~+0.3%. No action." Documented false positives pay for themselves on every future PR that trips the same wire.

The OPERA lesson and this story teach the same thing. A number from a noisy environment is not merely imprecise — it can be directionally wrong. A benchmark gate that is directionally wrong blocks good changes and waves bad ones through.

---

### Three Questions

The earlier posts in this series each address one way a Go benchmark can mislead you. They collapse into a checklist you can run before merging anything that touches a hot path.

| # | Question | Post | What to verify |
|---|----------|------|----------------|
| 1 | Is the compiler measuring real work? | [Compiler honesty](/posts/go-benchmarks-lying-compiler-honesty/) | Sink pattern present; no discarded results; `allocs/op` > 0 when allocation is expected |
| 2 | Is my sample stable enough? | [Statistics](/posts/go-benchmarks-lying-statistics/) | CV < ~5%; `benchstat` p-value < 0.05; `-count=10` minimum |
| 3 | Is the difference large relative to the noise? | [Local reproduction](/posts/go-benchmarks-lying-local-reproduction/) & [CI](/posts/go-benchmarks-lying-ci/) | Environment diagnosed; A/B on the same controlled machine; CI used for detection, not as the primary measurement |

Each question gates the next. A benchmark the compiler has optimised away answers question 2 with noise. A noisy environment makes question 3 unanswerable regardless of sample size.

> "Not all fast software is world-class, but all world-class software is fast. Performance is _the_ killer feature."
>
> Tobi Lütke (@tobi), [X, 5 May 2024](https://x.com/tobi/status/1787139157078188180)

A Google experiment found that a half-second increase in search result page generation time caused a 20% drop in traffic. The Google search team measured the difference and caught it before shipping. Measurement errors work in both directions: they block improvements and wave through regressions.

---

### Wire It Up This Afternoon

The [talk repo](https://github.com/kakkoyun/gopherconuk-26) for "Why Your Go Benchmarks Are Lying (And How to Stop Them)" at GopherCon UK 2026 includes three CLIs, one per question. Each is a stdlib-only Go module (`go 1.24`), no external dependencies, buildable with a single `go build`. Each is also wrapped as a Claude Code skill so an agent running benchmark discipline uses the same tools as a human.

| CLI | Answers | Skill |
|-----|---------|-------|
| `honestbench` | Is the compiler measuring real work? | `honest-benchmark` |
| `benchgate` | Is my sample stable enough? | `benchstat-gate` |
| `benchenv` | Is my environment controlled enough? | `diagnose-noisy-bench` |

#### honestbench

`honestbench` walks `*_test.go` files with `go/ast` and flags: results discarded after computation (dead-code elimination candidates), missing sink patterns, `StopTimer`/`StartTimer` misordering, and `b.N` loops that should migrate to `testing.B.Loop`, introduced in Go 1.24. Exit 1 on findings — usable as a CI gate.

```bash
cd tools/cli/honestbench && go build -o honestbench .
./honestbench -r ./...
```

Flags: `-r` recurse into subdirectories, `-json` machine-readable output, `-q` quiet (findings only, no summary line). Exit codes: `0` clean, `1` findings, `2` error.

Run this before reading a single `ns/op` number. A benchmark with findings is not measuring what you think it is.

#### benchgate

`benchgate` runs benchmarks N times, computes the coefficient of variation (CV) per benchmark, and fails if any benchmark exceeds a threshold. It optionally diffs against a saved baseline via `benchstat`.

```bash
cd tools/cli/benchgate && go build -o benchgate .
./benchgate -pkg ./... -count 10 -cv-threshold 5.0
```

Key flags:

| Flag | Default | Purpose |
|------|---------|---------|
| `-pkg` | `./...` | Package pattern to benchmark |
| `-count` | `10` | Number of runs |
| `-cv-threshold` | `5.0` | Max acceptable CV % |
| `-baseline` | (none) | Path to saved output for `benchstat` A/B |
| `-save` | (none) | Write raw output to capture a baseline |
| `-bench` | `.` | Benchmark regexp passed to `go test` |
| `-json` | (none) | Machine-readable output |

The CV threshold is the first honest signal. With SMT enabled on a shared cloud runner, CV on CPU-bound benchmarks runs around 23%; with SMT disabled it drops below 0.25% — roughly a 100× reduction. A gate at 5% catches environments that are too noisy to produce a reliable A/B signal before you waste time interpreting numbers.

To capture a baseline on the current branch and compare after a change:

```bash
./benchgate -pkg ./... -count 10 -save old.txt
# make your change
./benchgate -pkg ./... -count 10 -baseline old.txt
```

The `-baseline` flag runs `benchstat old.txt <new-output>` and prints the comparison automatically.

#### benchenv

`benchenv` diagnoses the measurement environment: SMT state, CPU frequency governor, Turbo Boost, system load average, and which of `perflock`, `benchstat`, and `benchdiff` are installed. It is cross-platform and degrades gracefully on macOS where sysfs controls are unavailable.

```bash
cd tools/cli/benchenv && go build -o benchenv .
./benchenv
```

The only flag is `-json`. Run it once at the start of a benchmarking session. Every `[warn]` line is a noise source. Fix the warnings before reading any numbers.

A typical output on a developer laptop:

```text
benchenv: benchmarking environment diagnosis (darwin/arm64, 10 CPUs)

  [warn]          turbo-boost — Turbo Boost enabled: frequency varies per-core.
  [warn]          perflock — perflock not found: go install github.com/aclements/perflock@latest
  [ok]            benchstat — found
  [ok]            benchdiff — found
  [unavailable]   smt — smt control not available on this platform

Summary: 2 ok, 2 warn, 1 unavailable. Fix warnings before trusting benchmark numbers.
```

Fix the warnings. Then run `benchgate`. Then compare with `benchstat`.

---

### The Minimum Viable Discipline

If you take one thing from this series: run benchmarks ten times, not once.

```bash
# Baseline on the current branch
go test -bench=. -count=10 ./... | tee old.txt

# After your change
go test -bench=. -count=10 ./... | tee new.txt

# Compare
benchstat old.txt new.txt
```

Add all three: `honestbench -r .` before reading any numbers, `benchenv` on any new machine or CI runner, and `benchgate -cv-threshold 5.0` as a gate that fails early when the environment is too noisy to produce a reliable signal.

Three tools, under an hour to wire up, applicable to any Go project. The benchmarks you write after this series will at minimum tell you what they are measuring, and tell you when the answer cannot be trusted.

---

### Resources

- [Why Your Go Benchmarks Are Lying (And How to Stop Them)](https://github.com/kakkoyun/gopherconuk-26) — GopherCon UK 2026 talk repo, demo module, and CLIs
- [The Benchmarks That Measure Themselves Away](/posts/go-benchmarks-lying-compiler-honesty/) — post 1: dead-code elimination, inlining, the sink pattern
- [Your Benchmark's Mean Is a Lie](/posts/go-benchmarks-lying-statistics/) — post 2: distributions, `benchstat`, CV
- [What Tene's Coordinated Omission Means for `testing.B`](/posts/go-benchmarks-lying-local-reproduction/) — post 3: `b.StopTimer()` misuse, GC pause hiding
- [Benchmark CI That Doesn't Lie](/posts/go-benchmarks-lying-ci/) — post 4: `benchdiff` workflow, statistical significance gates, bare-metal vs shared runners
- [Measuring Software Performance: Why Your Benchmarks Are Probably Lying](/posts/fosdem-2026-measuring-software-performance/) — language-agnostic companion (FOSDEM 2026)
- Tene, G. — [How NOT to Measure Latency](https://www.youtube.com/watch?v=lJ8ydIuPFeU)
- Gregg, B. — [Frequency Trails: Outliers](https://www.brendangregg.com/FrequencyTrails/outliers.html)
- Bakhvalov, D. — [Performance Analysis and Tuning on Modern CPUs](https://github.com/dendibakh/perf-book)
- CERN, [OPERA experiment reports anomaly in flight time of neutrinos from CERN to Gran Sasso](https://home.cern/news/press-release/cern/opera-experiment-reports-anomaly-flight-time-neutrinos-cern-gran-sasso) (press release, 22 February 2012)
- Cartlidge, E., "Error Undoes Faster-Than-Light Neutrino Results," *Science* 335(6072):1027, doi:[10.1126/science.335.6072.1027](https://doi.org/10.1126/science.335.6072.1027) (2012)
