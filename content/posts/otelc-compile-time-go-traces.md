---
title: "otelc: zero-touch Go traces at compile time"
description: "otelc is the OpenTelemetry SIG's compile-time instrumentation tool for Go: separate from Orchestrion, built from scratch, and stable since v1.0.1."
date: 2026-07-16T00:00:00Z
publishDate: 2026-07-16T00:00:00Z
promote: false
categories:
  - engineering
tags:
  - blog
  - go
  - observability
  - opentelemetry
  - compile-time-instrumentation
  - auto-instrumentation
series:
  - How to Instrument Go Without Changing a Single Line of Code
showToc: true
tocOpen: false
---

We're going to instrument a Go program without touching its source, and the whole change fits in one build command. Here's the before and after:

```bash
go build -o myapp .
otelc go build -o myapp .
```

Same flags, same package, one extra word in front. The binary that comes out has OpenTelemetry instrumentation compiled in for the libraries otelc knows about, `net/http` and gRPC among them, and nobody opened a handler file.

That extra word is what we'll follow through this post. This is part 3 of 6 in the [How to Instrument Go Without Changing a Single Line of Code](/series/how-to-instrument-go-without-changing-a-single-line-of-code/) series, the written companion to my [GopherCon UK 2026 talk](/talks/instrument-go-without-changing-a-single-line/). [Part 2](/posts/obi-ebpf-auto-instrumentation-go/) covered the kernel route. Here we move the intervention to build time and follow that one command: who built it and what it does to `go build`, then what it sees, what it costs and where it fits, and whether "without a single line" survives the trip.

Disclosure: I work at Datadog, which maintains Orchestrion and dd-trace-go, and I'm one of otelc's maintainers. Read my comparisons with that in mind.

## Why there are two tools

Before we open the hood, a mix-up to clear: `otelc` has a lookalike. Naming is hard, and naming two tools that play the same trick is harder.

Orchestrion is Datadog's tool, CLI binary `orchestrion`. The release pinned for the talk (13 August 2026) is [v1.12.0](https://github.com/DataDog/orchestrion/releases/tag/v1.12.0) (2026-07-30). Its [README](https://github.com/DataDog/orchestrion/blob/v1.12.0/README.md) says other vendors, OpenTelemetry among them, may provide alternate integrations, but the ones it defaults to (dd-trace-go/v2) are Datadog's.

