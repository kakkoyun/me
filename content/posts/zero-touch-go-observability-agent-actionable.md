---
title: "Making zero-touch Go observability agent-actionable"
description: "Turn the OBI vs. otelc decision into an agent-readable runbook, then make the Kubernetes path boring enough to run with one command."
date: 2026-08-06T00:00:00Z
publishDate: 2026-08-06T00:00:00Z
promote: false
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
  - auto-instrumentation
series:
  - How to Instrument Go Without Changing a Single Line of Code
showToc: true
tocOpen: false
---
You can't reproduce the bug locally, so you add a log line and redeploy. Wrong place. You add another one and redeploy again. That is the debugging loop from [my GopherCon UK talk](/talks/instrument-go-without-changing-a-single-line/), and in this last part we're going to shorten it: a decision rule for two zero-touch tools, then a runbook an AI coding agent (not a Java-style one) can execute.

The runbook starts with one boring question: is this Go service already running, or can I rebuild it? If the service has to stay untouched, OBI (OpenTelemetry eBPF Instrumentation) is the default. If I can rebuild it and need function-level spans, otelc (OpenTelemetry Go compile-time instrumentation) is the default. The rest of the decision tree is checking privileges, Go version, collector endpoint, and whether RED metrics are enough.

We'll keep that loop in view the whole way (yes, that's foreshadowing 👀) and see whether the series promise survives contact with it. This is part 6 of 6 in the [How to Instrument Go Without Changing a Single Line of Code](/series/how-to-instrument-go-without-changing-a-single-line-of-code/) series. [Part 5](/posts/go-runtime-futures-flight-recording-usdt/) looked at what Go itself might add, and parts 2 to 4 covered the tools ([OBI](/posts/obi-ebpf-auto-instrumentation-go/), [otelc](/posts/otelc-compile-time-go-traces/), the [eBPF profiler](/posts/continuous-profiling-go-without-code-changes/)). Disclosure: I'm one of otelc's maintainers, and [zeroins](https://github.com/kakkoyun/zeroins/tree/v0.2.0), `kubectl-obi` and the skill in this part are my own projects. The skill and plugins below live in the zeroins repository.

## The routing logic

The series follows three intervention points: build time, process start and the kernel. For a Go service, two of them are real routes. We reach for OBI when the service is already running (production, staging, Kubernetes, Docker Compose) and rebuilding or redeploying isn't acceptable, when the fleet is polyglot, or when HTTP/gRPC RED metrics (rate, errors, duration) and library-level spans are all we need. We reach for otelc when we control the build (a laptop, CI or the release pipeline), want granular spans for specific functions or one slow path, and are willing to rebuild with `otelc go build`. If neither fits cleanly, the tiebreaker is one question: *can this service be rebuilt and redeployed (otelc), or does it have to stay untouched (OBI)?*

The profiler from [part 4](/posts/continuous-profiling-go-without-code-changes/) isn't a third route but a layer beside either one, adding whole-node CPU profiles. A practical stack is otelc in the build for semantic spans, OBI for service boundaries and other languages, and the profiler for the node; add a layer when its signal earns the cost. The flight recorder lives in your code, so it stays out of the runbook. Orchestrion is not in this tree, since the zeroins lookups cover only OBI and otelc ([part 3](/posts/otelc-compile-time-go-traces/#where-it-fits-relative-to-obi) still points to it for Datadog APM).

Both routes need somewhere to send the output, such as an OTel Collector or Jaeger. OBI needs a BTF-enabled Linux kernel and a specific capability set ([part 2](/posts/obi-ebpf-auto-instrumentation-go/#what-it-requires) has the list), and otelc needs Go 1.25 or newer.

What happened to process start? We left it out on purpose. The [OpenTelemetry host injector](https://github.com/open-telemetry/opentelemetry-injector/blob/v0.10.1/README.md) preloads agents for Java, Node.js, .NET, Ruby, and Python (disabled by default), not Go, and a pure-Go build is static, so [`LD_PRELOAD` has nothing to attach to](https://github.com/open-telemetry/opentelemetry-injector/blob/v0.10.1/DESIGN.md). The OpenTelemetry Operator's [`inject-go` annotation](https://opentelemetry.io/docs/platforms/kubernetes/operator/automatic/) doesn't change that: it adds a per-pod sidecar running the Go auto-instrumentation agent (`go.opentelemetry.io/auto`, not OBI), off by default, that needs a privileged root container. A fleet-wide injector can keep the other runtimes while Go services route to OBI, or to otelc if you can rebuild ([part 1](/posts/why-go-cant-be-monkey-patched/#process-start-the-injector) has the background). Two routes remain. Let's see what each one buys us, starting with the one that leaves our binary alone.

## What OBI actually covers

OBI instruments [13 Go libraries](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.10.0/SUPPORT_MATRIX.md) out of the box, including `net/http`, gin, gRPC and `database/sql` ([the list is in part 2](/posts/obi-ebpf-auto-instrumentation-go/#what-it-actually-instruments-in-go)). It attaches from outside the process: no `LD_PRELOAD`, no rebuild, and in DaemonSet mode no restart. It also skips services it sees publishing their own OpenTelemetry telemetry (`exclude_otel_instrumented_services`, on by default), so an OTel Java or Python agent shouldn't double up; the docs describe this for OpenTelemetry SDK calls, so test a pod with a vendor agent first. On Kubernetes that DaemonSet comes from a Helm chart, and the defaults of chart 0.10.0 (`open-telemetry/opentelemetry-ebpf-instrumentation`) are enthusiastic: every namespace, privileged, exporting to a collector on the node IP (`${HOST_IP}:4317` for traces, `:4318` for metrics). Point it elsewhere before installing it on a cluster you care about.

The cost is span depth. Custom spans and business-logic events still need code changes when they are not at the HTTP/gRPC boundary. OBI observes what crosses library boundaries and can't see inside our logic, so when the slow part is in our own functions, we need the other route.

## What otelc covers

otelc takes the compile-time path: [`otelc go build`](https://opentelemetry.io/docs/zero-code/go/compile-time/) is a drop-in for `go build`. It instruments your code, its dependencies, and parts of the standard library at the AST level, and the injected spans cost the same as manually written OTel code. Here is the entire change: install the tool, swap the build command, run the binary with an endpoint and a service name.

```bash
go install go.opentelemetry.io/otelc/tool/cmd/otelc@v1.1.0
otelc go build -o ./myapp .

OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 \
OTEL_SERVICE_NAME=my-go-service \
./myapp
```

That is what "without a single line" means in practice: not one line of application source, one changed line in the build script. The endpoint says 4318 on purpose. otelc's runtime exports OTLP over HTTP (`http/protobuf`) by default, and 4317 is the gRPC port. Point the default protocol at 4317 and you get `malformed HTTP response` errors instead of traces (wrong door, polite knock); to use 4317, set `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`.

The tradeoff is build-time coupling: we can't attach otelc to a running binary, or instrument services we are not rebuilding. We can put it in the release pipeline, though. The [getting-started guide](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/docs/getting-started.md) covers CI/CD and calls it stable and ready for production use as of v1.0.0. Two tools, two sets of costs, and a choice an impatient human will get wrong at 3 a.m. Let's write it down so an agent can follow it.

## Making the decision executable

A decision tree in a blog post doesn't shorten anyone's loop. As the [talk](/talks/instrument-go-without-changing-a-single-line/) puts it, an agent on its own still has to pick a mechanism and know what it costs. I put the routing logic into an agent skill called [`collect-go-telemetry`](https://github.com/kakkoyun/zeroins/blob/v0.2.0/skills/collect-go-telemetry/SKILL.md), installed with `npx skills add kakkoyun/zeroins --all`. It encodes the decision tree and wraps it in a fixed workflow: preflight, coverage lookup, dry-run plan, confirmation gate, bounded attach, confirm traces, session audit. The tree is fixed; the context (which service, which libraries, which environment) is what an agent inspects.

The coverage step is the clever bit. Pasting OBI's support matrix and otelc's library catalog into context for every request is wasteful, so the skill uses per-library lookups (`zeroins obi lookup <library>`, `zeroins otelc lookup <import-path>`) that return only the relevant rows. They are offline, reading a snapshot embedded in the binary (OBI v0.10.0 and otelc v1.0.1 in zeroins v0.2.0), so they change only when zeroins does. Treat documentation as a retrieval problem, not a context-stuffing problem. The skill can now choose and look things up, but on Kubernetes something still has to do the attaching.

## zeroins and kubectl-obi: the Kubernetes path

That something is `kubectl-obi`, one of two experimental `kubectl` plugins in zeroins, which I wrote for the talk. `go install` puts an executable named `kubectl-obi` on your `PATH`, and `kubectl` discovers it as `kubectl obi`. It deploys privileged eBPF observers and is not a production installer, so the first thing we do is read the dry-run. It shells out to `helm` and `kubectl` (zeroins asks for helm v4), and `--endpoint` is required. Here is the lifecycle, dry-run first:

```bash
go install github.com/kakkoyun/zeroins/cmd/...@v0.2.0

# Review the plan first (changes nothing)
kubectl obi attach --dry-run --endpoint=https://otel-collector.observability.svc:4318

# Instrument everything on every node, detach automatically after 15 minutes
kubectl obi attach --duration=15m --endpoint=https://otel-collector.observability.svc:4318

# Check what's being instrumented
kubectl obi status --all-namespaces

# Stop instrumenting
kubectl obi detach
```

The endpoint must be an OTLP HTTP(S) base URL, so no `/v1/traces` suffix. In DaemonSet mode the plugin installs the pinned OBI chart (0.10.0, OBI v0.10.0, the release pinned for the talk on 13 August 2026) into the `obi-system` namespace with Helm. Sidecar mode also exists; it patches one deployment and restarts it, so the "no restart" promise holds only for the DaemonSet. Sidecar mode needs its own `kubectl obi detach <deployment> --mode=sidecar`; a bare `detach` removes only the DaemonSet. The whole thing is experimental: CI runs unit tests and Helm contract checks, and the real-eBPF integration test on a disposable K3s cluster last passed shortly before the v0.2.0 tag.

Handing an agent a command that attaches privileged eBPF programs to a cluster is exactly as fun as it sounds. Hence the guardrails.

## Guardrails before attach

The messy operational checks deserve names: kernel version, capabilities, collector endpoint, rebuild access, Go version, and span depth. I still would not let a skill silently attach eBPF to production, so the skill doesn't. It produces a plan first (`attach --dry-run` prints the cluster context, the privileges, the exact commands and the rendered values), then stops at a confirmation gate until a human approves. Exploratory attaches take `--duration` and detach themselves, and `zeroins sessions list` and `zeroins sessions reap` show and clean up what is still attached. Boring, reversible, logged. Observability needs more of that kind of magic trick. That's the whole runbook, so let's run the safe parts of it.

## Try it

Nothing here touches a cluster. First, a local trace backend for the otelc example above, using [Jaeger](https://www.jaegertracing.io/docs/2.21/getting-started/). Jaeger only accepts traces, so the metrics flush logs a 404 when the process shuts down. The traces arrive anyway:

```bash
docker run -d --name jaeger -p 16686:16686 -p 4318:4318 jaegertracing/jaeger:2.21.0

# build and run any small net/http service as shown in "What otelc covers", send a few requests, then:
curl -s localhost:16686/api/v3/services
```

The services list should include `my-go-service`. Then the zeroins side, which only looks things up and prints a plan:

```bash
zeroins obi lookup net/http
zeroins otelc lookup net/http
kubectl obi attach --dry-run --endpoint=https://otel-collector.observability.svc:4318
```

The two lookups say which route covers `net/http`, and the dry-run prints the plan a human would be asked to approve.

Versions, links and commands checked on 2 October 2026.

## Where to go from here

Back to the loop. The bug that won't reproduce locally used to cost a log line and a redeploy, then another when the first guess landed in the wrong place. Now the first move is the boring question from the top of this post. If the service has to stay untouched, the plan is one dry-run away and, in DaemonSet mode, nothing restarts. If the answer lives in our own functions, the question sends us to otelc, and the rebuild carries no source edit. Either way, we stop guessing where the log line goes.

That is the series. The [talk page](/talks/instrument-go-without-changing-a-single-line/) has the slides and links, and the [FOSDEM 2026 post](/posts/fosdem-2026-auto-instrumenting-go/) has the write-up of the earlier version of the talk. To help out, OBI, otelc and the eBPF profiler each have an OpenTelemetry SIG (see the [community repository](https://github.com/open-telemetry/community)), and Ollygarden's [agent skills](https://github.com/ollygarden/opentelemetry-agent-skills) are a good next stop for more OpenTelemetry skills.

Two routes, one boring question, no source edits. Go break the loop. 🔧
