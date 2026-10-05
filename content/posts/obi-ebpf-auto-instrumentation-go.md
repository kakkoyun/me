---
title: "OBI: eBPF auto-instrumentation for Go in production"
description: "OBI (OpenTelemetry eBPF Instrumentation) instruments Go services with no code changes, inside a defined scope. Here is that scope, what it requires and what it costs."
date: 2026-07-09T00:00:00Z
publishDate: 2026-07-09T00:00:00Z
promote: false
categories:
  - engineering
tags:
  - blog
  - go
  - observability
  - opentelemetry
  - ebpf
  - auto-instrumentation
series:
  - How to Instrument Go Without Changing a Single Line of Code
showToc: true
tocOpen: false
---

Take one HTTP request, `GET /orders/42`, headed for a Go service nobody is going to rebuild this quarter. We want a span for it, another for its database call, and the trace context handed on to the next service, all without touching the service. "Zero code changes" travels far in conference talks and vendor docs. Today we watch that one request from the kernel and find out where the phrase holds.

This is part 2 of 6 in the [How to Instrument Go Without Changing a Single Line of Code](/series/how-to-instrument-go-without-changing-a-single-line-of-code/) series, the written companion to my [GopherCon UK 2026 talk](/talks/instrument-go-without-changing-a-single-line/). [Part 1](/posts/why-go-cant-be-monkey-patched/) named three places to intervene: build time, process start and the kernel. We take the kernel route now, with OBI (OpenTelemetry eBPF Instrumentation): what it sees, what it costs, where it fits. The [FOSDEM 2026 post](/posts/fosdem-2026-auto-instrumenting-go/) has a wider first look at OBI next to the other eBPF options.

Disclosure: I work at Datadog and I'm one of otelc's maintainers; I don't contribute to OBI, so read my comparisons with that in mind.

## What OBI is

OBI is the direct successor to Grafana Beyla. Grafana Labs donated Beyla to the CNCF OpenTelemetry project in 2025, renamed it OBI, and moved its core development to the [`opentelemetry-ebpf-instrumentation`](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/tree/v0.10.0) repository. Beyla lives on as Grafana Labs' distribution of OBI.

The release pinned for the talk (13 August 2026) is [v0.10.0](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/releases/tag/v0.10.0) (2026-06-30), still in Development status. The project itself notes that breaking changes between minor releases are expected while it stays at `v0`, which is semver for "mind the gap".

How does OBI get a look at our request without being invited?

## How it works

OBI places eBPF uprobes (probes on user-space binaries) in the target binaries and kprobes (the same for kernel code) in the kernel, and the kernel JIT-compiles those eBPF programs to the host architecture (x86-64 or ARM64). For Go, OBI hooks specific library functions, not generic network traffic, which is what gives it library-level span context rather than just raw packets. A probe already sits on the `net/http` code that will serve `GET /orders/42`. A uprobe on `runtime.newproc1` records which goroutine started which, and OBI walks up to six parents to find the request.

For Go HTTP/gRPC RED metrics (rate, errors, duration), OBI attaches without source changes, recompilation, restarts, or an in-process agent. You deploy it as a DaemonSet (or a sidecar, or a host process), and spans and metrics start flowing to your OTel collector. Our service never gets a say, which is rather the point.

Being watched is one thing. What does the watcher write down?

## What it actually instruments in Go

For Go, OBI documents 13 library-level baselines as of v0.10.0. The list includes `net/http`, `golang.org/x/net/http2`, `gorilla/mux`, `gin-gonic/gin`, `google.golang.org/grpc`, `net/rpc/jsonrpc`, `database/sql` (with the `go-sql-driver/mysql` and `lib/pq` drivers), `redis/go-redis/v9`, Kafka (`segmentio/kafka-go` and `IBM/sarama`), and `go.mongodb.org/mongo-driver` v1 and v2. Full version constraints are in the [`SUPPORT_MATRIX.md`](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.10.0/SUPPORT_MATRIX.md) file in the v0.10.0 tag.

Say our service answers with `net/http`, queries MySQL through `database/sql`, and calls the next hop over gRPC. All three are on that list. Here is what "zero code changes" buys at each step:

| Step of the request | Zero code changes? |
|---|---|
| The request arrives: HTTP RED metrics | Yes |
| The handler queries the database: a library-level span | Yes |
| That span carries the SQL statement text | Yes, opt-in via `db.query.text`; bound parameters are not captured |
| The gRPC call to the next service carries the trace context (for supported protocols) | Yes, once enabled (off by default, needs extra privileges) |
| A span for "checkout", or an attribute like the customer's plan | No; requires SDK or compile-time tool |

