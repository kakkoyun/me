---
title: "OBI: eBPF auto-instrumentation for Go in production"
description: "OBI (OpenTelemetry eBPF Instrumentation) instruments Go services with zero code changes inside a specific, well-defined scope. Here is what that scope is and what it costs."
date: 2026-09-08T00:00:00Z
publishDate: 2026-09-08T00:00:00Z
draft: true
categories:
  - engineering
tags:
  - blog
  - go
  - observability
  - opentelemetry
  - ebpf
series: "How to Instrument Go Without Changing a Single Line of Code"
showToc: true
tocOpen: false
---

"Zero code changes" is a phrase that travels far in conference talks and vendor docs. It needs a precise definition before it's useful. OBI (OpenTelemetry eBPF Instrumentation) delivers on the promise within a specific scope and with specific requirements. Understanding both is the point.

## What OBI is

OBI is the direct successor to Grafana Beyla. Grafana Labs donated Beyla to the CNCF OpenTelemetry project in 2025, renamed it OBI, and moved all active development there. The current release is **v0.10.0 (2026-06-30)**, still in Development status. The project itself notes that breaking changes between minor releases are expected while it stays at `v0`.

Grafana Beyla continues to exist as Grafana Labs' distribution of the upstream OBI project. If you're using Beyla today, you're running a downstream of OBI.

The GitHub repo is `open-telemetry/opentelemetry-ebpf-instrumentation`. Go module: `go.opentelemetry.io/obi`. Apache-2.0.

## How it works

OBI places eBPF uprobes and kprobes at the kernel level. The eBPF programs are JIT-compiled by the Linux kernel to the host architecture (x86-64 or ARM64). For the Go case, OBI hooks into specific library functions, not generic network traffic, which is what gives it library-level span context rather than just raw packets.

For standard HTTP/gRPC RED metrics, OBI attaches without source changes, recompilation, restarts, or an in-process agent.

You deploy OBI as a DaemonSet (or sidecar), it attaches to the target processes, and spans and metrics start flowing to your OTel collector.

The official docs are explicit about the boundary:

> "Use language agents or manual instrumentation when you need custom spans, application-specific attributes, business events, or other in-process telemetry."

The SDK cost shows up where OBI cannot infer business context. OBI cannot generate a span for a specific business transaction, annotate a span with a database query string, or instrument logic that doesn't correspond to a known library call. For those, you still need either manual OTel SDK usage or a compile-time tool like otelc. OBI's value is in the cases where you want standard RED observability across all services on a node without coordinating with every application team.

## What it actually instruments in Go

OBI provides Go-specific library-level uprobe instrumentation (distinct from just intercepting network traffic) for 13 named libraries as of v0.10.0. The list includes `net/http`, `golang.org/x/net/http2`, `gorilla/mux`, `gin-gonic/gin`, `google.golang.org/grpc`, `go-redis/redis` v8/v9, Kafka (sarama and confluent-kafka-go), and `database/sql`. Full version constraints are in the `SUPPORT_MATRIX.md` file in the v0.10.0 tag.

The precise scope of "zero code changes" for Go:

| Scenario | Zero code changes? |
|---|---|
| HTTP/gRPC RED metrics | Yes |
| Library-level spans for the 13 supported libraries | Yes |
| Trace context propagation across services (for supported protocols) | Yes |
| Custom spans or business-logic events | No; requires SDK or compile-time tool |
| SQL query details or parameters | No; requires SDK or compile-time tool |

That is the library-bound visibility limit for production-safe, kernel-level instrumentation. The kernel can see function arguments and return values at library boundaries; it can't synthesize business context that doesn't exist at that level.

## What it requires

The "zero changes to your application" claim comes with requirements on the infrastructure side.

**Kernel version:** Linux 5.8+. There's a RHEL exception: 4.18+ for RHEL 8-family distros with the required eBPF backports. BTF (BPF Type Format) must be enabled; this has been the default on most distros since kernel 5.14.

If you're running macOS development environments, OBI requires Linux. You'll need a Linux VM or actual Linux nodes to test it.

**Capabilities:** OBI requires six Linux capabilities in unprivileged mode:

| Capability | Why |
|---|---|
| `CAP_BPF` | Core eBPF program loading |
| `CAP_SYS_PTRACE` | Process inspection |
| `CAP_NET_RAW` | Network-level probing |
| `CAP_CHECKPOINT_RESTORE` | Process state access |
| `CAP_DAC_READ_SEARCH` | Reading binaries |
| `CAP_PERFMON` | Performance monitoring |

A seventh capability, `CAP_SYS_ADMIN`, is required when Go trace propagation is enabled or when `perf_event_paranoid` is set high. Alternatively, `privileged: true` in Kubernetes works but is broader than necessary.

Security teams will scrutinize this list. That review is the operational cost to factor in.

## Kubernetes deployment

The recommended production model is a **DaemonSet**: one OBI pod per node, instrumenting all workloads on the node. This requires `hostPID: true` so OBI can access all processes. No changes to application pods.

The sidecar model is also supported: one OBI container per application pod, with `shareProcessNamespace: true` and `privileged: true` on the sidecar. More granular control at the cost of efficiency at scale.

For a single cluster of any reasonable size, the DaemonSet is the right choice. You deploy it once and every service on every node gets baseline observability.

## Language scope

OBI is multi-language at the network-protocol level. Beyond Go, it supports Java (with an embedded Java agent extracted at runtime), .NET, Node.js, Python, Ruby, C, C++, Rust, and GenAI provider SDKs. This means one DaemonSet can cover a polyglot services environment. Go gets special treatment with library-level uprobes; other languages may only get network-level visibility depending on the stack.

## Where it fits

The clearest use case for OBI is the "I need baseline observability across services I don't own or can't rebuild right now" scenario. Ship the DaemonSet, get RED metrics and trace spans for all your HTTP/gRPC services, and then decide which services need deeper instrumentation via otelc or the SDK.

OBI and compile-time tools are complementary, not competing. OBI gives you breadth across all languages and doesn't require touching CI pipelines. Compile-time tools like otelc give you depth: custom spans, business logic, and stdlib instrumentation. They require a rebuild and, for otelc specifically, Go 1.25+.

The caveat worth repeating: OBI is at v0.10.0 with Development status. The feature set is real and production-tested (Grafana Labs ran this in production as Beyla before the donation), but the API stability guarantees are explicitly not there yet. Budget for minor release changes while it matures toward v1.
