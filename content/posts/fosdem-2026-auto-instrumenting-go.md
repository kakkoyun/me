---
title: "Auto-Instrumenting Go: From eBPF to USDT Probes"
description: "A deep dive into approaches for instrumenting Go applications without changing source code — comparing compile-time, eBPF, runtime injection, and USDT methods with benchmarks."
date: 2026-02-27T00:00:00Z
publishDate: 2026-02-27T00:00:00Z
categories:
  - engineering
tags:
  - blog
  - go
  - opentelemetry
  - auto-instrumentation
  - ebpf
  - observability
  - usdt
  - compile-time-instrumentation
cover:
  image: /uploads/fosdem26_go_talk.jpeg
  alt: Auto-Instrumenting Go
  caption: FOSDEM 2026 — Go Devroom
---

This post expands on the [FOSDEM 2026 Go Devroom talk](/talks/how-to-instrument-go-without-changing-code/) I co-presented with [Hannah S. Kim](https://hannahkm.github.io). The talk, demo code, and all benchmark scenarios are available in the [fosdem-2026 repository](https://github.com/kakkoyun/fosdem-2026).

---

### The Problem

Go is one of the best languages for building production backend services. It compiles to native binaries, has excellent concurrency primitives, and produces predictable performance characteristics. But when it comes to auto-instrumentation — adding observability without modifying source code — Go is uniquely difficult.

In the JVM world, bytecode manipulation gives you powerful hooks. Java agents can intercept method calls, inject tracing, and propagate context without the application developer knowing. Python and Node.js have similar dynamic capabilities. Go has none of this.

The reasons are structural:

- **Static compilation.** Go compiles to a single native binary. There is no intermediate bytecode to rewrite at load time, no classloader to intercept, no dynamic linking by default.
- **No `LD_PRELOAD`.** Go's default static linking means the `LD_PRELOAD` trick that works for C/C++ applications (and that the [OTel Injector](https://github.com/open-telemetry/opentelemetry-injector) uses for Java, .NET, and Node.js) doesn't apply.
- **Unique calling convention.** Go's ABI passes arguments in registers with a convention different from the platform C ABI. This makes dynamic hooking with tools like Frida or ptrace significantly harder — you can't just read standard frame pointers.
- **Goroutine stack management.** Goroutines use segmented, growable stacks that the runtime can move at any time. Traditional stack-walking assumptions break.

The gap between "Go is great for production" and "Go is hard to auto-instrument" is real. This is the gap we set out to map.

---

### The Comparison Framework

We built a [demo repository](https://github.com/kakkoyun/fosdem-2026) with the same Go HTTP server implemented across seven scenarios, each using a different instrumentation approach. The application is deliberately simple — an HTTP server with configurable CPU load, memory allocation, and off-CPU time — so that instrumentation overhead is isolated and measurable.

#### The Seven Scenarios

| # | Scenario | Approach | What It Does |
|---|----------|----------|-------------|
| 1 | `default` | None | Baseline. No instrumentation of any kind. |
| 2 | `manual` | OTel SDK | Manual OpenTelemetry SDK integration — explicit tracer initialization, span creation via `otelhttp`, and context propagation. The "standard" way. |
| 3 | `obi` | eBPF (OBI) | [OpenTelemetry eBPF Instrumentation](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation). Network-level eBPF hooks. Runs as a sidecar, attaches to the running process. No code changes. |
| 4 | `ebpf` | eBPF (Auto) | [OpenTelemetry Go Auto-Instrumentation](https://github.com/open-telemetry/opentelemetry-go-instrumentation). Uprobe-based eBPF hooks targeting Go runtime functions. No code changes. |
| 5 | `orchestrion` | Compile-time | [Datadog Orchestrion](https://github.com/datadog/orchestrion) with OTel SDK. AST transformation via `-toolexec` at compile time. Requires a rebuild but no source changes. |
| 6 | `libstabst` | USDT (salp) | USDT probes via [salp](https://github.com/mmcshane/salp)/[libstapsdt](https://github.com/sthima/libstapsdt), consumed by a bpftrace sidecar that exports to OTLP. Proof of concept. |
| 7 | `usdt` | USDT (native) | Native USDT probes via a [custom Go fork](https://github.com/kakkoyun/go/tree/poc_usdt) that adds probe points to `net/http`, `database/sql`, `crypto/tls`, and `net`. Proof of concept. |

Each scenario runs in Docker with an identical observability stack (OTel Collector, Jaeger, Prometheus) and is load-tested with identical parameters.

#### Evaluation Axes

We compared the approaches across three dimensions:

- **Performance overhead** — latency, CPU, memory (RSS), throughput
- **Robustness** — stability across Go versions, container environments, failure modes
- **Operational friction** — deployment complexity, privilege requirements, debugging

---

### Manual OTel SDK (Baseline for Comparison)

The manual scenario is not auto-instrumentation — it is the standard way to instrument a Go service. You import the OTel SDK, initialize a tracer provider, wrap your HTTP handler with `otelhttp.NewHandler`, and create spans explicitly.

```go
func setupHandlers(inputs *Input) http.Handler {
    mux := http.NewServeMux()
    mux.HandleFunc("/health", HealthHandler)
    mux.HandleFunc("/load", inputs.LoadHandler)
    return otelhttp.NewHandler(mux, "")
}

func (c *Input) LoadHandler(w http.ResponseWriter, r *http.Request) {
    tracer := otel.Tracer("manual")
    _, span := tracer.Start(r.Context(), "manual.handler")
    defer span.End()
    // ... business logic
}
```

This gives you full control — custom span attributes, context propagation, error recording. But it requires code changes in every service, and those changes accumulate. Multiply by a hundred microservices and you understand why auto-instrumentation matters.

---

### Compile-Time: Orchestrion and OTel Compile-Time Instrumentation

Orchestrion uses Go's `-toolexec` flag to intercept the compilation pipeline. During the AST transformation phase, it injects instrumentation code — adding OTel spans, wrapping handlers, propagating context — without the developer modifying source files.

```bash
go build -toolexec 'orchestrion toolexec' -o myapp .
# Or equivalently:
orchestrion go build -o myapp .
```

The mechanism is aspect-oriented: you declare join points (e.g., "any function in package `main` named `LoadHandler`") and advice (e.g., "prepend a span creation statement"). The transformation happens at the AST level before the compiler emits machine code.

Orchestrion supports OpenTelemetry natively — it is not Datadog-specific. In January 2025, Datadog and Alibaba began merging their compile-time instrumentation efforts into a unified solution under the [OpenTelemetry Compile-Time Instrumentation SIG](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation).

**Trade-offs:**
- Requires a rebuild. You cannot instrument already-deployed binaries.
- Deepest instrumentation of all approaches — it can instrument stdlib and dependencies.
- Zero runtime overhead from the instrumentation mechanism itself (the injected OTel code has the same cost as manual instrumentation).
- Stable across Go versions (the toolexec interface is stable).
- No kernel privileges required.

For a deeper dive into the `-toolexec` mechanism, see my earlier [Unleashing the Go Toolchain](/talks/unleashing-the-go-toolchain/) talk from GopherCon UK 2025.

---

### eBPF Approaches

#### OBI (OpenTelemetry eBPF Instrumentation)

[OBI](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation) takes a network-level approach. It uses eBPF programs to hook into kernel-level network operations, intercepting HTTP/S and gRPC traffic. It is multi-language — Go, Java, .NET, Python, Node.js, Ruby, Rust — because it operates at the protocol layer rather than the language runtime layer.

```bash
docker run --privileged \
  --pid=container:myapp \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4318 \
  otel/ebpf-instrumentation:latest
```

OBI runs as a sidecar container. It attaches to the target process's PID namespace and loads eBPF programs that intercept network system calls. No source code modification, no recompilation, no restart.

**Trade-offs:**
- Requires `CAP_SYS_ADMIN` or privileged containers. Security teams push back on this.
- Limited to what eBPF can observe at the network level. Application-internal spans are not visible.
- Protocol coverage is growing: HTTP/S, gRPC, TLS visibility.
- Excellent for topology mapping and network observability beyond just tracing.

#### OTel Go Auto-Instrumentation

The [OpenTelemetry Go Auto-Instrumentation](https://github.com/open-telemetry/opentelemetry-go-instrumentation) project uses uprobe-based eBPF hooks that target specific Go runtime functions. Unlike OBI's network-level approach, this hooks directly into Go function prologues.

This project is effectively in maintenance mode. Several of its contributors have moved to OBI. At [OTel Unplugged EU 2026](/posts/otel-unplugged-eu-2026/), the frank assessment was: the people moved to where the momentum is.

---

### Runtime Injection: Frida and ptrace

The `injector` scenario explores dynamic instrumentation via [Frida](https://frida.re/), a ptrace-based toolkit for runtime function hooking. The idea is conceptually simple: attach to a running process, find the function you want to hook, and replace its prologue with a trampoline that calls your instrumentation code.

```go
// The application code uses //go:noinline to keep functions hookable.
//go:noinline
func (c *Input) LoadHandler(w http.ResponseWriter, _ *http.Request) {
    // ... business logic
}
```

In practice, this is extremely hard for Go binaries. [Quarkslab's excellent three-part series](https://blog.quarkslab.com/lets-go-into-the-rabbit-hole-part-1-the-challenges-of-dynamically-hooking-golang-program.html) documents the challenges in detail: Go's register-based calling convention, goroutine stack relocation, and compiler optimizations (inlining, dead code elimination) all conspire against reliable dynamic hooking.

The demo's injector scenario includes a helper tool that uses `unsafe.Offsetof` to find `http.Request` struct field offsets — information you need just to read the HTTP method and path from a hooked function's arguments.

**Trade-offs:**
- Works with existing binaries. No rebuild required.
- Requires `-gcflags="all=-N -l"` to disable optimizations, which defeats the purpose for production.
- Fragile across Go versions — struct layouts and calling conventions change.
- Limited applicability for Go's statically linked binaries.

For Go, this approach is more useful as a debugging tool than a production instrumentation strategy.

---

### USDT Probes: The Novel Part

USDT (User Statically-Defined Tracing) probes are a mechanism from the DTrace/SystemTap ecosystem. They are marker points compiled into a binary that external tooling (bpftrace, perf, DTrace) can attach to at runtime. The key property: **when no consumer is attached, the probe site is a NOP instruction with zero overhead.**

We built two proof-of-concept implementations.

#### libstabst: USDT via salp and bpftrace

The `libstabst` scenario uses [salp](https://github.com/mmcshane/salp), a Go binding to [libstapsdt](https://github.com/sthima/libstapsdt), to create USDT probes at runtime. The application defines probe points for request start and end:

```go
probes = salp.NewProvider("fosdem")
reqStart, _ = probes.AddProbe("request_start", salp.String, salp.Int64)
reqEnd, _ = probes.AddProbe("request_end", salp.String, salp.Int64, salp.Int64)
probes.Load()

// In the handler:
if reqStart != nil && reqStart.Enabled() {
    reqStart.Fire(reqID, startTime)
}
```

A bpftrace sidecar attaches to these probes and exports events as OTLP traces via a custom exporter bridge.

**Known limitations:** The salp library has compatibility issues with Go 1.25+, pinning this scenario to Go 1.23.x. It also needs `/proc/self/fd/` access for mmap, which fails in many container environments. On bare metal Linux or in a Lima VM, it works.

![Presenting the USDT + eBPF proof of concept at the Go Devroom](/uploads/fosdem26_go_usdt.png)

#### Native USDT: Custom Go Fork

The more ambitious PoC is a [custom Go fork](https://github.com/kakkoyun/go/tree/poc_usdt) that adds USDT probe points directly to the Go standard library — `net/http`, `database/sql`, `crypto/tls`, and `net`.

```go
import "runtime/trace/usdt"

func handleRequest(w http.ResponseWriter, r *http.Request) {
    usdt.Probe("myapp", "request_start")
    defer usdt.Probe1("myapp", "request_end", int32(w.StatusCode))
    // ... handle request
}
```

The fork includes a `go tool usdt` command for listing probes in a binary and generating bpftrace scripts:

```bash
$ go tool usdt list ./myserver
PROVIDER   NAME                  ADDRESS     ARGUMENTS
net_http   server_request_start  0x63296c    8@%rsi -8@%r8

$ go tool usdt bpftrace ./myserver > trace.bt
$ sudo bpftrace trace.bt
```

This PoC proves that native USDT support in Go is technically feasible. The standard library instrumentation is automatically available in any binary built with the fork — no application code changes, no SDK imports.

**Known limitations:** ARM64 argument parsing in bpftrace has issues with the probe argument notation emitted by the fork. The fork is strictly a proof of concept and not suitable for production.

---

### Go Runtime PoCs: Flight Recording

Beyond USDT, we explored a [flight recorder PoC](https://github.com/kakkoyun/go/tree/poc_flight_recorder) based on [golang/go#63185](https://github.com/golang/go/issues/63185). The concept: always-on distributed tracing built into the Go runtime, with a bounded ring buffer and GODEBUG-based activation.

```go
import "runtime/trace/flight"

flight.Enable(flight.HTTP | flight.SQL | flight.Net)
defer flight.Flush()  // Export on error or crash
```

The flight recorder PoC watches for trace files produced by the runtime, converts them to OTLP spans, and exports to a collector. If Go's runtime trace facilities eventually gain W3C Trace Context propagation, this could become the lowest-friction instrumentation path for Go — no SDK, no eBPF, no compile-time tools. Just the runtime doing what runtimes should do.

---

### Benchmark Results

We ran each scenario under identical load conditions using a Docker-based observability stack with 5-minute sustained load tests.

| Approach | CPU | Memory (RSS) | Max Latency | Max Throughput |
|----------|-----|-------------|-------------|----------------|
| Baseline (no instrumentation) | 10.2% | 202 MiB | 4.50 ms | 3.1k req/sec |
| Manual OTel SDK | 10.3% (+0.1%) | 210 MiB (+8 MiB) | 3.02 ms | 13.97k req/sec |
| eBPF Auto-Instrumentation | 10.0% (-0.3%) | 204 MiB (+2 MiB) | 3.07 ms | 4.57k req/sec |
| Compile-time (Orchestrion) | 9.8% (-0.4%) | 210 MiB (+8 MiB) | 2.59 ms | 27.8k req/sec |

A few things stand out. The CPU and memory overhead across all approaches is negligible for this workload. The throughput differences are more interesting — Orchestrion's compile-time approach achieved the highest throughput, likely because the OTel code injected at compile time benefits from the same optimizations as the rest of the application. The eBPF approach showed lower throughput, consistent with the overhead of crossing the kernel boundary for each intercepted call.

The USDT scenarios (`libstabst` and `usdt`) are not included in the table because they are proof-of-concept implementations with different exporter architectures. The core property of USDT — zero overhead when probes are not attached — was confirmed, but end-to-end benchmarking against the other approaches requires further work.

Full benchmark data and reproduction instructions are in the [demo repository](https://github.com/kakkoyun/fosdem-2026).

---

### The Ecosystem Picture

The most grounded take from the [OTel Unplugged EU 2026](/posts/otel-unplugged-eu-2026/) OBI/eBPF session:

> "Document the trade-offs between OBI, compile-time, injector, and SDK. Let people choose. Make them aware of each other and let them work together."

These approaches are not competing. They serve different deployment scenarios and can coexist.

| Approach | Mechanism | Best For | Limitation |
|----------|-----------|----------|------------|
| **Compile-time** (Orchestrion) | AST transformation via `-toolexec` | Deepest instrumentation, security-sensitive environments | Requires rebuild |
| **eBPF/OBI** | Kernel-level network hooks | Runtime flexibility, multi-language, no restart | Needs kernel privileges |
| **eBPF Auto** | Uprobe hooks on Go functions | Go-specific deep tracing without code changes | Maintenance mode, fragile across Go versions |
| **Injector/SSI** | K8s operator + `LD_PRELOAD` | Lowest friction onboarding | Does not work for Go's static binaries |
| **USDT** | Compiled probe points + bpftrace | Zero overhead when not tracing, future potential | Proof of concept, ecosystem immaturity |

The vision articulated at OTel Unplugged — `apt install opentelemetry` and everything works — requires all these layers coordinating. OBI detecting the Injector and backing off. Compile-time instrumentation detecting existing SDK usage. USDT probes coexisting with eBPF hooks. We are not there yet, but the direction is clear.

---

### Future Directions

Several threads from the talk and surrounding conversations point forward:

- **OTel Compile-Time SIG.** The merger between Datadog's Orchestrion and Alibaba's compile-time instrumentation under the OpenTelemetry umbrella is the most significant near-term development. A vendor-neutral, community-maintained compile-time instrumentation tool for Go would change the adoption curve.

- **W3C context propagation in runtimes.** If language runtimes and compilers understand trace context natively, the instrumentation story simplifies fundamentally. This was a recurring theme at OTel Unplugged.

- **eBPF Tokens.** [BPF Tokens](https://fosdem.org/2026/schedule/event/3LLHG9-bpf-tokens-safe-userspace-ebpf/) could significantly reduce the privilege requirements for eBPF-based instrumentation. Instead of `CAP_SYS_ADMIN`, a token-based trust model would lower the bar for security teams.

- **Native USDT in Go.** The PoC fork demonstrates feasibility. Whether the Go team would accept USDT probes into the standard library is an open question, but the pattern exists in other ecosystems — Postgres, MySQL, and the JVM all have static tracepoints behind flags.

- **Flight recording.** The `golang/go#63185` proposal for always-on flight recording in the Go runtime could eventually provide the foundation for zero-touch distributed tracing without any external tooling.

---

### Closing

The instrumentation tax is real and unavoidable. The question is not whether to pay it, but how to manage it. For Go, the answer is increasingly "you have options" — and those options are getting better.

The slides are available as [PDF](https://github.com/kakkoyun/fosdem-2026/blob/main/presentation.pdf) and [Markdown](https://github.com/kakkoyun/fosdem-2026/blob/main/presentation.md). The demo code, Docker setup, and benchmark scripts are all in the [fosdem-2026 repository](https://github.com/kakkoyun/fosdem-2026). The [recording is on YouTube](https://www.youtube.com/watch?v=0TvrSebuDPk).

If you want to get involved: the [OTel Compile-Time Instrumentation SIG](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation), [OBI](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation), and [OTel Go](https://github.com/open-telemetry/opentelemetry-go) repositories all accept contributions. The `#otel-go` and `#otel-ebpf-sig` channels on [CNCF Slack](https://slack.cncf.io/) are where the discussions happen.

See also: [OTel Unplugged EU 2026 field notes](/posts/otel-unplugged-eu-2026/) for the broader ecosystem context.
