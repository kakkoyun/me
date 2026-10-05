---
title: "Benchmarking Go, quickly"
description: "A primer before the Go benchmarks series: write one small benchmark, run it, and read every column, flag and compiler hint the next five posts take for granted."
date: 2026-06-30T00:00:00Z
publishDate: 2026-06-30T00:00:00Z
promote: false
categories:
  - engineering
tags:
  - blog
  - go
  - performance
  - benchmarking
  - testing
showToc: true
tocOpen: false
---

We're going to write one small benchmark, run it, and read every word of what comes back. By the end you'll know where `ns/op` comes from, what `-count` and `-benchtime` change, what the `-16` is, and how to ask the compiler and the profiler what the benchmark really did. Here is the line we'll be decoding:

```text
BenchmarkMakeBuffer-16	99632604	        18.53 ns/op	      64 B/op	       1 allocs/op
```

This is a primer before [part 1](/posts/go-benchmarks-lying-compiler-honesty/) of [Why Your Go Benchmarks Are Lying](/series/why-your-go-benchmarks-are-lying/), the written companion to my GopherCon UK talk, [Why Your Go Benchmarks Are Lying](/talks/why-your-go-benchmarks-are-lying/). The series argues about numbers like the one above, so it helps to know how they are made first. If you have run `go test -bench` before, skim.

## Write it, run it

Our benchmark allocates a 64-byte buffer and keeps it. It's the one the series uses as its running suspect, and it lives in a scratch module (`go mod init tiny`, one file, `tiny_test.go`):

```go
package tiny

import "testing"

func makeBuffer(n int) []byte {
	return make([]byte, n)
}

var sink []byte

func BenchmarkMakeBuffer(b *testing.B) {
	var s []byte
	for range b.N {
		s = makeBuffer(64)
	}
	sink = s
}
```

A benchmark is a function named `BenchmarkXxx` that takes a `*testing.B` and does its work `b.N` times. The package-level `sink` is there so the compiler can't throw the work away; [part 1](/posts/go-benchmarks-lying-compiler-honesty/) is about what happens without it. Let's run it:

```console
$ go test -run XXX -bench . -benchmem
goos: darwin
goarch: arm64
pkg: tiny
cpu: Apple M4 Max
BenchmarkMakeBuffer-16	99632604	        18.53 ns/op	      64 B/op	       1 allocs/op
PASS
ok  	tiny	2.105s
```

Every number in this post is from one run on one machine: an Apple M4 Max, Go 1.27.1, with a load average near 28 when I checked. A busy laptop is a fine teacher here, as you'll see. I'm recapturing these outputs on a quiet machine with a reproduction kit, and I'll update them when the new numbers are in.

