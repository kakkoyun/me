---
title: "Making zero-touch Go observability agent-actionable"
description: "Turn the OBI vs. otelc decision into an agent-readable runbook, then make the Kubernetes path boring enough to run with one command."
date: 2026-08-03T00:00:00Z
publishDate: 2026-08-03T00:00:00Z
draft: true
categories:
  - engineering
tags:
  - blog
  - go
  - observability
  - opentelemetry
  - ebpf
  - ai
  - tooling
series:
  - How to Instrument Go Without Changing a Single Line of Code
showToc: true
tocOpen: false
---

A useful agent skill starts with a boring question: is this Go service already running, or can I rebuild it?

If it is already running in Kubernetes, OBI is the default. If I can rebuild locally and need function-level spans, otelc is the default. The rest of the decision tree is mostly checking privileges, Go version, collector endpoint, and whether RED metrics are enough.

## The routing logic

The core decision looks like this:

**Use OBI** when:
- The service is already running (production, staging, Kubernetes, Docker Compose)
- Rebuilding or redeploying isn't acceptable
- The fleet is polyglot: more than one language, one instrumentation layer
- You need HTTP/gRPC RED metrics (rate, errors, duration) or library-level spans

**Use otelc** when:
- You're working locally or in a dev environment where you control the build
- You need granular spans for specific functions, business logic, or custom code paths
- You want to trace a specific slow path with exact data
- You're willing to rebuild with `otelc go build`

If neither fits cleanly, the tiebreaker question is: *"Is this for a running production service (OBI) or local development where you can rebuild (otelc)?"*

Both paths require an OTel Collector or Jaeger to receive the output. OBI additionally needs Linux kernel 5.8+ with BTF and six capabilities (`CAP_BPF`, `CAP_SYS_PTRACE`, `CAP_NET_RAW`, `CAP_CHECKPOINT_RESTORE`, `CAP_DAC_READ_SEARCH`, `CAP_PERFMON`). otelc needs the service to be in a language version it supports and a dev machine where you can run `go build`.

## What OBI actually covers

OBI instruments 13 Go libraries out of the box: `net/http`, gin, gRPC, gorilla/mux, go-redis, Kafka, `database/sql`, and others. It attaches from outside the process: no LD_PRELOAD, no restart, no rebuild. For Kubernetes, one DaemonSet covers every pod on every node:

```bash
kubectl apply -f https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/releases/download/v0.10.0/obi-daemonset.yaml
kubectl get pods -n obi-system
```

For Docker Compose, add an OBI container alongside your service:

```yaml
obi:
  image: ghcr.io/open-telemetry/opentelemetry-ebpf-instrumentation:v0.10.0
  pid: host
  privileged: true
  environment:
    OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4317
  volumes:
    - /sys/fs/bpf:/sys/fs/bpf
    - /sys/kernel/debug:/sys/kernel/debug
```

The span-depth cost is concrete: custom spans, SQL query details, and business-logic events still need code changes when they are not at the HTTP/gRPC boundary. OBI observes what crosses library boundaries. It can't see inside your application logic.

## What otelc covers

otelc takes the compile-time path: `otelc go build` is a drop-in for `go build`. It instruments your code, its dependencies, and parts of the standard library at the AST level. The injected spans have the same cost as manually written OTel code.

```bash
go install go.opentelemetry.io/otelc/tool/cmd/otelc@latest
otelc go build -o ./myapp ./...

OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317 \
OTEL_SERVICE_NAME=my-go-service \
./myapp
```

For local dev, pair this with Jaeger all-in-one:

```bash
docker run -d --name jaeger \
  -p 16686:16686 -p 4317:4317 \
  jaegertracing/all-in-one:latest
```

The tradeoff is build-time coupling. You can't attach otelc to a running production binary. It's the right tool when you're chasing down a specific slow code path and need exact function-level data, not when you're trying to instrument a fleet without touching running services.

## Making the decision executable

The routing logic above lives in a Claude Code skill called `collect-go-telemetry`. The skill encodes the decision tree described here: production vs. dev, polyglot vs. Go-only, RED metrics vs. granular spans. Then it pulls only the integration docs relevant to the libraries the service actually uses.

The last part matters for a practical reason: OBI's support matrix and otelc's aspect catalog are large. Fetching the full catalogs for every instrumentation request is wasteful. The skill uses per-library fetch scripts (`obi-integration.sh <library>`, `otelc-aspect.sh <import-path>`) to retrieve only the relevant sections. This is a pattern worth copying: treat your documentation as a retrieval problem, not a context-stuffing problem.

The useful part is the named checklist. A runbook can say: "for production services use OBI, for local dev use otelc, here's how to set up each." The decision tree doesn't change per request; the context does: which service, which libraries, which environment. An agent can inspect that context and execute the right steps.

## kubectl-obi: one command to instrument a cluster

For the Kubernetes path specifically, `kubectl-obi` is a krew plugin that wraps the DaemonSet lifecycle:

```bash
# Instrument everything on every node
kubectl obi attach

# Check what's being instrumented
kubectl obi status --all-namespaces

# Target one deployment with a sidecar instead
kubectl obi attach my-service --mode=sidecar --namespace=production

# Stop instrumenting
kubectl obi detach
```

The plugin handles the DaemonSet apply/delete without requiring you to remember the manifest URL or manage YAML manually. `kubectl obi attach` is the zero-argument case that does the right thing for most clusters.

The current implementation is a skeleton. The flag parsing and command structure are complete, and the actual Kubernetes API calls are wired up but need a cluster to finish validating. The interface design is the point: zero-touch instrumentation should be a single verb, not a multi-step YAML exercise.

## What I would automate next

The useful part is not that an agent can memorize two tools. The useful part is that the messy operational checks have names: kernel version, capabilities, collector endpoint, rebuild access, Go version, and span depth.

I still would not let a skill silently attach eBPF to production. The next version should produce a plan first: what it will attach, what privileges it needs, and how to roll it back. Boring, reversible, logged. Observability needs more of that kind of magic trick.
