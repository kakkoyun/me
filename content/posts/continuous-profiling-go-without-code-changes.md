---
title: "The fourth signal: continuous profiling without code changes"
description: "Stripped Go binaries still carry enough runtime metadata for eBPF profiling. Here is why, and where OpenTelemetry's profiles signal fits in a zero-touch stack."
date: 2026-07-23T00:00:00Z
publishDate: 2026-07-23T00:00:00Z
promote: false
categories:
  - engineering
tags:
  - blog
  - go
  - observability
  - opentelemetry
  - ebpf
  - profiling
  - auto-instrumentation
series:
  - How to Instrument Go Without Changing a Single Line of Code
showToc: true
tocOpen: false
---

Many tools that profile Go binaries resolve function names from the ELF symbol table or DWARF debug info, and production builds strip both. Point one of those profilers at a stripped binary and you get addresses, not names. The `opentelemetry-ebpf-profiler` doesn't have this problem, and we're going to find out why.

Let's start with a binary rather than a profiler. Here is the whole program, with `//go:noinline` so the compiler can't fold `checkout` into `main`:

```go
package main

import "fmt"

//go:noinline
func checkout(n int) int { return n * 2 }

func main() { fmt.Println(checkout(21)) }
```

We'll build it for Linux, strip it at link time, and ask what's left:

```console
$ GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags='-s -w' -o stripped .
$ go tool nm stripped
reading stripped: no symbol section
reading stripped: no symbols
$ llvm-readelf -S stripped | grep -E 'symtab|debug|gopclntab'
  [ 5] .gopclntab        PROGBITS        00000000000bbf28 0abf28 097cf1 00   A  0   0  8
$ strings stripped | grep -E '^main\.'
main.checkout
main.main
```