Now the flags. [`-bench .`](https://pkg.go.dev/cmd/go#hdr-Testing_flags) selects benchmarks by regular expression, and by default none run. `-run XXX` does the same for tests; nothing is named `XXX`, so no test runs and the timing isn't muddied by them. `-benchmem` adds the last two columns: bytes and heap allocations per iteration. The first number is how many times the loop ran, and the second, `ns/op`, is the time per iteration. We'll start with the first.

## Where does 99,632,604 come from?

Nobody chose it. The testing package [runs the function once with `b.N = 1`, then predicts how many iterations would fill the benchmark time, adds 20% headroom, grows by at most 100× per step and stops at a billion](https://github.com/golang/go/blob/go1.27.1/src/testing/benchmark.go#L304-L326). To watch it happen, I temporarily added a `fmt.Fprintln(os.Stderr, "b.N =", b.N)` to a copy of the benchmark:

```console
$ go test -run XXX -bench Ramp 2>&1 | grep -E 'b\.N|ns/op'
b.N = 1
BenchmarkRamp-16	b.N = 100
b.N = 10000
b.N = 1000000
b.N = 28893382
b.N = 47900115
47900115	        22.76 ns/op
```

The function ran six times, and the printed line comes from the last run alone. The result is [its total time divided by `b.N`](https://github.com/golang/go/blob/go1.27.1/src/testing/benchmark.go#L555), which is why `ns/op` is a mean. The ramp isn't a fixed ladder: on the earlier run the last `b.N` was 99,632,604. The target is time, not a count, and `-benchtime` sets it. The default is `1s`; a value like `100x` means a fixed number of iterations.

Every `-count` repetition is its own ramp and its own mean:

```console
$ go test -run XXX -bench . -benchmem -count=3
BenchmarkMakeBuffer-16	96041296	        23.08 ns/op	      64 B/op	       1 allocs/op
BenchmarkMakeBuffer-16	61289114	        23.37 ns/op	      64 B/op	       1 allocs/op
BenchmarkMakeBuffer-16	100000000	        17.26 ns/op	      64 B/op	       1 allocs/op
```

Same binary, same code, and the slowest sample is about 35% slower than the fastest. Each line is one mean, so each is one sample. [Part 2](/posts/go-benchmarks-lying-statistics/) is about what to do with a handful of them.

Go is compiled ahead of time, so there is no JIT warmup for the ramp to wait out. One iteration still isn't representative. With `-benchtime=1x` the same benchmark reported 2500, 1667 and 2000 ns/op. I haven't chased down why (cold caches, the first allocation and timer granularity are my suspects).

That leaves the suffix. The `-16` is [`GOMAXPROCS`](https://github.com/golang/go/blob/go1.27.1/src/testing/benchmark.go#L671), and the suffix is dropped when the value is 1. With `-cpu 1,4` we get both forms:

```console
$ go test -run XXX -bench 'MakeBuffer$' -cpu 1,4
BenchmarkMakeBuffer     	83583531	        18.06 ns/op
BenchmarkMakeBuffer-4   	100000000	        20.72 ns/op
```

A missing suffix in someone else's output means they ran with `GOMAXPROCS=1`. We can read the whole line now. What we can't tell yet is whether the loop did what we think it did.

## The newer loop, and a suspicious zero

Go 1.24 added [`testing.B.Loop`](https://go.dev/doc/go1.24) as a replacement for the `b.N` loop. We add a second benchmark that uses it, with no sink:

```go
func BenchmarkMakeBufferLoop(b *testing.B) {
	for b.Loop() {
		makeBuffer(64)
	}
}
```

[`Loop` resets the timer on its first call and stops it when it returns false](https://pkg.go.dev/testing#B.Loop), so setup before it isn't measured. The benchmark function runs once per `-count`, and the compiler keeps the arguments and results of calls in the body alive, so it can't optimize away the whole loop body. (It has had bugs; [part 1](/posts/go-benchmarks-lying-compiler-honesty/) lists them.) [Go 1.26 changed how it keeps them alive](https://go.dev/doc/go1.26): inlining in the body is no longer blocked. Here are both benchmarks together:

```console
$ go test -run XXX -bench . -benchmem -count=3
BenchmarkMakeBuffer-16    	92055165	        21.90 ns/op	      64 B/op	       1 allocs/op
BenchmarkMakeBuffer-16    	88833778	        19.98 ns/op	      64 B/op	       1 allocs/op
BenchmarkMakeBuffer-16    	100000000	        23.30 ns/op	      64 B/op	       1 allocs/op
BenchmarkMakeBufferLoop-16	494076908	         3.145 ns/op	       0 B/op	       0 allocs/op
BenchmarkMakeBufferLoop-16	548045512	         2.975 ns/op	       0 B/op	       0 allocs/op
BenchmarkMakeBufferLoop-16	562811305	         2.071 ns/op	       0 B/op	       0 allocs/op
```

Same function, yet the loop version reports about 3 ns against about 20, and zero allocations. The series spends a post on numbers like that. Let's ask the compiler directly.

## Ask the compiler

`-gcflags=-m` prints the compiler's inlining and escape-analysis decisions. The code lives in a `_test.go` file, so it has to be `go test`, and `-run XXX -bench XXX` compiles everything without running anything. I kept the two lines about our buffer:

```console
$ go test -gcflags=-m -run XXX -bench XXX . 2>&1 | grep 'make(\[\]byte, 64)'
./tiny_test.go:14:17: make([]byte, 64) escapes to heap
./tiny_test.go:21:13: make([]byte, 64) does not escape
```

Line 14 is the `b.N` benchmark: the buffer goes to the heap, hence `1 allocs/op`. Line 21 is the `b.Loop` one: the buffer stays on the stack, so the zero is honest. `-S` goes one level lower and prints the assembly. The `b.N` benchmark calls the allocator (I trimmed the file path; the same grep on `BenchmarkMakeBufferLoop STEXT` prints nothing):

```console
$ go test -gcflags=-S -run XXX -bench XXX . 2>&1 | grep -A40 'tiny.BenchmarkMakeBuffer STEXT' | grep 'CALL.*makeslice'
0x0040 00064 (tiny_test.go:6)	CALL	runtime.makeslice(SB)
```

That is enough compiler for now; [part 1](/posts/go-benchmarks-lying-compiler-honesty/) reads these outputs in anger.

## Where the profiler fits

A benchmark tells you how long; a profile tells you where. Our buffer is a poor subject, since in my run its profile was dominated by runtime frames, so let's use the series demo's hashing benchmark, `BenchmarkHash_BLoop`, from the [companion repository](https://github.com/kakkoyun/gopherconuk-26/tree/fdce88cc0ce129b7d2edfb1a20d02fe647c17eeb/talks/go-benchmarks-lying/demo). We add `-cpuprofile` to the run and read it with `go tool pprof -top`, keeping three rows:

```console
$ go test -run XXX -bench BenchmarkHash_BLoop -benchmem -benchtime=2s -cpuprofile hash.prof .
$ go tool pprof -top hash.prof
      flat  flat%   sum%        cum   cum%
     1.95s 92.86% 92.86%      1.95s 92.86%  crypto/internal/fips140/sha256.blockSHA2
     0.09s  4.29% 97.14%      0.09s  4.29%  runtime.pthread_cond_signal
     0.02s  0.95% 98.10%      1.97s 93.81%  crypto/internal/fips140/sha256.block
```

The benchmark spent 92.86% of its CPU in `blockSHA2`, the SHA-256 block function, which is what a hash benchmark should be doing. If the profile of your own benchmark is dominated by `runtime` and `testing` frames instead, you may be timing the test framework.

Versions, links and commands checked on 2 October 2026.

## Try it

`b.Loop` needs Go 1.24, but the zero `allocs/op` result needs Go 1.26. On 1.24 and 1.25 the loop version shows 1 alloc/op too, which is the inlining change from earlier. Make a directory, run `go mod init tiny`, put the two benchmarks in `tiny_test.go` and run `go test -run XXX -bench . -benchmem -count=3`. Your numbers will differ from mine; on Go 1.26 or later your `allocs/op` column should not. Then add `-benchtime=1x`, `-cpu 1,4` and `-gcflags=-m` one at a time and watch which column moves.

We wrote a dozen lines of Go, got a line of output, and know where every field came from: the ramp, the mean, the sample, the suffix and the allocator. What we can't yet say is whether a given `ns/op` deserves trust. That's the question the series asks, and [part 1](/posts/go-benchmarks-lying-compiler-honesty/) starts by catching the compiler emptying a loop. 🔎
