---
title: "Making zero-touch Go observability agent-actionable"
date: 2026-07-29
draft: true
tags: ["go", "observability", "opentelemetry", "ebpf", "ai", "tooling"]
slug: zero-touch-go-observability-agent-actionable
---

The decision of how to instrument a Go service isn't complicated, but it is context-dependent. Two tools cover most cases — OBI for production runtime attach, otelc for local dev compile-time instrumentation — and choosing between them comes down to a handful of concrete questions: Is the service already deployed? Can you rebuild? Do you need custom spans or just HTTP/gRPC RED metrics?

That decision tree is simple enough to encode. And if it's encodable, it's automatable.

### The routing logic

The core decision looks like this:

**Use OBI** when:
- The service is already running (production, staging, Kubernetes, Docker Compose)
- Rebuilding or redeploying isn't acceptable
- The fleet is polyglot — multiple languages, one instrumentation layer
- You need HTTP/gRPC RED metrics (rate, errors, duration) or library-level spans

**Use otelc** when:
- You're working locally or in a dev environment where you control the build
- You need granular spans — specific functions, business logic, custom code paths
- You want to trace a specific slow path with exact data
- You're willing to rebuild with `otelc go build`

If neither fits cleanly, the tiebreaker question is: *"Is this for a running production service (OBI) or local development where you can rebuild (otelc)?"*

Both paths require an OTel Collector or Jaeger to receive the output. OBI additionally needs Linux kernel 5.8+ with BTF and six capabilities (`CAP_BPF`, `CAP_SYS_PTRACE`, `CAP_NET_RAW`, `CAP_CHECKPOINT_RESTORE`, `CAP_DAC_READ_SEARCH`, `CAP_PERFMON`). otelc needs the service to be in a language version it supports and a dev machine where you can run `go build`.

### What OBI actually covers

OBI instruments 13 Go libraries out of the box: `net/http`, gin, gRPC, gorilla/mux, go-redis, Kafka, `database/sql`, and others. It attaches from outside the process — no LD_PRELOAD, no restart, no rebuild. For Kubernetes, one DaemonSet covers every pod on every node:

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

The limitation is real and worth stating: custom spans, SQL query details, business-logic events — anything that isn't at the HTTP/gRPC boundary — still needs code changes. OBI observes what crosses library boundaries. It can't see inside your application logic.

### What otelc covers

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

### Making the decision executable

The routing logic above lives in a Claude Code skill called `collect-go-telemetry`. The skill encodes exactly the decision tree described here — production vs. dev, polyglot vs. Go-only, RED metrics vs. granular spans — and then pulls only the integration docs relevant to the libraries the service actually uses.

The last part matters for a practical reason: OBI's support matrix and otelc's aspect catalog are large. Fetching the full catalogs for every instrumentation request is wasteful. The skill uses per-library fetch scripts (`obi-integration.sh <library>`, `otelc-aspect.sh <import-path>`) to retrieve only the relevant sections. This is a pattern worth copying: treat your documentation as a retrieval problem, not a context-stuffing problem.

The skill's existence is the point. Observability decisions that engineers document in runbooks — "for production services use OBI, for local dev use otelc, here's how to set up each" — can be encoded as agent-actionable tools. The decision tree doesn't change per-request; what changes is the context (which service, which libraries, which environment). An agent can evaluate that context and execute the right steps.

### kubectl-obi: one command to instrument a cluster

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

The current implementation is a skeleton — the flag parsing and command structure are complete, the actual Kubernetes API calls are wired up but need a cluster to finish validating. The interface design is the point: zero-touch instrumentation should be a single verb, not a multi-step YAML exercise.

### The principle

The best observability is the kind your tools can set up for you.

This isn't about replacing engineering judgment. The decision tree still requires understanding what OBI can and can't observe, what privileges eBPF needs, what otelc's build requirements are. But once that judgment is encoded — once the routing logic is written down and the commands are documented — there's no reason a human has to re-execute it from memory every time. That's exactly the kind of procedural work that agents are good at.

The `collect-go-telemetry` skill and `kubectl-obi` are small examples of a broader pattern: take the decision framework from a talk or a runbook, make it executable, and let your tooling do the legwork.
