---
title: "What a uprobe costs, and what USDT buys"
description: "One Go function, two ways to probe it: OBI's uprobes on entry and every RET, or a USDT site. What a hit costs, what OBI does for Go today, and what USDT would change."
date: 2026-07-11T00:00:00Z
publishDate: 2026-07-11T00:00:00Z
promote: false
categories:
  - engineering
tags:
  - blog
  - go
  - ebpf
  - usdt
  - observability
  - auto-instrumentation
showToc: true
tocOpen: false
---

We're going to put a probe on one small Go function, twice. First the way OBI (OpenTelemetry eBPF Instrumentation) does it today, then the way a USDT site would. On the way we'll price a single probe hit, and find that USDT's pitch is not a discount.

This is a companion to the [How to Instrument Go Without Changing a Single Line of Code](/series/how-to-instrument-go-without-changing-a-single-line-of-code/) series, between [Part 2](/posts/obi-ebpf-auto-instrumentation-go/) and [Part 3](/posts/otelc-compile-time-go-traces/). The series accompanies my [GopherCon UK talk](/talks/instrument-go-without-changing-a-single-line/). Part 2 showed what OBI sees. Here we look at how it gets its probes onto Go code, and why USDT keeps coming up. Our function is below. The `//go:noinline` keeps the compiler from folding it into `main`, so there is something left to probe.

```go
package main

import "fmt"

//go:noinline
func handle(n int) int {
	if n < 0 {
		return -1
	}
	if n == 0 {
		return 0
	}
	return len(fmt.Sprint(n))
}

func main() {
	fmt.Println(handle(42))
}
```

## One function, three exits

Let's build it for `linux/amd64` with Go 1.27.1 and ask `go tool objdump` for `main.handle`. The listing is trimmed to the lines we need (`…` marks what I cut), and the rest is byte for byte what the tool printed:

```text
TEXT main.handle(SB) ./main.go
  main.go:6		0x49a080		493b6610		CMPQ SP, 0x10(R14)
  main.go:6		0x49a084		765b			JBE 0x49a0e1
  …
  main.go:11		0x49a09c		c3			RET
  …
  main.go:13		0x49a0d2		c3			RET
  …
  main.go:8		0x49a0e0		c3			RET
  …
  main.go:6		0x49a0e6		e8b52afeff		CALL runtime.morestack_noctxt.abi0(SB)
  main.go:6		0x49a0f0		eb8e			JMP main.handle(SB)
```