One build, one machine: Go 1.27.1 on macOS, cross-compiling for linux/arm64. The symbol table and every `.debug_*` section are gone (plain `readelf -S` works too if `llvm-readelf` isn't on your PATH), yet `.gopclntab` is still there and `strings` can read our function names out of the file. We'll keep pulling on that: a stripped binary that still knows its function names, and a profiler that knows whom to ask.

This is part 4 of 6 in the [How to Instrument Go Without Changing a Single Line of Code](/series/how-to-instrument-go-without-changing-a-single-line-of-code/) series, the written companion to my [GopherCon UK 2026 talk](/talks/instrument-go-without-changing-a-single-line/). [Part 3](/posts/otelc-compile-time-go-traces/) moved the intervention to build time. Now we go back to the kernel for profiles, the fourth OpenTelemetry signal after traces, metrics and logs. Disclosure: I work at Datadog and I'm one of otelc's maintainers, so read my comparisons with that in mind.

## .gopclntab: the debug info Go can't remove

Why did `.gopclntab` survive? Because the Go runtime can't live without it. The runtime needs to walk the call stack at any time, for panics, for the garbage collector, for goroutine dumps, and it does that with this program-counter-to-line-number table. It maps raw instruction addresses to function names, file names and line numbers, and since the runtime always needs it, `strip` leaves it alone.

The profiler's docs make the same point: the [data stays present even in static, stripped executables](https://github.com/open-telemetry/opentelemetry-ebpf-profiler/blob/v0.0.202633/doc/gopclntab.md), which is what lets it symbolize and unwind production executables.

A stripped Go binary can be read from the outside, then. Who does the reading?

## What the profiler actually is

The reader is the [`opentelemetry-ebpf-profiler`](https://github.com/open-telemetry/opentelemetry-ebpf-profiler/tree/v0.0.202633). It started as the Elastic Universal Profiling Agent. Elastic [proposed the donation](https://github.com/open-telemetry/community/issues/1918) in January 2024, and OpenTelemetry [approved it](https://github.com/open-telemetry/community/issues/1918#issuecomment-2153125431) that June. Run the official Collector distribution, `otelcol-ebpf-profiler` (started with `--feature-gates=+service.profilesSupport`), from `opentelemetry-collector-releases`, not the same-named test binary in the repo's own `cmd/` directory, which is for internal use only. The latest tag as of the talk (13 August 2026) is `v0.0.202633` (which reads as ISO week 33 of 2026). The project publishes tags, not GitHub Releases.

An eBPF program fires on CPU sample events in the kernel and reads process-internal data structures from outside the target process. No `LD_PRELOAD`, no ptrace attach, and no injector ([part 1](/posts/why-go-cant-be-monkey-patched/#process-start-the-injector) covers why that last one is hard for Go). The README states it plainly: ["100% non-intrusive: there's no need to load agents or libraries into the processes that are being profiled."](https://github.com/open-telemetry/opentelemetry-ebpf-profiler/blob/v0.0.202633/README.md) Our `stripped` binary would never know anyone had read it. You typically run it as a DaemonSet with `hostPID: true`.

Why not `net/http/pprof`? It needs a blank import and a redeploy to switch on, which is the change this series avoids. In my view it still has the edge on profile types and detail, and it needs no kernel privileges.

Nothing gets loaded into the application. The fine print is on the node.

## What "zero code changes" actually means

The profiled applications need nothing: no rebuild, no restart, no SDK import. The node pays instead.

The [example config](https://github.com/open-telemetry/opentelemetry-ebpf-profiler/blob/v0.0.202633/cmd/otelcol-ebpf-profiler/local.example.yaml) says to run the Collector as root, or to grant specific capabilities (it names `CAP_SYS_ADMIN`, `CAP_PERFMON`, and/or `CAP_BPF`, plus access to `/proc`). The [README](https://github.com/open-telemetry/opentelemetry-ebpf-profiler/blob/v0.0.202633/README.md) also says current code may require Linux 5.10 or greater.

The bill arrives per node, not per service, which is what makes it useful at scale. You still need a backend that takes OTLP profiles, and the README says mature production-ready ones have yet to emerge (Pyroscope and devfiler are its open-source options, and devfiler is Elastic's desktop viewer for experiments, not a production backend).

A privileged agent on every node buys us CPU profiles. How far can we trust the signal?

## How mature is it?

Young. These are the statuses as of October 2026, from the [profiles concepts page](https://opentelemetry.io/docs/concepts/signals/profiles/) and the [specification](https://opentelemetry.io/docs/specs/otel/profiles/) (spec v1.61.0, OTLP 1.11.0):

| Layer | Status |
| ------- | -------- |
| OTel specification (`/docs/specs/otel/profiles/`) | **Alpha** |
| OTLP wire format (OTLP 1.11.0) | **Development** |
| Collector receiver (`ebpf-profiler`) | **Development** |
| Collector feature gate `service.profilesSupport` | **Alpha** (off by default, enable it explicitly) |
| Traces / Metrics / Logs (for comparison) | Stable / Stable / Stable |

The last row is the only one with a comfortable word in it.

The README is explicit: "Implements the Alpha OTel Profiles signal." It calls its own implementation "functional but work-in-progress / evolving", and Alpha means evolving, not backward-compatibility-guaranteed.

What works today, reliably, is on-CPU stacks sampled per OS thread, with correct Go function names via `.gopclntab`, the trick we started with. It also [reads Go pprof labels](https://github.com/open-telemetry/opentelemetry-ebpf-profiler/blob/v0.0.202633/support/ebpf/go_labels.ebpf.c) by following the thread's current `g` to its goroutine, so samples carry whatever labels the application set. The README also lists Java, Python and other runtimes it can unwind, though I only checked the Go path. [Off-CPU profiling](https://github.com/open-telemetry/opentelemetry-ebpf-profiler/blob/v0.0.202633/design-docs/00001-off-cpu-profiling/README.md) is in development and [allocation profiling](https://github.com/open-telemetry/opentelemetry-ebpf-profiler/blob/v0.0.202633/design-docs/00003-memory-profiling/README.md) is a design proposal.

Alpha, then, with a working core: always-on CPU flame graphs for production Go services. Where does that sit next to the tools from the last two parts?

## Where the fourth signal fits

[OBI](/posts/obi-ebpf-auto-instrumentation-go/) gives us traces and RED metrics for HTTP and gRPC from the kernel, [otelc](/posts/otelc-compile-time-go-traces/) gives us function-level spans for the price of a rebuild, and the profiler adds always-on CPU profiles for the whole node. Together they cover three of the four signals (traces, metrics, profiles) without a single source change in the application. Logs are only partly covered: [OBI can add trace context to application logs](https://opentelemetry.io/docs/zero-code/obi/trace-log-correlation/) (Linux 6.0 or newer), but it enriches them and does not export them.

The useful move is to jump from a slow trace to the flame graph for the same time window: traces tell you a request was slow, profiles tell you where the CPU went. Lining them up by request is where zero-touch has a gap. The data model lets samples carry trace and span IDs, but for Go the profiler can only read request context from pprof labels that the application sets, the path [OTEP 4947](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.61.0/oteps/profiles/4947-thread-ctx.md#alternative-for-go-support) describes. A compile-time tool could set span-ID labels for the profiler to read, but that is proposed work, and I haven't verified that otelc or dd-trace-go do it. Zero-touch profiling alone correlates by resource and time window, not by request, so treat trace-to-profile pivoting as where this is heading.

Back to our stripped binary. We never rebuilt it, restarted it or added an import, and it still carries `main.checkout` in `.gopclntab` for `strings` or a privileged profiler to read. The signal is Alpha, but Elastic [ran the same agent in customer production](https://github.com/open-telemetry/community/issues/1918) before donating it, so the capability is real: continuous CPU profiling with correct symbolization of stripped Go binaries. The commands at the top of this post check that any Go binary you ship still has its names; running the profiler itself takes a Linux host and the Collector command in its README, and [See it run: OBI and the eBPF profiler without Kubernetes](/posts/go-instrumentation-see-it-run/) does that in a VM. Try the check on yours, then go see where your CPU time goes. 🔍

Versions, links and commands checked on 2 October 2026.

## Up next

[Part 5, Go runtime futures: flight recording, USDT, and the instrumentation hook problem](/posts/go-runtime-futures-flight-recording-usdt/), looks at what Go itself could add: flight recording, which shipped, and the hooks that are still missing. Three tools have worked around Go so far. Time to ask Go for help.