The last row is the library-bound visibility limit of kernel-level instrumentation. The kernel sees function arguments and return values at library boundaries, and can't synthesize business context that isn't there. The Limitations section of the [official docs](https://opentelemetry.io/docs/zero-code/obi/) says so plainly:

> "Use language agents or manual instrumentation when you need custom spans, application-specific attributes, business events, or other in-process telemetry that eBPF-based instrumentation cannot derive automatically."

For business context you still need manual OTel SDK usage or a compile-time tool like [otelc](/posts/otelc-compile-time-go-traces/). The view is good. What does it charge for the ticket?

## What it requires

The "zero changes to your application" claim moves the bill from the app team to the node. (The docs pages I link are unversioned; I read them on 2026-10-02.)

The kernel comes first: the [docs](https://opentelemetry.io/docs/zero-code/obi/) ask for Linux 5.8+, with a RHEL exception of 4.18+ for RHEL 8-family distros with the required eBPF backports. It must also expose BTF (BPF Type Format) information. Most current mainstream distros ship with it; check that `/sys/kernel/btf/vmlinux` exists. On macOS, eBPF is a Linux party, so bring a VM; [See it run: OBI and the eBPF profiler without Kubernetes](/posts/go-instrumentation-see-it-run/) does exactly that.

Then the capabilities. OBI has no single capability set, because the required access grows with the features you turn on. For plain application observability it needs six Linux capabilities when it runs unprivileged: `CAP_BPF`, `CAP_SYS_PTRACE`, `CAP_NET_RAW`, `CAP_CHECKPOINT_RESTORE`, `CAP_DAC_READ_SEARCH` and `CAP_PERFMON` (plus `CAP_SYS_RESOURCE` on kernels before 5.11, which the 5.8 floor still allows). The [security page](https://opentelemetry.io/docs/zero-code/obi/security/) explains why each one is needed and has the per-feature breakdown.

More features need more capabilities. `CAP_NET_ADMIN` is added when context propagation is enabled, which is off by default: a socket-level eBPF program then adds a `traceparent` header to outgoing HTTP. `CAP_SYS_ADMIN` is required for Go library-level propagation, where a uprobe writes the header into Go's own request buffer with `bpf_probe_write_user`, and it stands in for `CAP_PERFMON` when `kernel.perf_event_paranoid` is set high (the AKS and EKS defaults need it). Running with `privileged: true` in Kubernetes works, but it's the sledgehammer option. Security teams will scrutinize this list, and that review is the operational cost to factor in.

On [Kubernetes](https://opentelemetry.io/docs/zero-code/obi/setup/kubernetes/), the preferred model for covering many services is a DaemonSet: one OBI pod per node, with `hostPID: true` so it can see every process and no changes to application pods. The sidecar model (one OBI container per pod, with `shareProcessNamespace: true` and `privileged: true`) gives finer control at the cost of efficiency at scale. I would start with the DaemonSet: deploy once, and every service on every node, ours included, gets baseline observability.

What does it cost while running? I have no measurements of OBI v0.10.0 itself; the [FOSDEM post](/posts/fosdem-2026-auto-instrumenting-go/)'s benchmark is one demo workload. Every hit on an attached uprobe traps into the kernel, so a hot function pays per call ([What a uprobe costs, and what USDT buys](/posts/go-uprobe-vs-usdt/) takes that cost apart). The kernel's own BPF selftests recorded about 313 ns per hit on an uprobe over a NOP (3.190 M/s, one x86_64 run, CPU not stated, [commit 0c4fc6bd6105](https://github.com/torvalds/linux/commit/0c4fc6bd61054a9378bce149b3758f9b6e8fb5ab)); a [2023 bpftime paper](https://arxiv.org/pdf/2311.07923) measured 3,224 ns on older, unstated hardware. The two sources differ tenfold, and I haven't measured OBI's. I'm measuring it, with a reproduction kit, for a follow-up post. The rest is upkeep. OBI looks up Go struct-field offsets by Go and library version (`offsets.json`), and Go 1.26 removing `pcHeader.textStart` broke its symbol resolution in PIE and cgo binaries until [PR #1851](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/pull/1851).

Is that enough, or just a start?

## Where it fits

Back to `GET /orders/42`. With nobody touching the service, we got RED metrics for the request, library-level spans for its database and gRPC calls, and, with the right opt-ins and privileges, SQL text and trace context across services. We did not get what the on-call engineer asks first: which customer, which cart, which business step.

That split shows where OBI fits: baseline observability across services you don't own or can't rebuild right now. Ship the DaemonSet, then decide which services deserve more.

OBI and compile-time tools are complementary. OBI gives breadth without touching CI pipelines. Compile-time tools like otelc give depth (custom spans, business logic, stdlib instrumentation) at the price of a rebuild and, for otelc, Go 1.25+. [Part 6](/posts/zero-touch-go-observability-agent-actionable/) turns the choice into a decision rule.

The caveat worth repeating: the feature set is real, since OBI is the same codebase as Beyla, which reached 1.0 in November 2023. The API stability guarantees, though, are explicitly not there yet, and the [v0.10.0 release notes](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/releases/tag/v0.10.0) carry a long security-hardening section. Budget for minor release changes, and canary before a fleet-wide rollout.

"Zero code changes", then? For our request: yes, inside a defined scope, with a defined price list.

Versions, links and commands checked on 2 October 2026.

## Up next

[Part 3, otelc: zero-touch Go traces at compile time](/posts/otelc-compile-time-go-traces/), moves the intervention to build time. The service gets rebuilt; in exchange, we get depth. Same promise, new vantage point. 👀