The entry is `CMPQ SP, 0x10(R14)`. [R14 holds the current goroutine](https://github.com/golang/go/blob/go1.27.1/src/cmd/compile/abi-internal.md), so this compares the stack pointer with the goroutine's stack guard. If the stack is too small, `JBE` jumps to `runtime.morestack`, which grows the stack (a copy, so it moves) and restarts the function with `JMP main.handle`. The body then leaves through three `RET` instructions, one per `return` in the source.

Watching `handle` start is easy, since we know where it starts. Watching it finish is where Go makes life hard.

## Way one: an entry uprobe and a uprobe on every RET

The textbook way to catch a return is a uretprobe. The kernel rewrites the return address on the stack so the function returns into a trampoline. After poking through the uretprobe implementation in 2018, Austin Clements [wrote](https://github.com/golang/go/issues/27077#issuecomment-414460569): "It's not clear to me how the runtime (or anything that unwinds the stack) could account for this." Ian Lance Taylor had [already explained the other half](https://github.com/golang/go/issues/22008#issuecomment-331773872): Go's stacks "grow, and therefore move". A return address the kernel wrote into a stack that then moves points nowhere good.

OBI skips uretprobes. Its code comment says why: ["since go linkage is non-standard we can't use uretprobe"](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.10.0/pkg/internal/goexec/instructions.go#L97). Instead it [decodes the function's machine code with `x86asm` and records every `RET`](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.10.0/pkg/internal/goexec/instructions_amd64.go#L25-L48), then [attaches a plain uprobe at each one](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.10.0/pkg/ebpf/instrumenter.go#L644). That is v0.10.0, the release pinned for the talk and for part 2. For `handle` it means one entry probe and three return probes, found by reading disassembly. In [v0.14.0](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.14.0/pkg/ebpf/instrumenter.go#L995) the same idea is still there, now batched into one attachment.

The entry probe has its own wart. The v0.14.0 eBPF code (the talk pins v0.10.0) says that when Go grows the stack it restarts the function, [so the entry probe fires twice](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.14.0/bpf/gotracer/go_obi_ctx.h#L74-L76). That is our `JMP main.handle`, and OBI's eBPF code has to allow for it.

Then there are the arguments. Reading a struct field from a probe needs its offset, and some offsets move between Go releases. OBI keeps [a table of them](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.14.0/pkg/internal/goexec/offsets.json) and refreshes it with a [daily workflow](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.14.0/.github/workflows/update-offsets.yml). By my count it covers 59 types and 96 fields in `offsets.json` at v0.10.0 (1,510 lines), and 91 types and 183 fields at v0.14.0 (2,746 lines). One field, `net/http.http2ClientConn.fr`, sits at offset 208 in Go 1.17.0 and 368 from Go 1.26.0.

That is a lot of work to do before the first trap. What does a trap cost?

## What one hit costs

The kernel's own BPF selftests can tell us. When Jiri Olsa [added USDT rows to the uprobe benchmark](https://github.com/torvalds/linux/commit/0c4fc6bd61054a9378bce149b3758f9b6e8fb5ab), his commit message recorded one run on an x86_64 kernel. The benchmark hits a probe from a single producer thread and runs a trivial BPF counter program. The CPU is not stated. In millions of hits per second, with my 1/x in brackets:

| Probe target | M/s | Per hit |
|---|---|---|
| No probe, just the loop (`usermode-count`) | 152.507 | 6.6 ns |
| `uprobe-nop` | 3.190 | 313 ns |
| `usdt-nop` | 3.235 | 309 ns |
| `uprobe-ret`, a probe on a bare `ret` | 1.095 | 913 ns |

A USDT site is a NOP with the same trap put on it, and it costs what a uprobe on a NOP costs. The table has no row for a Go entry, which starts with `CMPQ`, not a NOP. The `ret` row is the slowest one, and I don't know whether a Go `RET` lands in that regime, because I haven't measured it.

The disabled case is not free either. PostgreSQL's docs say that with `--enable-dtrace`, probe arguments ["will be evaluated whenever control passes through the macro, even if no tracing is being done"](https://www.postgresql.org/docs/18/dynamic-trace.html). libbpf's own documentation says a USDT ["normally has zero overhead, unless it is being traced by some external entity"](https://github.com/torvalds/linux/blob/v7.2/tools/lib/bpf/usdt.c#L52-L54).

USDT is not zero overhead. If the price is the same trap, the case for it has to rest on something else.

## Way two: a named site in the body

A USDT site puts a NOP in the function body and a note in the `.note.stapsdt` ELF section. Per [libbpf's description](https://github.com/torvalds/linux/blob/v7.2/tools/lib/bpf/usdt.c#L66-L105), the note carries a provider, a name, the site's address and, per argument, a size and a location such as `-4@%edi`. Three things follow.

A tool attaches with less work. It reads the address and the argument locations from the note, and it does not disassemble anything. For `handle` that would be one site instead of an entry probe plus three `RET` probes. If the site's author computes the arguments, the tool also has no struct offsets to track. That last part is my opinion, based on what OBI carries today.

Go's moving stacks stop mattering. A site in the body is a plain uprobe, so there is no return hijack for a moving stack to break.

It can be a stable contract. The name outlives a refactor that moves the code around, and a tool asking for `net_http:server_request_start` doesn't care where the compiler put it. The caveat is that the project has to keep its probes. CPython's docs are blunt: ["No guarantees are made about probe compatibility between versions of CPython"](https://github.com/python/cpython/blob/v3.14.0/Doc/howto/instrumentation.rst#L27-L30).

Go has none of this natively today. [Part 5](/posts/go-runtime-futures-flight-recording-usdt/) covers my `poc_usdt` fork, which is an experiment. The idea I'd argue for is generic tracepoints that the standard library exposes on purpose. USDT is one way to build them, and it needs more work from me and acceptance from the Go runtime team.

Back to `handle`, then.

## Two probes, one function

With way one, `handle` gets an entry uprobe and three `RET` uprobes, found by decoding the function, plus a per-release table of struct offsets kept current by a daily job. With way two, it gets a named site, with the argument locations stated in the binary. Both cost a trap per hit. The difference is who does the work: a tool's maintainers, again for every Go release, or a runtime, once, if it accepts the idea. Neither helps with carrying trace context from an incoming request to an outgoing call. That is still unsolved.

Versions, links and commands checked on 2 October 2026.

## Try it

You can repeat the listing. Save the function above as `main.go`, then build and count the exits:

```bash
GOOS=linux GOARCH=amd64 go build -trimpath -o handle main.go
go tool objdump -s '^main.handle$' handle | grep -c RET
```

With Go 1.27.1 I get `3`. Addresses may differ on another toolchain.

One function, two ways to watch it. One asks the tool to learn every habit Go has. The other asks Go to introduce itself. 🔭
