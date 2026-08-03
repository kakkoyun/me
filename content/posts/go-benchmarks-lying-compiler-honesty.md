---
title: "The Go Benchmark That Measured Nothing: Compiler Honesty in testing.B"
description: "Dead-code elimination, constant folding, and inlining can silently gut a Go benchmark loop. Learn how to detect each transformation, why allocs/op is the honest signal, and how testing.B.Loop in Go 1.24 removes most of these footguns at the language level."
date: 2026-09-01T00:00:00Z
publishDate: 2026-09-01T00:00:00Z
draft: true
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

### The Number That Felt Too Good

You write a benchmark. You run it. `0.30 ns/op`. Zero allocations. The function executes a million times per second, apparently.

Then someone on the team points out that the function you just benchmarked allocates 64 bytes. Every time. That is not negotiable — it calls `make`. There is no path through the code that avoids it.

So where did the allocations go?

They were never there. The compiler looked at your benchmark loop, noticed that the return value of your function was unused, and decided — correctly, according to the language specification — that the entire call was dead code. It removed it. Your benchmark loop still ran `b.N` times. It just ran empty.

This is not a compiler bug. It is the optimizer doing exactly what it should. The problem is that the same transformations that make production code fast make microbenchmarks fundamentally adversarial. An earlier post, [Measuring Software Performance: Why Your Benchmarks Are Probably Lying](/posts/fosdem-2026-measuring-software-performance/), covers why hardware noise and statistical method matter in any language. This series is about a different category of problem: the ones the Go compiler introduces before the benchmark ever reaches a CPU.