otelc is the OpenTelemetry Go compile-time instrumentation tool, CLI binary `otelc`. Why a second tool? The [SIG announcement](https://opentelemetry.io/blog/2025/go-compile-time-instrumentation/) (January 2025) says Alibaba and Datadog had each proposed donating a tool, Alibaba's `opentelemetry-go-auto-instrumentation` and Datadog's Orchestrion. Then the two organizations "decided to join forces" and set up a new SIG, with further contributions from Quesma. The goal was a unified, vendor-neutral approach that "picks the best aspects of each solution", and it "won't be Alibaba's or Datadog's solution that 'wins'". The SIG built otelc from scratch. Orchestrion was never donated and stays at `github.com/DataDog/orchestrion` as Datadog's own product.

[v1.0.0 and v1.0.1](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/releases/tag/v1.0.1) both went out on 2026-07-14, four weeks before the talk. The [v1.0.0 release notes](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/releases/tag/v1.0.0) retract it because `otelc pin` wrote incorrect module paths, so v1.0.1 is the first usable stable release and the one pinned for the talk. [v1.1.0](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/releases/tag/v1.1.0) followed on 2026-08-24. The OpenTelemetry blog's [v1 announcement](https://opentelemetry.io/blog/2026/go-compile-time-instrumentation-v1/) tells the milestone story (I [cross-posted](/posts/go-compile-time-instrumentation-v1/) it).

The two tools share a mechanism and differ in codebase and default tracer, so choosing is mostly about which tracer SDK you're committing to. The trick underneath is the same either way. Let's see what that extra word does to `go build`.

## The mechanism

Go's build system has a `-toolexec` flag. Normally `go build` invokes the compiler directly. With `-toolexec`, the go command runs each toolchain program (`compile`, `asm`, `link`, `vet`) through a wrapper binary first. `go help build` calls it "a program to use to invoke toolchain programs like vet and asm." That generic hook turns out to be exactly the right one for compile-time AOP: Orchestrion's maintainers describe their tool as, in some ways, a "compile-time-woven Aspect-oriented Programming (AoP) framework" ([golang/go#69887](https://github.com/golang/go/issues/69887)). My [guest post](https://internals-for-interns.com/posts/hooking-into-the-go-toolchain/) builds this `-toolexec` mechanism up step by step, cache included.

Our extra word plugs into that hook. `otelc go build` adds the flag for us and registers `otelc` as the wrapper. When the wrapper intercepts a compile for a package one of its rules matches, it parses that package's `.go` files into an AST, applies the rules (which functions to wrap, which spans to inject, how to propagate context), and hands the rewritten source to the real compiler. Everything else passes through untouched. The compiler never sees the original, so as far as it knows you wrote the instrumentation yourself, and it's too polite to ask.

How far does the rewriting reach? The [OpenTelemetry blog](https://opentelemetry.io/blog/2026/go-compile-time-instrumentation-v1/) says:

> "hooks into the standard Go toolchain during the build (through its `-toolexec` mechanism) and injects OpenTelemetry instrumentation into your code, its dependencies, and the standard library as they are compiled."

If `net/http` needs instrumentation, otelc can inject it as `net/http` gets compiled into your binary. The result has OTel spans baked in: no runtime agent, no sidecar, no dynamic injection. The rewrite injects a small trampoline (a generated stub in the target function) that calls a hook function, linked in with `//go:linkname`. The hooks are ordinary Go in otelc's instrumentation packages, and they call the OTel API and SDK, so at runtime the spans look like ones you'd have written by hand.

That's the whole trick, and it comes with a price tag. Let's read it before we buy.

## The constraint you need to know

otelc needs a Go 1.25 or newer toolchain (its [`go.mod`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.0.1/go.mod) says `go 1.25.0`). The toolchain is what counts: a service whose `go.mod` says `go 1.24` still builds with a newer toolchain, and otelc raises the directive with a warning. Builds pinned to a Go 1.23 or 1.24 toolchain can't use otelc, nor Orchestrion v1.12.0 ([`go.mod`](https://github.com/DataDog/orchestrion/blob/v1.12.0/go.mod)). For those, OBI ([part 2](/posts/obi-ebpf-auto-instrumentation-go/)) needs no rebuild.

When I prepared the talk, Go 1.26 (February 2026) was current, and Go 1.27 arrived on 2026-08-19, which ends upstream support for 1.25. Toolchain pinning is a fine habit until a tool wants a newer one. In slow-upgrade environments that's the first question to answer. If the toolchain clears, the next question is what the rebuild buys us.

## What it instruments

The default rules cover a list of libraries; for your own functions you write a custom rule. A rule is a YAML entry naming a target package, a selector and an action such as `inject_hooks` ([schema](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/docs/rules.md)); its hooks are Go in a package of their own. At v1.0.1 the [getting-started guide](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.0.1/docs/getting-started.md) listed `net/http` (client and server), gRPC, `database/sql`, gin, go-redis v9, mongo-driver, Kubernetes client-go, the OpenAI Go SDK (v1 to v3) and segmentio/kafka-go. v1.1.0 added Anthropic, AWS SDK v2, linodego and mongo-driver v2; the [docs' supported-libraries page](https://opentelemetry.io/docs/zero-code/go/compile-time/supported-libraries/) has the current list.

Orchestrion with dd-trace-go has its own list. Its [supported-integrations table](https://github.com/DataDog/dd-trace-go/blob/v2.9.1/contrib/supported_integrations.md) in dd-trace-go v2.9.1 (the version Orchestrion v1.12.0 pins) marks which integrations work with Orchestrion. They include HTTP frameworks (net/http, gin, gorilla/mux, chi, echo, fiber), gRPC, `database/sql` and the layers above it (pgx, gorm, mongo-driver), Redis (go-redis v6 to v9, redigo, rueidis), Kafka, AWS SDK v1 and v2, and Kubernetes client-go. Compare both lists against your own dependencies before choosing.

Coverage is one axis. The other is whether to rebuild at all, so let's put otelc next to OBI.

## Where it fits relative to OBI

OBI and otelc attack the same problem, zero source code changes, from opposite ends. Which end do we pick?

OBI attaches from outside the process at runtime. It needs no rebuild, works on deployed services, and covers other languages too. But it's bounded by what eBPF can observe at library boundaries: RED metrics and library-level spans for the Go libraries it supports ([13 in the OBI v0.10.0 support matrix](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/blob/v0.10.0/SUPPORT_MATRIX.md), the release pinned for the talk). It cannot generate custom spans or instrument business logic.

otelc works at build time. It requires a rebuild and Go 1.25 or newer. In exchange, it can reach stdlib internals, your own functions, dependencies and business logic, with a custom rule for anything the default set doesn't cover. The injected spans have the fidelity of hand-written OTel calls, because the hooks call the same OTel API and SDK you would.

My decision rule: deployed and can't rebuild, need baseline visibility across services? OBI. Building or rebuilding, want granular spans, on Go 1.25 or newer? otelc. Running Datadog APM with the widest framework coverage? Orchestrion. [Part 6](/posts/zero-touch-go-observability-agent-actionable/) turns this into a runbook. For now, time to run that command.

## Try it

Install otelc, pinned to a version. I ran v1.1.0; its runtime rules match v1.0.1, the version pinned for the talk:

```bash
go install go.opentelemetry.io/otelc/tool/cmd/otelc@v1.1.0
```

Then build the service with otelc wrapping the build command, exactly as in the opening:

```bash
otelc go build -o myapp .
```

That's the complete usage change. To see traces, run the binary with `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318` and `OTEL_SERVICE_NAME=my-go-service`. otelc exports OTLP over HTTP by default, so use 4318, not the gRPC port 4317 ([part 6](/posts/zero-touch-go-observability-agent-actionable/#what-otelc-covers) explains). In CI, put `otelc` in `$PATH` and prefix your existing build command. If you can't prefix it, the getting-started guide describes a second route: run `otelc setup` once, then set `GOFLAGS="'-toolexec=otelc toolexec'"` and use plain `go build`.

"Without a single line" sounds absolute, so here's the fine print. You don't edit `go.mod` yourself, but otelc does touch it. During the build it adds its hook modules as `replace` directives, runs `go mod tidy`, and may raise the `go` directive (it prints `Bumped go version` when it does), then restores `go.mod` and `go.sum` when the build finishes. A `.otelc-build/` directory stays behind. If a build is interrupted, the [troubleshooting guide](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.0.1/docs/troubleshooting.md) says to run `otelc cleanup` and `git restore go.mod go.sum`.

Already using `otelhttp` and your own spans? I built a small server with `otelhttp.NewHandler` and one manual span using `otelc go build` (v1.1.0, Go 1.27.1, macOS arm64) and sent three requests to Jaeger. Each request was one trace: otelc's server span at the root, the `otelhttp` server span under it, and my manual span under that. Nothing is orphaned, but you get two server spans per request. I didn't test dd-trace-go.

Back to our one command, then. "Without a single line" really means one build command substitution and Go 1.25 on your toolchain. I'll take that trade most days. 🔧

Versions, links and commands checked on 2 October 2026.

## Up next

[Part 4, The fourth signal: continuous profiling without code changes](/posts/continuous-profiling-go-without-code-changes/), goes back to the kernel to add profiles, and asks what a stripped binary still remembers. Next time, nobody rebuilds anything.
