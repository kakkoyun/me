---
title: "A/B is the wrong model for CI"
description: "A per-PR benchmark A/B compares two runs. A benchmark's history is a time series. A synthetic change-point toy, how the Go project tracks it, and a false-positive ledger."
date: 2026-08-01T00:00:00Z
publishDate: 2026-08-01T00:00:00Z
promote: false
categories:
  - engineering
tags:
  - blog
  - go
  - performance
  - benchmarking
  - ci
showToc: true
tocOpen: false
---

We're going to take one benchmark and stop looking at it as a pair of numbers. First we'll see why a pair misleads, then we'll build a small time series and read it.

Start with a pair that misled me. On [dd-trace-go #4891](https://github.com/DataDog/dd-trace-go/pull/4891#issuecomment-4690941739), the benchmark bot's comment now says `BenchmarkOTLPProtoSize/1span` is 7.6% to 8.0% *faster* than its baseline. Eleven days after #4891 was opened, on [#4926](https://github.com/DataDog/dd-trace-go/pull/4926#issuecomment-4779621296), the bot said the same sub-benchmark was 8.1% to 8.5% *slower*. Both comments are correct arithmetic over two sets of runs, and the baselines differ: `05d9b8a` on the first, `1e830f6` on the second. Same benchmark, opposite verdicts. 🔀

This is a companion to the [Why Your Go Benchmarks Are Lying](/series/why-your-go-benchmarks-are-lying/) series, between [part 4](/posts/go-benchmarks-lying-ci/) and [part 5](/posts/go-benchmarks-lying-three-questions/). Part 5 tells the #4891 story in full; here we ask what it looks like over time. Disclosure: I work at Datadog, which maintains dd-trace-go.

## A pair carries an assumption

The bot says what it does in its own comment: "This is an A/B test comparing a candidate commit's performance against that of a baseline commit." For a question about one change, that is fair, and [A PR gate that actually fails](/posts/go-benchmarks-pr-gate-that-fails/) builds one.

The pair quietly assumes the baseline is a fixed, neutral reference. It isn't. `main` moves, and the binary's layout and the machine's mood move with it. Change the baseline and the same benchmark gets a different verdict, as above; on #4891 alone the sign changed between bot updates ([part 5](/posts/go-benchmarks-lying-three-questions/#the-ci-regression-that-was-a-speedup)). A pair can't show that, because it has one point on each side.

What does the same benchmark look like when we keep every night instead of comparing two? Let's make one up.

## Sixty nights of one benchmark

Everything in this section is **synthetic**: a Go program generated it, and no real benchmark did. The benchmark is a pretend 1000 ns/op function measured once a night, with 0.5% Gaussian noise. Three times, at nights 20, 35 and 50, a "PR" lands and adds 1.5%. On night 42 a noisy neighbour adds 8% for one night only. We'll read it two ways: a 5% gate comparing each night with the one before, standing in for a PR check against one baseline run, and a change-point detector we'll write after that.

```go
package main

import (
	"fmt"
	"math"
	"math/rand/v2"
	"slices"
)

const (
	nights    = 60
	minLen    = 5
	threshold = 6.0
)

func main() {
	// Synthetic: 1000 ns/op, 0.5% noise, three +1.5% steps, one noisy night.
	rng := rand.New(rand.NewPCG(1, 2))
	series := make([]float64, nights)
	for i := range series {
		level := 1000.0
		for _, step := range []int{20, 35, 50} {
			if i >= step {
				level *= 1.015
			}
		}
		series[i] = level * (1 + 0.005*rng.NormFloat64())
	}
	series[42] *= 1.08

	for i := 1; i < nights; i++ {
		if d := series[i]/series[i-1] - 1; math.Abs(d) > 0.05 {
			fmt.Printf("night %2d vs night %2d: %+.1f%%  <- a 5%% gate fires\n", i, i-1, 100*d)
		}
	}

	fmt.Println("change points (night where a new level starts):")
	for _, cp := range split(series, 0, nights) {
		fmt.Printf("  night %d\n", cp)
	}
}
```

The first loop is the per-PR model. Here is the first half of the output, from Go 1.27.1:

```text
night 42 vs night 41: +9.3%  <- a 5% gate fires
night 43 vs night 42: -8.3%  <- a 5% gate fires
```

The gate fires twice, both times on the noisy neighbour: night 42 looks like a regression, night 43 like a recovery. It never fires on the three real steps, because 1.5% is well under its threshold, yet together they made the benchmark about 4.6% slower. The gate blames the innocent night and lets the guilty ones through. [Part 4](/posts/go-benchmarks-lying-ci/#two-patterns-that-actually-work) said a change costing 1% per PR won't trip a per-PR gate. Here are the numbers.

## Reading the series

Change-point detection scans the whole history for places where the results shift, and stays quiet about everything else. [MongoDB engineers](https://arxiv.org/abs/2003.00584) moved to an E-Divisive means detector after threshold-based detection, and report that it "dramatically dropped our false positive rate".

Our toy reader is much cruder and does *not* use E-Divisive. It does binary segmentation: find the night with the largest median shift, and if that beats a threshold, cut there and repeat on both halves. Here is the rest of the program:

```go
// split does binary segmentation: cut at the strongest shift, recurse on both halves.
func split(x []float64, lo, hi int) []int {
	best, bestT := -1, 0.0
	for k := lo + minLen; k <= hi-minLen; k++ {
		if t := math.Abs(shift(x[lo:k], x[k:hi])); t > bestT {
			best, bestT = k, t
		}
	}
	if bestT < threshold {
		return nil
	}
	return append(append(split(x, lo, best), best), split(x, best, hi)...)
}

// shift is the difference of medians in units of its standard error, with
// the noise scale taken from the median absolute deviation so that a single
// spike cannot inflate it.
func shift(a, b []float64) float64 {
	ma, mb := median(a), median(b)
	dev := make([]float64, 0, len(a)+len(b))
	for _, e := range a {
		dev = append(dev, math.Abs(e-ma))
	}
	for _, e := range b {
		dev = append(dev, math.Abs(e-mb))
	}
	sigma := 1.4826 * median(dev)
	return (mb - ma) / (sigma * math.Sqrt(1/float64(len(a))+1/float64(len(b))))
}

func median(x []float64) float64 {
	s := slices.Sorted(slices.Values(x))
	return (s[(len(s)-1)/2] + s[len(s)/2]) / 2
}
```

`split` tries every cut at least `minLen` nights from either end and keeps the strongest. The `threshold` of 6 is a knob I picked by eye for this data, and a real deployment has to set its own. The last part of the output:

```text
change points (night where a new level starts):
  night 21
  night 33
  night 49
```

It finds three level changes and ignores the night-42 spike. The planted steps were at 20, 35 and 50, so it lands within two nights of each. On a real series the output is a list of candidate nights, and the next job is `git log` between them. Part 4 lists [tools that ship change-point detection](/posts/go-benchmarks-lying-ci/#tool-survey-and-a-recommendation).

## How the Go project reads its own

The Go wiki's [PerformanceMonitoring](https://go.dev/wiki/PerformanceMonitoring) page states the principle plainly: "We never report performance numbers in isolation, and only relative to some baseline", because "comparing performance data taken far apart in time, even on the same hardware, can result in a lot of noise that goes unaccounted for". Before merge, [SlowBot](https://go.dev/wiki/SlowBots) `perf_vs_parent` and `perf_vs_tip` run a pair on purpose. After merge, the [performance dashboard](https://perf.golang.org/dashboard/) gives "continuous monitoring of benchmark performance for every commit", and because the tip-of-tree baseline "is always the latest overall release of Go", "on every minor release of Go, the baseline shifts". Read that next to our opening pair: the sign on #4891 flipped when `main` moved, and Go's dashboard puts baseline changes where you can see them.

## A ledger for alarms that weren't

Bot comments will keep arriving, and some will be old friends. A mute regex silences a benchmark and forgets why. I'd add a ledger entry per dismissed alarm, in the repository, next to the benchmark. This one is illustrative, written from the public bot comments and part 5:

```text
BenchmarkOTLPProtoSize (all four sub-benchmarks)
  seen:    dd-trace-go #4891 (12 Jun), #4926 (23 Jun)
  symptom: 6-9% in one direction; sign flipped when main moved
  cause:   code layout, suspected, not proven (see part 5)
  check:   same-machine A/B of base vs head before anyone edits code
```

`seen` turns one surprise into a count, `cause` says how sure we are, and `check` names the decisive test, so the next person doesn't improvise one.

## Back to the one benchmark

The pair told us −8% on one PR and +8% on another. Our sixty nights told us which night was a neighbour and which were the code. Keep the nightly series from [part 4](/posts/go-benchmarks-lying-ci/), use pairs for "did this change do it", and write down the alarms that turned out to be nothing.

Versions, links and commands checked on 2 October 2026.

## Try it

The two Go blocks above are one program: paste the second under the first in a `main.go`, run `go mod init cp` and `go run .`. I ran that with Go 1.27.1 and got the output shown. Change the seed or `threshold` and watch the detector miss a step or invent one. Then ask what the baseline was in your own bot's last three comments.

A benchmark is a story told over time. Stop reading only the last sentence. 📈