This is post 1 of "Why Your Go Benchmarks Are Lying," a companion series to the talk of the same name at GopherCon UK 2026. All code shown is from the [demo repository](https://github.com/kakkoyun/gopherconuk-26) (`talks/go-benchmarks-lying/demo/`).

---

### The Compiler Is Not a Neutral Observer

#### Dead-Code Elimination

Dead-code elimination (DCE) is the compiler transformation most likely to produce a benchmark that measures nothing. The rule is simple: if a computation produces a value that nothing ever reads, the compiler can remove the computation. In a benchmark, you typically call a function and throw away the return value. From the compiler's perspective, that return value is unobserved — so the call is dead.

Here is the exact pattern from `dce_bench_test.go`:

```go
func makeBuffer(n int) []byte {
    return make([]byte, n) // heap-escaping allocation
}

// Result of makeBuffer is unused → DCE fires.
// Expected: allocs/op = 0 (the allocation never happens).
func BenchmarkMakeBuffer_DCE(b *testing.B) {
    for range b.N {
        makeBuffer(64) // result discarded → compiler removes the call
    }
}
```

The fix is the **sink pattern**: assign the result to a local variable inside the loop, then write that local to a package-level variable after the loop. Because the package-level variable is visible to other packages — the compiler cannot prove it is never read — it must keep the computation that produces the value assigned to it.

```go
var sink []byte // package-level sink defeats DCE

func BenchmarkMakeBuffer_Correct(b *testing.B) {
    var s []byte
    for range b.N {
        s = makeBuffer(64)
    }
    sink = s // one global write per benchmark run, not per iteration
}
```

The two-variable idiom matters. Writing to `sink` inside the loop would add one global memory write per iteration — measurable overhead. Writing `sink = s` after the loop costs almost nothing, and it is enough to keep the entire computation chain alive.

#### Constant Folding

If every input to an expression is a compile-time constant, the compiler evaluates the expression at compile time and replaces it with a literal. The benchmark then iterates over a constant load — which takes no time to compute at runtime, because it was already computed during compilation.

The `bits.OnesCount` example from `dce_bench_test.go` illustrates this:

```go
// Constant input → folded at compile time.
// Proof: "go build -gcflags='-S' ." shows MOVD $3, not a VCNT instruction.
func BenchmarkOnesCount_ConstantFolded(b *testing.B) {
    var s int
    for range b.N {
        s = bits.OnesCount(0b10110) // constant → evaluated at compile time
    }
    sinkInt = s
}

var onesInput uint = 0b10110

// Runtime value → actual OnesCount instruction.
func BenchmarkOnesCount_Correct(b *testing.B) {
    var s int
    for range b.N {
        s = bits.OnesCount(onesInput)
    }
    sinkInt = s
}
```

On Apple Silicon both versions report similar timings — `bits.OnesCount` is a single hardware instruction that runs near the timer floor regardless. But the assembly tells the real story. Run `make asm-dce` in the demo directory:

```bash
go build -gcflags='-S' . 2>&1 | grep -A5 "OnesCount_ConstantFolded"
```

The constant-folded version shows `MOVD $3, Rxx` — the compiler substituted the literal 3 for the entire `bits.OnesCount` call. The correct version shows `VCNT` and `UADDLV` — an actual popcount instruction pair. The timing looks similar; the code is entirely different.

The fix is a package-level variable for inputs. The compiler cannot constant-propagate through a package-level variable because its value may change between compilation and runtime.

#### Inlining and Its Aftermath

The Go compiler inlines small functions by replacing each call site with a copy of the callee's body. Inlining is nearly always a good thing in production. In a benchmark, it interacts badly with DCE: once the callee's body is inlined into the loop, the compiler can see that the result is unused and eliminate the now-inlined body entirely.

The classic shape is a predicate like `isCond(201)` — a function whose conditional looks expensive but which the compiler, once it has inlined the body and seen a constant argument, can prove always returns `false`. The call disappears. The same `var sink T` pattern defeats it, with one addition: use a non-constant input *and* capture the result. Either alone is not enough.

Check what the compiler will inline with `go build -gcflags='-m'`. Any function annotated `can inline X` will be inlined at every call site, which makes it a candidate for subsequent DCE if the result is unused.

---

### The Honest Signal

#### Why `allocs/op` Is Harder to Fool Than `ns/op`

This brings us to the centerpiece of the talk.

`ns/op` can be fooled. A benchmark loop that runs empty — because DCE eliminated the work — still reports a plausible-looking time. On a modern CPU the measurement floor is around 0.25 ns. An empty loop and a very fast function can look identical.

`allocs/op` is different. An allocation is a discrete, observable event. The testing framework captures `runtime.ReadMemStats` at the start and end of the benchmark run, computes the delta, and divides by `b.N`. Either a heap allocation happened, or it did not. There is no timer floor to hide behind.

Run the DCE demo yourself with `make bench-dce`:

```bash
go test -bench=BenchmarkMakeBuffer -benchmem -count=10 ./...
```

Here is the actual output on an Apple M4 Max, six runs averaged:

| Benchmark | ns/op | B/op | allocs/op |
|---|---|---|---|
| `BenchmarkMakeBuffer_DCE` | 0.2532 | 0 | **0** |
| `BenchmarkMakeBuffer_Correct` | 11.14 | 64 | **1** |

`BenchmarkMakeBuffer_DCE` reports zero bytes allocated and zero allocations. Not "very few" — zero. The `make([]byte, 64)` call that is unconditionally in the function body never executed. The allocation column is hardware-independent proof: you cannot have a 64-byte heap allocation that costs 0 bytes.

`BenchmarkMakeBuffer_Correct` reports `64 B/op, 1 allocs/op`. The allocation happened. The measurement is trustworthy.

This is why `-benchmem` should be the default invocation for any Go benchmark:

```bash
go test -bench=. -benchmem ./...
```

Allocation counts surface unexpected heap escapes, regressions from interface boxing, and missed pool opportunities. And when DCE strikes, they tell you immediately — because `0 allocs/op` for a function that provably allocates is impossible.

A result under 1 ns/op for anything non-trivial is the strongest signal that DCE or constant folding has struck. Any result that does not scale with the computational complexity of the function under test deserves scrutiny.

---

### Timer Traps

The `testing.B` timer starts when the benchmark function is called. Everything that runs before the first iteration of the measurement loop is included in the measurement unless you explicitly reset it.

#### One-Time Setup: `ResetTimer`

`b.ResetTimer()` zeros both the elapsed time and the allocation counters. Call it after any setup that should not be included in the measurement:

```go
func BenchmarkHash_BN_WithSetup_Correct(b *testing.B) {
    data := make([]byte, 1024)
    copy(data, payload)
    b.ResetTimer() // exclude setup from timing
    var s [32]byte
    for range b.N {
        s = sha256.Sum256(data)
    }
    _ = s
}
```

`ResetTimer` does not stop the timer. If the timer was running, it keeps running after the reset — it just zeroes the accumulated time.

#### Per-Iteration Setup: `StopTimer` and `StartTimer`

When each iteration requires its own setup, use `b.StopTimer()` and `b.StartTimer()` around it. The order matters precisely:

```go
func BenchmarkProcess_PerIterSetup_Correct(b *testing.B) {
    var s string
    for range b.N {
        b.StopTimer()
        input := buildFixture(fixtureSize) // not timed
        b.StartTimer()                     // restart before the work
        s = processString(input)           // only this is measured
    }
    sinkStr = s
}
```

The `BenchmarkProcess_TimerOrder_BUG` in `timer_bench_test.go` shows what happens when you get the order wrong — `StartTimer` is called after the work, not before it. The timer measures fixture construction; `processString` runs while the timer is off. The reported ns/op is the cost of the wrong thing.

#### The Benchmark That Never Terminates

There is a worse variant: `StopTimer` with no `StartTimer` at all.

The testing framework determines how long to run a benchmark by accumulating timed duration until it reaches the target time (default 1 second). If the timer is stopped and never restarted, `b.duration` never accumulates. The framework keeps doubling `b.N` and calling the benchmark function again. The benchmark runs forever.

This is why the demo repository describes that case rather than demonstrating it — the comment in `timer_bench_test.go` reads "Don't run that live." We found out the direct way. If you run `make bench-timer` and a benchmark hangs, a missing `b.StartTimer()` is the likely cause. `Ctrl-C`, add the missing call, run again.

---

### `testing.B.Loop` (Go 1.24): The Form That Removes Most of This

Austin Clements proposed `testing.B.Loop` in [Go issue #61515](https://github.com/golang/go/issues/61515) specifically because the `b.N` pattern has a cluster of failure modes that are easy to hit and hard to detect statically. It shipped in Go 1.24.

The form is:

```go
func BenchmarkHash_BLoop(b *testing.B) {
    // Setup: excluded from timing automatically.
    data := make([]byte, 1024)
    copy(data, payload)

    var s [32]byte
    for b.Loop() {
        s = sha256.Sum256(data)
    }
    _ = s
}
```

Setup before the loop is automatically excluded — no `b.ResetTimer()` needed. The benchmark function is called exactly once per `-count` value, so expensive setup does not re-execute across the ramp-up iterations that the framework uses to find a stable `b.N`. And in Go 1.24, the compiler detects loops whose condition is syntactically `b.Loop()` and disables inlining into the loop body — which severs the inlining-then-DCE chain described earlier.

| Behaviour | `for range b.N` | `for b.Loop()` |
|---|---|---|
| Automatic `ResetTimer` at loop start | No | Yes |
| Automatic `StopTimer` at loop end | No | Yes |
| Benchmark function called per ramp-up | Multiple times | Exactly once per `-count` |
| Setup before loop re-executes on ramp-up | Yes | No |
| DCE of loop body prevented by compiler | No | Yes |
| Compatible with `StopTimer`/`StartTimer` inside | Yes | Yes |

One limitation: the DCE prevention applies only when the loop condition is written exactly as `b.Loop()`. Assigning the method to a variable first — `loop := b.Loop; for loop()` — does not trigger the compiler transformation. Write the condition literally.

Per-iteration setup still requires `b.StopTimer` and `b.StartTimer` inside the loop — `B.Loop` does not change that. And there must be exactly one benchmark loop per function; `b.N` and `b.Loop` cannot coexist in the same benchmark.

For new benchmarks, prefer `b.Loop`. Migrating an existing benchmark is mechanical: replace `for n := 0; n < b.N; n++` (or `for range b.N`) with `for b.Loop()` and remove any `b.ResetTimer()` that existed only to exclude setup before the loop.

---

### Where to Go From Here

The transformations covered here — DCE, constant folding, inlining, timer misuse — are about whether the benchmark measures anything at all. The next problem is harder: assuming the benchmark does measure real work, what do you do with a single `ns/op` number?

A single number is not a result. It is one sample from a distribution. Two benchmarks can share a mean and have completely different distributions. Post 2, [A Single Benchmark Number Is a Lie](/posts/go-benchmarks-lying-statistics/), covers how to read that distribution, how to use `benchstat` to compare results across commits, and when a measured difference is real rather than noise.

---

### Resources

- Demo code: [`talks/go-benchmarks-lying/demo/`](https://github.com/kakkoyun/gopherconuk-26/tree/main/talks/go-benchmarks-lying/demo) — `make bench-dce`, `make asm-dce`, `make bench-timer`
- Talk: "Why Your Go Benchmarks Are Lying (And How to Stop Them)", GopherCon UK 2026
- Prerequisite post: [Measuring Software Performance: Why Your Benchmarks Are Probably Lying](/posts/fosdem-2026-measuring-software-performance/)
- Dave Cheney — [How to write benchmarks in Go](https://dave.cheney.net/2013/06/30/how-to-write-benchmarks-in-go)
- Go Team — [Evolving the Go benchmark API](https://go.dev/blog/testing-b-loop) (the `testing.B.Loop` announcement post)
- Austin Clements — [Go proposal #61515: testing: add testing.B.Loop for iteration](https://github.com/golang/go/issues/61515)
- Go standard library — [`testing` package documentation](https://pkg.go.dev/testing)
- Go 1.24 Release Notes — [testing.B.Loop](https://go.dev/doc/go1.24)
