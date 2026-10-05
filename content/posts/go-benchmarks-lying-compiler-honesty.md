---
title: "The Go Benchmark That Measured Nothing: Compiler Honesty in testing.B"
description: "Dead-code elimination, constant folding and inlining can silently empty a Go benchmark loop. Here is how to catch each one, and how testing.B.Loop removes most of them."
date: 2026-07-07T00:00:00Z
publishDate: 2026-07-07T00:00:00Z
promote: false
categories:
  - engineering
tags:
  - blog
  - go
  - performance
  - benchmarking
  - testing
series:
  - Why Your Go Benchmarks Are Lying
showToc: true
tocOpen: false
---

We're going to chase down one benchmark result that looks suspiciously good. The function under test calls `make([]byte, 64)` every time it runs, and the benchmark reports `0.34 ns/op`, `0 B/op`, `0 allocs/op`. That is almost three billion heap allocations per second on a laptop, and the allocator counted none of them. (It comes from a real run, more on that below.) Keep it in your pocket; we'll follow it the whole way.

Where did the allocations go? They were never there. The compiler looked at the benchmark loop, noticed that the return value was unused, and, once the call was inlined, could prove that the body had no observable effect. It removed the body. The loop still ran `b.N` times. It just ran empty. The fastest code is the code that never runs, and the least useful to benchmark. This is not a compiler bug: the optimizer did its job, and nobody told it we wanted to watch. The transformations that make production code fast make microbenchmarks adversarial.

This is part 1 of 5 in the [Why Your Go Benchmarks Are Lying](/series/why-your-go-benchmarks-are-lying/) series, the written companion to the [GopherCon UK 2026 talk](/talks/why-your-go-benchmarks-are-lying/) of the same name. The series asks three questions of every benchmark number: did the compiler let it measure real work, is the sample stable, and is the difference large relative to the noise? This part answers the first. We'll catch the compiler emptying a loop in two ways, find the one column of `go test` output it cannot fool, trip over the benchmark timer ourselves, and finish with `testing.B.Loop`, the standard library's fix for most of it. Part 2 takes on the sample, parts 3 and 4 the machine, and part 5 turns the three questions into a checklist. New to `testing.B`? The primer [Benchmarking Go, quickly](/posts/go-benchmarks-quickly/) covers writing and reading one first. A benchmark bot once flagged a pull request of mine as 6 to 9% slower; hold that thought for part 5.

