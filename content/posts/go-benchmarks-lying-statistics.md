---
title: "A Single Benchmark Number Is a Lie"
description: "One benchmark run is one sample from a distribution you haven't seen. Go's benchstat and a twenty-line awk script give you the tools to ask whether your results are real — and whether your environment is stable enough to answer."
date: 2026-09-08T00:00:00Z
publishDate: 2026-09-08T00:00:00Z
draft: true
categories:
  - engineering
tags:
  - blog
  - go
  - performance
  - benchmarking
  - statistics
series:
  - Why Your Go Benchmarks Are Lying
showToc: true
tocOpen: false
---

### The Run That Lied

Run `BenchmarkMakeBuffer_Correct` on a loaded machine — sixteen CPU-bound background processes competing for the same cores. Here are two measurements from that capture:

```text
BenchmarkMakeBuffer_Correct-16    41877204    39.39 ns/op
...
BenchmarkMakeBuffer_Correct-16    52521198    27.54 ns/op
```

Same code, same binary, eight runs apart: a 43% swing. If you had run the benchmark once and filed the PR, you would have been up to 43% off in either direction. The benchmark measured exactly what was happening: scheduler preemptions, cache evictions, stolen CPU time. It just wasn't measuring what you thought it was.

This is the core problem with any single benchmark result: it is one draw from a distribution whose shape, center, and spread you do not know. The number might be a warm-cache best case. It might include a garbage collection pause. Or it might sit 20% above the median for no reason you can reproduce.

Before you can do anything useful with benchmark data, you need to answer two questions in order:

1. Is the code actually executing? (Covered in [Post 1: Compiler Honesty](/posts/go-benchmarks-lying-compiler-honesty/): if the compiler has optimized your benchmark away, the number is telling you nothing about your code at all.)
2. Is the measurement stable enough to mean anything? (This post.)

The [FOSDEM 2026 talk on measuring software performance](/posts/fosdem-2026-measuring-software-performance/) covers the statistical foundations in language-agnostic terms: Welch's t-test, change-point detection, why averages lie. Here we go one level deeper into the Go-specific tooling that puts those principles into practice.

---

### Benchstat: From Runs to a Distribution

The right response to a noisy single measurement is more samples, not better luck. Collect twenty runs, then let `benchstat` summarize the distribution:

```bash
go test -bench=BenchmarkMakeBuffer_Correct -benchmem -count=20 -benchtime=1s . \
  | tee results.txt

go install golang.org/x/perf/cmd/benchstat@latest
benchstat results.txt
```

For the idle-host capture (`results/idle.txt` from the demo), the output is:

```text
goos: darwin
goarch: arm64
pkg: github.com/kakkoyun/gopherconuk-26/demo
cpu: Apple M4 Max
                      │ results/idle.txt │
                      │      sec/op      │
MakeBuffer_Correct-16        11.32n ± 5%
```

Two numbers: `11.32n` is the **median** of the 20 runs; `± 5%` shows the relative spread of the distribution.

{{< sidenote side="alternate" label="median" >}}Benchmark distributions are right-skewed: a GC pause or a scheduler preemption can drag one run well above the rest, and the arithmetic mean follows it up. The median ignores those outliers. The geometric mean appears only in benchstat's `geomean` summary row, which aggregates results across multiple benchmarks — not in the per-benchmark rows shown here.{{< /sidenote >}}

#### Comparing Two Runs

Single-file summaries show how consistent a run set is. The comparison mode is more useful:

```bash
go test -bench=. -benchmem -count=20 -benchtime=1s . > old.txt
# make your change
go test -bench=. -benchmem -count=20 -benchtime=1s . > new.txt
benchstat old.txt new.txt
```

Here is the comparison between the idle run and the loaded run from the demo results — `sec/op` only, allocations were identical:

```text
                      │ results/idle.txt │           results/noisy.txt           │
                      │      sec/op      │    sec/op     vs base                 │
MakeBuffer_Correct-16        11.32n ± 5%   37.40n ± 25%  +230.34% (p=0.000 n=20)
```

