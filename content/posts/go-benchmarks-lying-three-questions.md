---
title: "Three Questions Before You Trust a Benchmark"
description: "A CI regression that turned out to be a speedup, and three questions, each backed by a small CLI, that tell you whether a Go benchmark result deserves your trust."
date: 2026-08-04T00:00:00Z
publishDate: 2026-08-04T00:00:00Z
promote: false
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

A benchmark bot once told me that one of my pull requests made a benchmark 6–9% slower. A same-machine comparison said the pull request made it faster. Both results were stable, and they disagreed. In this last part we'll find out how that happens, and leave with three questions and three small Go tools that tell us how far to trust a number.

## A loose cable

Physicists have been fooled the same way, at a much larger scale. In September 2011, the OPERA collaboration [announced](https://web.archive.org/web/20140222165941/http://press-archived.web.cern.ch/press-archived/PressReleases/Releases2011/PR19.11E.html) that muon neutrinos appeared to travel faster than the speed of light. Months of rechecking found nothing wrong. The root cause, eventually, was an improperly seated fibre-optic connector in the GPS timing chain, which introduced a ~73 ns bias that made neutrinos appear to arrive early ([Science](https://doi.org/10.1126/science.335.6072.1027) called it a loose cable). A second fault, an oscillator defect, pushed the other way and partly masked the first. Once both were corrected, the 2012 re-measurements showed neutrino speed consistent with the speed of light.

A systematic measurement error can hide in plain sight, look exactly like signal, and survive review by people far more careful than we are. Our Go benchmarks have `testing.B`, a laptop, and background Chrome tabs. They have cables too: the compiler, the statistics, and the machine with its OS scheduler. We'll follow one loose cable through this post. I'll show you mine first, and then we'll see which question would have caught it.

This is part 5 of 5 in the [Why Your Go Benchmarks Are Lying](/series/why-your-go-benchmarks-are-lying/) series, the written companion to the [GopherCon UK 2026 talk](/talks/why-your-go-benchmarks-are-lying/). [Part 4](/posts/go-benchmarks-lying-ci/) built benchmark CI that holds up (with the companions [A PR gate that actually fails](/posts/go-benchmarks-pr-gate-that-fails/) and [A/B is the wrong model for CI](/posts/go-benchmarks-ab-is-the-wrong-model/)); this part asks whether we should believe it. The [FOSDEM 2026 post on measuring software performance](/posts/fosdem-2026-measuring-software-performance/) is the prerequisite. The tools live in [benchlab](https://github.com/kakkoyun/benchlab/tree/v0.1.0) and the talk's demo results in [gopherconuk-26](https://github.com/kakkoyun/gopherconuk-26/tree/fdce88cc0ce129b7d2edfb1a20d02fe647c17eeb/talks/go-benchmarks-lying). Disclosure: I work at Datadog, which maintains dd-trace-go, so the story is about my employer's CI bot. The lesson holds for any repository.

Enough physics. Here is my loose cable.

## The CI regression that was a speedup

In June 2026 I pushed a change touching `context.go` in the `ddtrace/tracer` package, which landed as [dd-trace-go #4891](https://github.com/DataDog/dd-trace-go/pull/4891). The change was compile-time instrumentation plumbing. Shortly after the push, the benchmark bot commented that `BenchmarkOTLPProtoSize` was **6–9% slower than main**.

My first instinct was to suspect my change. The better move is to read what the benchmark measures first, so here is its timed loop:

```go
// The entire timed loop inside BenchmarkOTLPProtoSize:
for b.Loop() {
	proto.Size(tracesData)
}
```

That is a protobuf size computation on a struct assembled entirely before the loop (the [real benchmark](https://github.com/DataDog/dd-trace-go/blob/1a0c5e19b611f34f14c14531304973c89d2fb055/ddtrace/tracer/otlp_writer_bench_test.go#L144) still calls `b.ResetTimer()` there, which `b.Loop` makes redundant). It never calls `ContextWithSpan`, `SpanFromContext`, or any code the PR modified, so the diff had no believable path to the number. Hold that thought, because the likely mechanism is stranger.

Did the regression show up on my own machine? Running the benchmark repeatedly there gave a **coefficient of variation (CV) under 0.1%**, so a 6–9% gap was not ordinary variance. I built `main` and `#4891` on that same machine, an Apple M4 Max (darwin/arm64), and compared them with `benchstat`. The table shows the medians:

| Build | 1 span | 10 spans |
|-------|--------|----------|
| main | 883.3 ns/op | 7115 ns/op |
| #4891 | 840.7 ns/op | 6775 ns/op |

**#4891 was faster.** CI had flagged a regression, and the same-machine A/B showed the opposite.

The likely mechanism is code layout. Changing `context.go` shifted function addresses in the test binary, which moved the hot `proto.Size` loop relative to cache-line and branch-target-buffer boundaries. At the sub-microsecond scale of the one-span case, a small alignment shift can swing a result by a few percent in either direction, enough to flip the verdict from "improvement" to "regression". Emery Berger's [Performance Matters](https://www.youtube.com/watch?v=r-TLSBdHe1A) (Strange Loop 2019) puts code layout alone at ±10%.

The evidence is circumstantial. A later comparison of symbol addresses in linux/amd64 test binaries, built from the base commit and from the PR's merge commit, shows the hot protobuf size functions (`proto.MarshalOptions.size`, `impl.(*MessageInfo).sizePointer`) each moved by 96 bytes, and the benchmark closure by 160. Those are amd64 binaries, not necessarily what CI ran, so the layout is indicative only, and no hardware-counter measurement ties the shift to the delta.

The bot's own history on the PR fits the layout reading. From 12 June, each update of its comment said four regressions, 6–9% at every span count. On 19 June, after `main` had moved, the same comment said four improvements of 6–8% for the same benchmark. That is not noise around zero. The bias was stable and changed sign when `main` moved, the same shape as OPERA: a systematic error that looks like signal.

The resolution: nothing. No code change for the benchmark. A speculative "fix" to quiet it would have been chasing shadows.

At the time, these benchmarks ran on shared CI runners. We have since moved them to dedicated bare-metal machines, which takes the noisy neighbours out of the picture. It doesn't take code layout out, and neither does a same-machine A/B, since the two binaries still differ in layout. It removes the machine. CI said +6 to 9% and my machine about −5% for a benchmark whose loop the PR never touched; a sign that flips between machines points at layout more than at code. Neither machine is authoritative by default; the flip is the tell to go and look at layout. The same benchmark tripped again on [#4926](https://github.com/DataDog/dd-trace-go/pull/4926), eleven days after #4891 was opened, with +6.5–8.5% on the same four sub-benchmarks. That time the flag was dismissed on sight as a known false positive: a code-layout artifact, with a local A/B of about +0.3%.

OPERA and #4891 teach the same thing. A number can be reproducible and still be directionally wrong, and a gate that is directionally wrong blocks good changes and waves bad ones through. One loose cable is bad luck. Knowing which cables to check is not, and the series gave us three.

## Three questions

Each earlier part went after one way a Go benchmark can mislead us. Side by side, they make a checklist to run before merging anything on a hot path:

| # | Question | Part | What to verify |
| --- | ---------- | ------ | ---------------- |
| 1 | Is the compiler measuring real work? | [Compiler honesty](/posts/go-benchmarks-lying-compiler-honesty/) | Sink pattern present; no discarded results; `allocs/op` > 0 when allocation is expected |
| 2 | Is my sample stable enough? | [Statistics](/posts/go-benchmarks-lying-statistics/) | CV < ~5%; at least `-count=10` |
| 3 | Is the difference large relative to the noise? | [Local reproduction](/posts/go-benchmarks-lying-local-reproduction/) & [CI](/posts/go-benchmarks-lying-ci/) | `benchstat` p-value < 0.05 and an effect that matters; environment diagnosed; A/B on the same machine, since a sub-10% micro delta can be code layout; CI used for detection, not as the primary measurement |

Each question gates the next. A benchmark the compiler has optimised away answers question 2 with noise, and a noisy environment makes question 3 unanswerable whatever the sample size. A checklist nobody runs is decoration, so each question gets a tool.

## Wire it up this afternoon

The three CLIs from the talk are in [benchlab](https://github.com/kakkoyun/benchlab/tree/v0.1.0), my own project, one per question. Everything here describes `v0.1.0`, the tag pinned for the talk on 12 August 2026. They share one stdlib-only Go module (`go 1.24`). Pin the tag, because unreleased work on `main` changes some of these flags:

```bash
go install github.com/kakkoyun/benchlab/cmd/...@v0.1.0
```

We'll take them in question order, starting with the compiler.

### `honestbench`

`honestbench` answers question 1. It walks `*_test.go` files with `go/ast` and flags results discarded after computation (dead-code elimination candidates), missing sink patterns, `StopTimer`/`StartTimer` misordering, and `b.N` loops that should migrate to `testing.B.Loop`, introduced in Go 1.24. It exits 1 on findings, so it works as a CI gate:

```bash
honestbench -r ./...
```

`-r` recurses into subdirectories, `-json` prints machine-readable output and `-q` prints findings only. Exit codes are `0` for clean, `1` for findings and `2` for an error. We run it before reading a single `ns/op`, because a finding on a `b.N` loop means the benchmark probably measures something other than what we think.

One caveat: `v0.1.0` also reports discarded results inside `for b.Loop()` bodies, where the `testing` package [documents](https://pkg.go.dev/testing#B.Loop) that call results are kept alive. That includes the `proto.Size` loop from my story. Treat a finding there as a prompt to look, not as proof. (Yes, my own linter flags my own story. Tools are measurements too.) Once the compiler is honest, the next question is whether the sample is.

### `benchgate`

`benchgate` answers question 2. It runs benchmarks N times, computes the coefficient of variation (CV) per benchmark, and fails if any exceeds a threshold. It can also diff against a saved baseline through `benchstat`, which must be on your `PATH` (see [part 2](/posts/go-benchmarks-lying-statistics/)):

```bash
benchgate -pkg ./... -count 10 -cv-threshold 5.0
```

`-pkg` (default `./...`) and `-bench` (default `.`) pick what to run, `-count` (default 10) says how many times, and `-cv-threshold` (default 5.0, in percent) sets the bar. `-baseline` takes a saved file to diff against, `-save` writes one, and `-json` prints machine-readable output. A gate at 5% catches environments too noisy for a reliable A/B before we waste time interpreting numbers. [Part 4](/posts/go-benchmarks-lying-ci/#why-shared-runners-lie) shows what SMT and frequency scaling do to CV.

To capture a baseline on the current branch and compare after a change, we run it twice:

```bash
benchgate -pkg ./... -count 10 -save old.txt
# make your change
benchgate -pkg ./... -count 10 -baseline old.txt
```

The second run calls `benchstat old.txt <new-output>` for us and prints the comparison. The exit code comes from the CV check alone, so a +40% delta on a quiet sample still exits 0; gating on the delta is a step you write. A stable sample still says nothing about the machine that produced it, which is what the third tool is for.

### `benchenv`

`benchenv` helps with question 3. It diagnoses the measurement environment: SMT state, CPU frequency governor, Turbo Boost, system load average, and which of `perflock`, `benchstat` and `benchdiff` are installed. It works across platforms and degrades gracefully on macOS, where sysfs controls are unavailable. Its only flag is `-json`.

```bash
benchenv
```

Here is one run, on one machine: an Apple M4 Max (darwin/arm64, Go 1.27.1) with `benchenv` from `v0.1.0`, on 2026-10-02. The load-average warning depends on what else the machine was doing, so yours will differ.

```text
benchenv: benchmarking environment diagnosis (darwin/arm64, 16 CPUs)

  [unavailable]   SMT control — macOS does not expose SMT control via sysfs — use a Linux machine or bare-metal CI runner for publication-quality numbers
  [unavailable]   CPU frequency governor — macOS does not expose a CPU frequency governor — use a Linux machine or bare-metal CI runner for publication-quality numbers
  [unavailable]   Turbo Boost — macOS does not expose Turbo Boost control from user space — use a Linux machine or bare-metal CI runner for publication-quality numbers
  [warn]          load average — close background applications before benchmarking
  [unavailable]   thermal pressure — macOS thermal state is not accessible from user space — watch for CPU throttling on sustained benchmark runs
  [warn]          perflock not installed — go install github.com/aclements/perflock@latest
  [ok]            benchstat installed — benchstat found on PATH
  [warn]          benchdiff not installed — go install github.com/willabides/benchdiff/cmd/benchdiff@latest
  [ok]            GOMAXPROCS / NumCPU — NumCPU=16 GOMAXPROCS=16

Summary: 2 ok, 3 warn, 4 unavailable. Fix warnings before trusting benchmark numbers.
```

Every `[warn]` line is a noise source or a missing tool, and the `[unavailable]` lines are macOS declining to say. The install hints print `@latest`; pin `perflock` and `benchdiff` the way [part 3](/posts/go-benchmarks-lying-local-reproduction/) does. We run `benchenv` once at the start of a benchmarking session, fix the warnings, then run `benchgate`, then compare with `benchstat`.

## The minimum viable discipline

If we keep one thing from this series, it should be this: run benchmarks ten times, not once. The whole loop needs only the Go toolchain and `benchstat`:

```bash
# Baseline on the current branch
go test -bench=. -benchmem -count=10 ./... | tee old.txt

# After your change
go test -bench=. -benchmem -count=10 ./... | tee new.txt

# Compare
benchstat old.txt new.txt
```

`benchstat` then tells us whether the difference clears the noise. That is the floor. For anything you report, use `-count=20` (plus `-benchtime=2s` on a noisy Mac, [part 3](/posts/go-benchmarks-lying-local-reproduction/)), and for CI baselines consider a fixed count (`-benchtime=Nx`, [part 2](/posts/go-benchmarks-lying-statistics/)) over part 4's time-based 2s and 5s. Around that loop go all three tools: `honestbench -r ./...` before reading any numbers, `benchenv` on any new machine or CI runner, and `benchgate -cv-threshold 5.0` as a gate that fails early when the environment is too noisy for a reliable signal.

Three tools, under an hour to wire up, for any Go project. Time to check them against the cable from the start.

Versions, links and commands checked on 2 October 2026.

## Where to go from here

Back to the loose cable. Run #4891 through the questions. Question 1 passes: the loop sizes a real protobuf message. Question 2 passes too, with a CV under 0.1%, and that is the trap, because a stable sample is not the same as a right one. Question 3 is the one that failed. The CI delta said slower, the A/B on one machine said faster, and the sign flipped when `main` moved. The A/B on one machine took the machine out of the story, with CI as the smoke alarm rather than the judge.

That is the series. The [talk page](/talks/why-your-go-benchmarks-are-lying/) has the slides and links, the CLIs are in [benchlab](https://github.com/kakkoyun/benchlab/tree/v0.1.0), and the demo results are in [gopherconuk-26](https://github.com/kakkoyun/gopherconuk-26/tree/fdce88cc0ce129b7d2edfb1a20d02fe647c17eeb/talks/go-benchmarks-lying).

Go find your loose cable. Preferably before anyone calls a press conference.