The prerequisite is [Measuring Software Performance: Why Your Benchmarks Are Probably Lying](/posts/fosdem-2026-measuring-software-performance/), which covers why hardware noise and statistical method matter in any language. Here we deal with what the Go compiler does before the benchmark ever reaches a CPU. All the code comes from the [demo repository](https://github.com/kakkoyun/gopherconuk-26/tree/fdce88cc0ce129b7d2edfb1a20d02fe647c17eeb/talks/go-benchmarks-lying/demo) (`talks/go-benchmarks-lying/demo/`, at commit `fdce88c`).

## The compiler is not a neutral observer

Our suspect is dead-code elimination, with inlining as its accomplice. Its cousin, constant folding, does the same damage by another route. We start with the suspect.

### Dead-code elimination

Dead-code elimination (DCE) follows a simple rule: if a computation produces a value that nothing ever reads, the compiler can remove it. In a benchmark we typically call a function and throw away the return value. Inlining is the accomplice: the compiler replaces a call to a small function with a copy of its body, nearly always a win in production. In a benchmark, once the body sits inside the loop, the compiler can see the result is unused and delete the lot (a call it cannot inline is kept).

Here is the pair behind our suspect, excerpted from `dce_bench_test.go` (long comments left out):

```go
func makeBuffer(n int) []byte {
	return make([]byte, n) // heap-escaping allocation
}

func BenchmarkMakeBuffer_DCE(b *testing.B) {
	for range b.N {
		makeBuffer(64) // result discarded → compiler removes the call
	}
}
```

`makeBuffer` really does put its buffer on the heap when called on its own. The benchmark discards the result, and because `makeBuffer` is small enough to inline, the compiler sees a `make` nobody reads and deletes it, allocation included.

This reproduces on Go 1.25 and later (I tested 1.25.0, 1.26.0 and 1.27.1). On Go 1.24 the inlined `make` still escapes to the heap, so it allocates even with the result discarded. And the trick needs inlining: put `//go:noinline` on `makeBuffer` and the same benchmark reports `64 B/op, 1 allocs/op`.

The fix is the **sink pattern**: assign the result to a local variable inside the loop, then write that local to a package-level variable after the loop. The compiler treats a store to a package-level variable as observable, so it must keep the computation behind it. Same file again:

```go
// sink is the package-level variable that defeats DCE.
var sink []byte

func BenchmarkMakeBuffer_Correct(b *testing.B) {
	var s []byte
	for range b.N {
		s = makeBuffer(64)
	}
	sink = s
}
```

The two-variable idiom matters: writing to `sink` inside the loop would add a global write per iteration, which is measurable, while one write after the loop costs almost nothing and still keeps the whole chain alive. Every iteration still runs: with the last buffer stored in `sink`, the `make` escapes, so each one allocates. `runtime.KeepAlive` is callable too, but forces no escape.

A sink keeps a result alive, but it cannot help if the compiler already knows the answer before the program runs.

### Constant folding

If every input to an expression is a compile-time constant, the compiler evaluates the expression at compile time and replaces it with a literal. The benchmark then loads a constant, and the compiler already did the work. The `bits.OnesCount` pair in the same file shows it: the first function feeds in a constant, the second a package-level variable, which the compiler cannot constant-propagate because its value can change at run time:

```go
var sinkInt int

func BenchmarkOnesCount_ConstantFolded(b *testing.B) {
	var s int
	for range b.N {
		s = bits.OnesCount(0b10110) // constant → evaluated at compile time
	}
	sinkInt = s
}

// onesInput breaks the constant chain — compiler cannot prove this is 0b10110.
var onesInput uint = 0b10110

func BenchmarkOnesCount_Correct(b *testing.B) {
	var s int
	for range b.N {
		s = bits.OnesCount(onesInput)
	}
	sinkInt = s
}
```

On Apple Silicon both versions report similar timings, because `bits.OnesCount` compiles to a four-instruction NEON sequence that runs near the timer floor regardless. The timing can't tell them apart, so we ask the assembly instead (`make asm-dce` runs this). `XXX` matches nothing, so no benchmark runs, and plain `go build` would print nothing because it never compiles `_test.go` files:

```bash
go test -gcflags='-S' -run XXX -bench XXX . 2>&1 | grep -A14 'OnesCount_ConstantFolded(SB)'
```

The constant-folded version shows `MOVD $3, Rxx`: the compiler substituted the literal 3 for the entire `bits.OnesCount` call. The correct version shows `VCNT` and `VUADDLV`, an actual popcount sequence (arm64 names; on amd64, widen the grep to `-A30` and look for `MOVL $3` against `POPCNTQ`). Similar timing, entirely different code.

Both tricks leave `ns/op` looking perfectly believable. If the time column can't be trusted, what can?

## The honest signal

Back to our suspect. `0.34 ns/op` sits right next to the measurement floor on Apple Silicon, around 0.25 ns, about one loop iteration per cycle. An empty loop and a blazing-fast function look identical down there. `allocs/op` has no such floor. An allocation is a discrete event: the testing framework reads `runtime.ReadMemStats` at the start and end of the run, takes the delta, and divides by `b.N`. Either a heap allocation happened or it did not.

Let's run the DCE pair side by side (`make bench-dce` does it, after a one-time `make tools` to install `benchstat`):

```bash
go test -run XXX -bench=BenchmarkMakeBuffer -benchmem -count=10 .
```

`benchstat` summarizes the ten runs as medians. This is one run on one machine: an Apple M4 Max (darwin/arm64) under background load (load average 8 to 11), Go 1.27.1. The `ns/op` column is noisy and `allocs/op` is exact, which is the point.

| Benchmark | ns/op | B/op | allocs/op |
|---|---|---|---|
| `BenchmarkMakeBuffer_DCE` | 0.3444 ± 96% | 0 | **0** |
| `BenchmarkMakeBuffer_Correct` | 15.43 ± 29% | 64 | **1** |

I'm recapturing these on a quiet machine with a reproduction kit, and I'll update the table when the new numbers are in.

`BenchmarkMakeBuffer_DCE` reports zero bytes and zero allocations. Not "almost none": zero. The `make([]byte, 64)` in the function body never executed, and no timer resolution or clock speed can change that column. `BenchmarkMakeBuffer_Correct` reports `64 B/op, 1 allocs/op`: the allocation happened, so that measurement is trustworthy. Mystery solved: the `0.34 ns/op` was an empty loop, and the honest cost is about 15 ns and one allocation. Remember that zero, though. It has one more trick left.

This is why `-benchmem` belongs in every Go benchmark invocation (`go test -bench=. -benchmem ./...`). `0 allocs/op` for a function you know calls `make` is a red flag, and a result under 1 ns/op for anything non-trivial is the strongest hint that DCE or constant folding has struck. Two caveats apply. `allocs/op` is an integer average, so a loop that hits the heap on every fourth iteration rounds down to `0`, and `B/op` gives it away. And a zero can also mean the buffer stayed on the stack, so check `-gcflags=-m`: `inlining call to X` means it was inlined; `can inline X` only means it could be. And for a function that never allocates, `allocs/op` stays silent; check the assembly instead.

The compiler is not the only thing that can make a benchmark measure the wrong thing. We can do it to ourselves, with the timer.

## Timer traps

First, how `testing.B` keeps time. It runs the benchmark with a growing iteration count until one run fills `-benchtime`; `ns/op` is that run's duration divided by the count. Go compiles ahead of time, so there is no JIT warmup, and each `-count` line is one such mean, not a distribution.

The `testing.B` timer starts when the benchmark function is called, so everything that runs before the loop is measured unless we reset it.

`b.ResetTimer()` zeros the elapsed time and the allocation counters, so we call it after one-time setup, just before the loop. It does not stop the timer: a running timer keeps running, from zero.

### Per-iteration setup: `StopTimer` and `StartTimer`

When each iteration needs its own setup, we bracket the setup with `b.StopTimer()` and `b.StartTimer()`, and the order matters. This one is from `timer_bench_test.go`, where `buildFixture`, `fixtureSize`, `processString` and `sinkStr` are helpers:

```go
func BenchmarkProcess_PerIterSetup_Correct(b *testing.B) {
	var s string
	for range b.N {
		b.StopTimer()
		input := buildFixture(fixtureSize)
		b.StartTimer() // ← timer restarts; only processString is measured
		s = processString(input)
	}
	sinkStr = s
}
```

The timer stops before the fixture is built and restarts before the work, so only `processString` is timed. Call `StartTimer` after the work instead, as `BenchmarkProcess_TimerOrder_BUG` in the same file does, and the timer measures fixture construction while `processString` runs with the timer off. The reported ns/op is then the cost of the wrong thing.

### The benchmark that reports nonsense

Worse: `StopTimer` with no `StartTimer` at all. The testing framework decides how long to run a benchmark by accumulating timed duration until it reaches the target time (default 1 second). If the timer is stopped and never restarted, the accumulated duration holds only the time up to the first `StopTimer`. The framework keeps growing `b.N` until it hits its cap of 1e9. For a trivial body with a single `StopTimer`, it reaches that cap in about 20 seconds and prints something like `0.0000007 ns/op`. Another number that looks suspiciously good.

The demo repository describes this case rather than demonstrating it. The comment in `timer_bench_test.go` reads "Don't run that live." We found out the direct way. If one of your own benchmarks seems to hang, look for a missing `b.StartTimer()`, or a stop/start pair left at the default `-benchtime`. `Ctrl-C`, fix it, run again. (Each `StopTimer`/`StartTimer` call runs `runtime.ReadMemStats`, which stops the world, which is why the demo pins these benchmarks to `-benchtime=50000x`, a fixed count with no ramp.)

Empty loops, forgotten resets, timers left off: all mistakes the testing package could make impossible. Since Go 1.24, it covers most of them.

## `testing.B.Loop` in Go 1.24 removes most of this

Austin Clements proposed `testing.B.Loop` in [Go issue #61515](https://github.com/golang/go/issues/61515) because the `b.N` pattern has failure modes that are easy to hit and hard to detect statically. It shipped in [Go 1.24](https://go.dev/doc/go1.24). Here is the demo's hashing benchmark in the new form, from `bloop_bench_test.go` (`payload` is a package-level `[]byte` fixture):

```go
func BenchmarkHash_BLoop(b *testing.B) {
	// Setup: excluded from timing automatically.
	data := make([]byte, 1024)
	copy(data, payload)

	var s [32]byte
	for b.Loop() { // ← each call to Loop() is one measured iteration
		s = sha256.Sum256(data)
	}
	_ = s
}
```

Notice what is missing: no `b.ResetTimer()`. [The first call to `Loop` resets the timer and the call that returns false stops it](https://pkg.go.dev/testing#B.Loop), so setup and cleanup are not measured. The benchmark function is called exactly once per `-count` value, so expensive setup does not re-execute while the framework ramps `b.N` up. And the compiler recognizes loops whose condition is syntactically `b.Loop()` and keeps the arguments, results and assigned variables of calls in the loop body alive (it wraps them in a `runtime.KeepAlive`), so inlining can no longer leave a dead body behind. Go 1.24 and 1.25 did this by [refusing to inline into the body](https://go.dev/blog/testing-b-loop), which could add heap allocations that production code would not have. [Go 1.26 keeps inlining and keeps the values alive instead](https://go.dev/doc/go1.26).

The DCE protection has limits. It had a bug in Go 1.26.0 to 1.26.2, where assigning a call's result to `_` inside the loop still let the compiler drop the body ([#77654](https://github.com/golang/go/issues/77654), fixed in Go 1.26.3 and 1.27). It applies only when the loop condition is written exactly as `b.Loop()`: assigning the method to a variable first (`loop := b.Loop; for loop()`) does not trigger the compiler transformation.

`b.Loop` protects the call, not its inputs: `bits.OnesCount(0b10110)` in a `for b.Loop()` body still folds to `MOVL $3` on amd64 (Go 1.27.1), so keep a non-constant input. `_ = s` after the loop only silences "declared and not used"; `-benchmem` remains the check.

A `StartTimer` that never comes is a fatal error with `b.Loop` ("B.Loop called with timer stopped"), not a hang.

For new benchmarks, prefer `b.Loop`. Migrating an old one is mechanical: swap `for range b.N` for `for b.Loop()` and drop any `b.ResetTimer()` that only excluded setup. Code that reads `b.N` inside the loop needs a second look: `b.N` is 0 until the loop ends.

Now back to our number one last time. `0.34 ns/op` started as an empty loop, and the sink turned it into 15 ns and one allocation. On Go 1.26 and later, `for b.Loop() { makeBuffer(64) }` reports `0 B/op, 0 allocs/op` for the same buffer, and this time the zero is honest: the body runs, but the inlined buffer no longer escapes and lives on the stack, as it would in production code. Same digit, opposite meaning. Which `makeBuffer` number do we report? The `b.Loop` one. The sink version measures a heap escape that production code may not have, and `b.Loop` on Go 1.26 or later measures the function as the compiler would really treat it. If an allocation count surprises you, `-gcflags=-m` tells you which case you are in.

Enough reading. Let's run it.

## Try it

Everything above runs from the [demo repository](https://github.com/kakkoyun/gopherconuk-26/tree/fdce88cc0ce129b7d2edfb1a20d02fe647c17eeb/talks/go-benchmarks-lying/demo). The module declares `go 1.26.5`, so Go fetches that toolchain if yours is older. The assembly step shows arm64 instructions.

```console
git clone https://github.com/kakkoyun/gopherconuk-26
cd gopherconuk-26
git checkout fdce88cc0ce129b7d2edfb1a20d02fe647c17eeb
cd talks/go-benchmarks-lying/demo

# DCE and the sink pattern: compare allocs/op
go test -run XXX -bench='BenchmarkMakeBuffer' -benchmem -count=10 .

# Constant folding: MOVD $3 against VCNT and VUADDLV
go test -gcflags='-S' -run XXX -bench XXX . 2>&1 | grep -A14 'OnesCount_ConstantFolded(SB)'

# Timer ordering (fixed iterations, as make bench-timer does)
go test -run XXX -bench='BenchmarkProcess' -benchmem -count=3 -benchtime=50000x .
```

`BenchmarkMakeBuffer_DCE` should report `0 allocs/op`, and `BenchmarkMakeBuffer_Correct` should report `1`. Expect the ns/op column to wobble with whatever else your machine is doing. That wobble is the next part of the story.

Versions, links and commands checked on 2 October 2026.

## Up next

[Part 2, A Single Benchmark Number Is a Lie](/posts/go-benchmarks-lying-statistics/), assumes the benchmark does real work and asks what one `ns/op` number is worth: how to read the distribution behind it, how to compare commits with `benchstat`, and when a difference is real. The compiler is out of the way. The statistics are not. 📊