Three numbers: the delta (+230.34%, meaning the loaded machine ran the same benchmark three times slower), the p-value (p=0.000, effectively zero; the difference is real), and the sample count (n=20 per side).

When the p-value exceeds 0.05, benchstat prints `~` instead of a delta — the correct result, meaning "no measurable difference with this sample size." Report it as such rather than rerunning.

---

### What Benchstat Doesn't Tell You

The `± 5%` and `± 25%` figures hint at spread, but they describe how tightly the geomean is estimated, not whether your *environment* is stable enough to trust any comparison you run in it. For that you need a different number: the **coefficient of variation**.

CV = σ / μ, expressed as a percentage. Where benchstat answers "is A different from B?", CV answers "is this machine a reliable place to ask that question?" Benchstat deliberately does not report CV — it is designed to compare two distributions, not to characterize the environment producing them. That is a separate pass.

A twenty-line awk script handles it. From the demo directory:

```bash
make cv
# or directly:
awk -f cv.awk results/idle.txt
awk -f cv.awk results/noisy.txt
```

`cv.awk` reads any `go test -bench` output and computes mean, standard deviation, and CV per benchmark. Run it across the three conditions captured in the demo (`results/cv-summary.txt`, Apple M4 Max, `-count=20 -benchtime=1s`):

| Condition | Mean ns/op | Stddev | CV |
|-----------|-----------|--------|-----|
| Idle host | 11.46 | 0.54 | 4.75% |
| 16 background spinners | 34.97 | 6.60 | 18.88% |
| Pinned container, 1 CPU | 16.28 | 0.85 | 5.25% |

The loaded machine is three times slower and four times noisier. A CV of 18.88% means the standard deviation is nearly one-fifth of the mean — the benchmark is measuring scheduling interference at least as much as the code under test. Any A/B comparison collected on that machine would be uninterpretable.

The rule of thumb:

| CV | Interpretation |
|----|---------------|
| < 2% | Excellent; results are reliable |
| 2 to 5% | Acceptable for most comparisons |
| 5 to 10% | Noisy; investigate the environment |
| > 10% | Fix the environment; do not trust comparisons |

At 18.88%, the loaded condition fails the threshold by a factor of nearly four. More samples would not help — you cannot average your way out of a biased environment.

#### The Shape Behind the Mean

The arithmetic mean of 34.97 ns/op in the noisy condition looks unremarkable until you inspect the raw runs. The first seven land between 38 and 44 ns/op. Runs eight through sixteen drop to 25 to 29 ns/op, almost half the speed of the first cluster. Then the last four drift back toward 38 to 39. The mean of 34.97 sits between two populations that never actually existed as stable states.

A single number — any single number — hides this completely. This is why the FOSDEM post's advice on strip plots applies here: one dot per measurement reveals the bimodality immediately. Boxplots would obscure it; a mean buries it entirely.

The CV of 18.88% catches the problem numerically. But the raw data is showing you something worse than noise: the measurement environment was shifting between two regimes during the run. That is not recoverable with more statistics. The third condition in the table — a pinned container — is the start of the answer. Post 3 ([Local Reproduction](/posts/go-benchmarks-lying-local-reproduction/)) covers what isolation actually buys you.

---

### How Many Runs Are Enough?

