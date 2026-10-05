---
title: "A Single Benchmark Number Is a Lie"
description: "One benchmark run is one sample from a distribution you have not seen. benchstat and a short awk script tell you whether the result, and the machine, can be trusted."
date: 2026-07-14T00:00:00Z
publishDate: 2026-07-14T00:00:00Z
promote: false
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
Here is one benchmark that gave us two different answers for the same code. We're going to take that run apart: see what `benchstat` can and can't say about it, add the one number it doesn't report, and decide how many runs it takes before a result earns any trust. Let's call it the run that lied.

The benchmark is `BenchmarkMakeBuffer_Correct`, run on a machine with sixteen CPU-bound background processes competing for the same cores. Here are two of its twenty runs (`-16` is the `GOMAXPROCS` suffix), with the `B/op` and `allocs/op` columns dropped:

```text
BenchmarkMakeBuffer_Correct-16    41877204    39.39 ns/op
...
BenchmarkMakeBuffer_Correct-16    52521198    27.54 ns/op
```

Those are runs 1 and 9 of one capture on an Apple M4 Max (darwin/arm64) from the [companion repository](https://github.com/kakkoyun/gopherconuk-26/tree/fdce88cc0ce129b7d2edfb1a20d02fe647c17eeb/talks/go-benchmarks-lying/demo). Same code, same binary, eight runs apart, a 43% swing. Run it once, file the PR, and you could have reported either number. (I would love to say I've never done that.) Scheduler preemption, cache evictions and stolen CPU time are the likely culprits. The benchmark measured what the machine was doing; it just wasn't what we thought we were measuring. Any single result is one draw from a distribution whose shape, center and spread we haven't seen.

This is part 2 of 5 in the [Why Your Go Benchmarks Are Lying](/series/why-your-go-benchmarks-are-lying/) series, the written companion to the [GopherCon UK 2026 talk](/talks/why-your-go-benchmarks-are-lying/). In [part 1](/posts/go-benchmarks-lying-compiler-honesty/) we asked whether the compiler lets a benchmark do real work. Here we ask the second of the three questions: is the sample stable enough to mean anything? We also pick up the statistics for the third (p-value and effect size), whether the difference is large relative to the noise, and [part 3](/posts/go-benchmarks-lying-local-reproduction/) and [part 4](/posts/go-benchmarks-lying-ci/) then deal with the machine. The prerequisite is the [FOSDEM 2026 post on measuring software performance](/posts/fosdem-2026-measuring-software-performance/), which covers the statistics in language-agnostic terms. Here we go one level deeper, into the Go tooling.

If one run can say 39 or 27, the first move is to stop trusting one run.

## From runs to a distribution with `benchstat`

The cure for a noisy measurement is more samples, not better luck. Let's collect twenty runs and let `benchstat` summarize them:

```bash
go test -bench=BenchmarkMakeBuffer_Correct -benchmem -count=20 -benchtime=1s . \
  | tee results.txt

go install golang.org/x/perf/cmd/benchstat@v0.0.0-20260929162123-406019bb8b68
benchstat results.txt
```

We'll start with the idle machine as our control. This is the `benchstat` output for the idle capture (same `-count=20 -benchtime=1s`, same M4 Max), trimmed to the `sec/op` table because the tool also prints `B/op` and `allocs/op`:

```text
goos: darwin
goarch: arm64
pkg: github.com/kakkoyun/gopherconuk-26/demo
cpu: Apple M4 Max
                      │ results/idle.txt │
                      │      sec/op      │
MakeBuffer_Correct-16        11.32n ± 5%
```

Two numbers here. `11.32n` is the [**median**](https://pkg.go.dev/golang.org/x/perf@v0.0.0-20260929162123-406019bb8b68/cmd/benchstat) of the 20 runs, and `± 5%` is how far the 95% confidence interval around that median reaches, as a percentage of it: a range built to contain the true median 95% of the time.

{{< sidenote side="alternate" label="median" >}}Real latency data is rarely a bell curve: [Brendan Gregg's frequency trails](https://www.brendangregg.com/FrequencyTrails/outliers.html) show disk I/O latency distributions that are combinations of bimodal and log-normal. A GC pause or a scheduler preemption can drag one benchmark run well above the rest, and the arithmetic mean follows it up. The median ignores those outliers.{{< /sidenote >}}

Now let's put the loaded machine next to it.

### Comparing two runs

Comparison is where `benchstat` earns its keep. We collect one file before a change and one after, then hand it both:

```bash
go test -bench=. -benchmem -count=20 -benchtime=1s . > old.txt
# make your change
go test -bench=. -benchmem -count=20 -benchtime=1s . > new.txt
benchstat old.txt new.txt
```

Here the "change" is the load, so we compare the idle capture against the loaded one (`sec/op` only; allocations were identical):

```text
                      │ results/idle.txt │           results/noisy.txt           │
                      │      sec/op      │    sec/op     vs base                 │
MakeBuffer_Correct-16        11.32n ± 5%   37.40n ± 25%  +230.34% (p=0.000 n=20)
```

The delta is +230.34%, so the loaded machine took about 3.3 times as long, and a p-value of effectively zero, the chance that noise alone would produce a difference this large, says the difference is real. When the p-value exceeds 0.05, `benchstat` prints `~` instead of a delta, which is the right answer: "no measurable difference with this sample size." Report it as such. (The [test underneath](https://pkg.go.dev/golang.org/x/perf@v0.0.0-20260929162123-406019bb8b68/cmd/benchstat) is Mann-Whitney U on the samples, which compares ranks and needs no bell curve, not the Welch's t-test from the FOSDEM post.)

`benchstat` says the two machines differ. It doesn't say whether the loaded one is a place where any comparison means anything, and that is the gap we fill next.

## What benchstat doesn't tell you

Look at the `± 25%` on the loaded side. The `±` figures are 95% confidence intervals on the median, and they hint at spread, but they don't say whether the *environment* is stable enough to trust a comparison run in it. The interval narrows as runs are added; CV does not. For that we need a different number: the **coefficient of variation**.

CV = σ / μ, as a percentage. Where `benchstat` answers "is A different from B?", CV answers "is this machine a reliable place to ask?" `benchstat` compares two distributions; it doesn't characterize the environment producing them, much as a referee doesn't inspect the pitch. A short awk script does that pass:

```bash
make cv
# or directly:
awk -f cv.awk results/idle.txt
awk -f cv.awk results/noisy.txt
```

`cv.awk` reads any `go test -bench` output and computes the mean, standard deviation and CV per benchmark. Over the idle and loaded captures (same `-count=20 -benchtime=1s` on the same M4 Max) it gives this table. [Part 3](/posts/go-benchmarks-lying-local-reproduction/) adds a third condition.

| Condition | Mean ns/op | Stddev | CV |
|-----------|-----------|--------|-----|
| Idle host | 11.46 | 0.54 | 4.75% |
| 16 background spinners | 34.97 | 6.60 | 18.88% |

The loaded machine is three times slower and four times noisier. A CV of 18.88% puts the standard deviation at nearly one-fifth of the mean, so we are measuring scheduling interference at least as much as the code. Any A/B comparison collected there is uninterpretable.

My rule of thumb for reading it, not `benchstat`'s:

| CV | Interpretation |
|----|---------------|
| < 2% | Results are reliable |
| 2 to 5% | Acceptable for most comparisons |
| 5 to 10% | Noisy; investigate the environment |
| > 10% | Fix the environment; do not trust comparisons |

At 18.88% the loaded condition misses the 10% line by nearly a factor of two. More samples would not help, because the environment is biased and averaging does not remove a bias (noise shrinks with more runs; bias does not). What kind of bias? For that we go back to the raw runs.

### Back to the run that lied

The mean of 34.97 ns/op looks unremarkable until we read the twenty runs. The first seven land between 38 and 44 ns/op. Run eight is 37. Runs nine through sixteen drop to 25 to 29, roughly a third lower. Then the last four climb back: 34, then 38 to 39. The mean sits in the gap between the two clusters, where only a couple of runs land. It describes a machine that was almost never in that state.

Now our two runs make sense. Run 1 (39.39) sits in the first cluster, run 9 (27.54) in the second. The machine shifted between two regimes during the capture, and we happened to sample one of each. Mann-Whitney assumes one distribution per sample, which these runs are not. One dot per measurement, the strip plot from the FOSDEM post, shows this at once. A boxplot would obscure it, and a mean buries it entirely.

I did not measure why the regimes differ. Scheduler interference is the likely explanation, though P/E-core placement or frequency scaling would look similar on this machine. More statistics cannot recover that; a pinned container is the start of the answer, and part 3 measures what isolation buys. First, a question we've been dodging: even on a good machine, how many runs do we collect?

## How many runs are enough?

Ten is the practical floor: [`benchstat`'s own documentation](https://pkg.go.dev/golang.org/x/perf@v0.0.0-20260929162123-406019bb8b68/cmd/benchstat) says to run "at least 10, ideally 20". Below six samples it can't compute a confidence interval at all and prints `± ∞`, so five is a sanity check and nothing more. Ten gives a reliable local A/B comparison, and 20 is for a CI nightly suite or anything we intend to report. [Kalibera and Jones (ISMM 2013)](https://dl.acm.org/doi/10.1145/2464157.2464160) argue for repetition counts based on measured variance, and 20 is a reasonable engineering compromise between rigor and machine time. Fifty or more is for environments we can't quiet down. It tightens the interval and keeps the same bias, so for the run that lied it would only give a sharper picture of two moods.

As a rule of thumb, resolving a change of Δ% at a CV of c% takes about 16·(c/Δ)² runs per side. At 5% CV, a 5% change needs 16 to 20 runs; at the loaded machine's 18.88%, more than 200. (This is Lehr's rule, 16σ²/Δ² per group for about 80% power at α=0.05. It assumes normal noise, and two regimes break it.)

By default `-benchtime=1s` lets Go calibrate `b.N` to fill one second per run. For CI baselines I prefer a fixed count such as `-benchtime=1000000x` (a million iterations per run, no calibration) with `-count=20`, because a calibration loop that reacts to momentary system load is variance nobody asked for. Pick N so each run lasts milliseconds, not microseconds.

We now know how many runs to collect. One habit can still waste every one of them.

## The p-hacking trap

The most common way to get a benchmark result you like is to keep running until you see one. I have done this, and I suspect you have too.

That habit is p-hacking, and it invalidates the p-values `benchstat` reports, which are calibrated for a pre-specified number of experiments, not an open-ended search. `benchstat`'s documentation calls [rerunning until it reports a change](https://pkg.go.dev/golang.org/x/perf@v0.0.0-20260929162123-406019bb8b68/cmd/benchstat) a common statistical error: at the default α of 0.05, about one comparison in twenty shows a difference when nothing changed, whatever your `-count`. Across 40 benchmarks that is about two false flags per run: re-measure a flag with a pre-committed N, and keep a ledger of the ones that do not reproduce. Select for the runs that clear the threshold and you have selected flukes.

The discipline is to decide N before running, run once, and report what `benchstat` says, `~` results included. If it matters enough to look again, a larger run is a new experiment: fix its N up front and label it a second look in the report. What we can't do is rerun after a disappointing p-value and keep whichever result we like. "It only improved on the third attempt" is p-hacking. "It improved when I closed my editor" is environmental confounding, which is equally problematic.

Suppose we resisted all that and the p-value is low. Are we done?

## Effect size versus statistical significance

Not yet. A low p-value says the difference is unlikely to be zero. It doesn't say the difference matters.

With 100 samples on a quiet machine (CV around 1% or less), a 0.3% change can clear p=0.05. On an HTTP handler running at 200 µs that saves 600 nanoseconds per request: statistically real, practically irrelevant. The inverse also holds. With five samples a 15% regression might not reach significance, but 15% on a critical path deserves a look anyway, and a larger pre-committed N can settle it as a new experiment.

We report both numbers. Here is my rule of thumb, not `benchstat`'s:

| Delta | p-value | Action |
|-------|---------|--------|
| < 2% | any | No action needed |
| 2 to 10% | > 0.05 | Treat as no measurable difference; pre-commit to a larger N if it matters |
| 2 to 10% | < 0.05 | Investigate; may be real |
| > 10% | > 0.05 | Investigate; the noise may be hiding a real change |
| > 10% | < 0.05 | Real; act on it |

Regressions that creep in at 1 to 2% per commit never trip these thresholds; the FOSDEM post's change-point detection section covers them.

That is the whole kit for the sample: a distribution, a stability number, a run count and a discipline. Time to check our arithmetic.

## Try it

To recompute the CV table from the captured results in the companion repository:

```bash
git clone https://github.com/kakkoyun/gopherconuk-26
cd gopherconuk-26/talks/go-benchmarks-lying/demo
git checkout fdce88cc0ce129b7d2edfb1a20d02fe647c17eeb

make cv            # recompute the CV table from results/
```

`make cv` prints all three conditions, the two above and the pinned container from part 3. Re-running them is in [part 3](/posts/go-benchmarks-lying-local-reproduction/#try-it).

Versions, links and commands checked on 2 October 2026.

## Up next

[Part 3, Before CI: Can You Trust a Benchmark on Your Own Laptop?](/posts/go-benchmarks-lying-local-reproduction/) measures what container pinning and the Linux controls buy you locally, and where it stops. The run that lied is about to get a third condition. Let's see if it behaves.