`-count=10` is the practical floor. Benchstat needs enough samples to estimate the geomean with confidence; below ten the estimates become unreliable. Use `-count=20` for anything you intend to report or check into a CI baseline. [Kalibera and Jones (ECOOP 2013)](https://dl.acm.org/doi/10.1145/2509136.2509184) establish that N ≥ 30 is needed for robust inter-run statistics; 20 is a reasonable engineering compromise between rigor and machine time.

| `-count` | Use case |
|----------|---------|
| 5 | Quick development sanity check only |
| 10 | Reliable local A/B comparison |
| 20 | CI nightly suite, public reporting |
| 50+ | Very noisy environments |

**On `-benchtime`:** the default `1s` calibrates `b.N` to fill one second per run. Two better options depending on your goal:

- `-benchtime=2s` — more iterations per run, reducing within-run variance.
- `-benchtime=100x` — exactly 100 iterations regardless of clock time. The fixed count makes runs more directly comparable; Go's calibration loop cannot vary `b.N` based on momentary system load.

For CI baselines, prefer fixed-iteration: `-benchtime=100x -count=20`. Time-based calibration is a source of variance you did not ask for.

To reproduce both conditions from this post:

```bash
# From talks/go-benchmarks-lying/demo/ in github.com/kakkoyun/gopherconuk-26
make bench   # run benchmarks and pipe to benchstat
make cv      # recompute CV table from results/
```

---

### The P-Hacking Trap

The most common way to get a benchmark result you like is to keep running until you see one.

This is p-hacking, and it invalidates everything benchstat reports. The p-value is calibrated for a pre-specified number of experiments, not an open-ended search. With `-count=20` and α=0.05, you expect approximately one false positive for every twenty benchmarks by chance alone. Select for runs that clear the threshold and you have systematically chosen flukes.

The discipline is simple but requires commitment up front:
1. Decide on N before running.
2. Run once.
3. Report what benchstat says, including the `~` results.

If the result is not significant with your chosen N, you have two honest options: accept "no measurable difference" or pre-commit to a larger N and run exactly once more. What you cannot do is rerun after seeing a disappointing p-value.

Recognizing it in practice:

- "I ran it a few times until it stabilised": p-hacking.
- "The improvement only showed up on the third attempt": p-hacking.
- "benchstat showed improvement when I closed my editor": environmental confounding, equally problematic.

---

### Effect Size vs Statistical Significance

A low p-value tells you the difference is unlikely to be zero. It does not tell you the difference matters.

With 100 samples, a 0.3% change will clear p=0.05 with ease. A 0.3% improvement to an HTTP handler running at 200 µs saves 600 picoseconds per request. Statistically real, practically irrelevant. The code complexity required to achieve it will cost more in maintenance than it saves in latency.

The inverse is also true: with five samples, a 15% regression might not reach statistical significance, but 15% on a critical path is worth investigating regardless. More data changes the answer; dismissing the signal does not.

Report both numbers:

| Delta | p-value | Action |
|-------|---------|--------|
| < 2% | any | No action needed |
| 2 to 10% | > 0.05 | Collect more samples; likely noise |
| 2 to 10% | < 0.05 | Investigate; may be real |
| > 10% | > 0.05 | Likely noise; collect more before acting |
| > 10% | < 0.05 | Real; act on it |

For PR-level comparisons, benchstat covers this well. For continuous benchmarking across hundreds of commits — where slow regressions creep 1 to 2% per commit and never trip a threshold — the FOSDEM post's section on change-point detection (ED-PELT) explains what to reach for once you have a historical baseline.

---

### Resources

- [benchstat documentation](https://pkg.go.dev/golang.org/x/perf/cmd/benchstat) — `golang.org/x/perf/cmd/benchstat`
- [Demo repository](https://github.com/kakkoyun/gopherconuk-26) — `make bench` and `make cv` from `talks/go-benchmarks-lying/demo/`
- [Measuring Software Performance: Why Your Benchmarks Are Probably Lying](/posts/fosdem-2026-measuring-software-performance/) — the language-agnostic statistical foundation; read this first
- [Post 1: Compiler Honesty](/posts/go-benchmarks-lying-compiler-honesty/) — confirming the compiler is actually running your code
- [Post 3: Local Reproduction](/posts/go-benchmarks-lying-local-reproduction/) — what to do when CV says your machine is the problem
- Kalibera, T. and Jones, R. — [Rigorous Benchmarking in Reasonable Time](https://dl.acm.org/doi/10.1145/2509136.2509184) (ECOOP 2013)
- Gregg, B. — [Frequency Trails: Outliers](https://www.brendangregg.com/FrequencyTrails/outliers.html)
- "Why Your Go Benchmarks Are Lying (And How to Stop Them)", GopherCon UK 2026
