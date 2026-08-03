---
title: "otelc: zero-touch Go traces at compile time"
date: 2026-07-28
draft: true
description: "otelc is the OTel SIG's compile-time instrumentation tool for Go — distinct from Orchestrion, built from scratch, and now at its first stable release. Here's what it does and what it requires."
tags: ["go", "observability", "opentelemetry", "compile-time-instrumentation"]
categories: ["engineering"]
slug: "otelc-compile-time-go-traces"
toc: true
---

There are two separate compile-time Go instrumentation tools, and they are regularly confused for each other. Getting that distinction right is the prerequisite for understanding either of them.

**DataDog/orchestrion** is Datadog's tool, CLI binary `orchestrion`, defaults to dd-trace-go/v2. It reached GA at v1.0.0 in November 2024 and is currently at v1.11.0 (2026-06-25). It's vendor-agnostic — you can configure it to use OTel SDK — but Datadog maintains it.

**open-telemetry/opentelemetry-go-compile-instrumentation** is the OTel SIG tool, CLI binary `otelc`. It was built from scratch by Datadog and Alibaba working together under the OpenTelemetry umbrella — inspired by Orchestrion, but a separate codebase with separate maintenance. v1.0.1 shipped on 2026-07-14. That's the first non-retracted stable release.

Orchestrion was not donated to OpenTelemetry. It still lives at `github.com/DataDog/orchestrion`. The relationship between the two tools is: shared mechanism, shared inspiration, different codebases and sponsors.

This post covers `otelc`. If you want the official project announcement, I also cross-posted the [OpenTelemetry blog's v1 post](/posts/go-compile-time-instrumentation-v1/) — that's the community-facing milestone story. This post is the practitioner take: what the mechanism actually is, what the constraints are, and when to reach for it.

### The mechanism

Both tools use the same core approach, which the Orchestrion maintainers describe as compile-time-woven Aspect-Oriented Programming. Here's how it works:

Go's build system has a `-toolexec` flag. Normally, `go build` invokes the compiler directly. With `-toolexec`, every invocation of `go tool compile` passes through your wrapper binary first. `otelc` registers itself as that wrapper.

When `otelc` intercepts a compile invocation, it parses each `.go` source file into an AST, applies instrumentation rules (which functions to wrap, which spans to inject, how to propagate context), and hands the rewritten source to the real compiler. The compiler never sees the original; from its perspective, you just wrote the instrumentation code yourself.

From the OTel blog on otelc:

> "hooks into the standard Go toolchain during the build (through its `-toolexec` mechanism) and injects OpenTelemetry instrumentation into your code, its dependencies, and the standard library as they are compiled."

That last part matters: not just your code, but dependencies and stdlib too. If `net/http` needs instrumentation, otelc can inject it at the point where `net/http` gets compiled into your binary.

The result is a binary with OTel spans baked in. No runtime agent, no sidecar, no dynamic injection. At runtime, the instrumented code calls the OTel SDK just as if you'd written the calls manually — because after the AST rewrite, you effectively did.

### Using it

Install:

```bash
go install go.opentelemetry.io/otelc/tool/cmd/otelc@latest
```

Build your service with otelc wrapping the build command:

```bash
otelc go build -o myapp .
```

That's the complete usage change. No `go:generate`, no build tags, no source modifications. The `-toolexec` flag is wired in by `otelc go build` automatically.

For CI, you set `otelc` in `$PATH` and prefix your existing build command. It works with any build system that accepts custom `go build` invocations. No changes to `go.mod` required for the application itself; otelc manages its own dependencies.

### The constraint you need to know

`otelc` requires **Go 1.25+**. This is confirmed from the README badge and is a genuine constraint: services on Go 1.23 or 1.24 cannot use otelc. For those, OBI (no rebuild required) or Orchestrion (check its `go.mod` for minimum version) are the options.

Go 1.25 isn't ancient — at time of writing it's current — but in environments with slow upgrade cycles or pinned toolchains, this will be the first question to answer.

### Why two tools

It's a fair question. The OTel SIG blog post describes it as Datadog and Alibaba having "independently built compile-time Go instrumentation tools and converged." Orchestrion is Datadog's production-tested tool with broad dd-trace-go integration. The SIG decided the right move was to build a new OTel-native tool from scratch rather than donate Orchestrion wholesale, keeping Orchestrion as Datadog's supported product while the SIG owns the OTel-standard version.

The practical implication for users: if you're on the OTel SDK and want vendor-neutral compile-time instrumentation, `otelc` is the right choice. If you're running Datadog APM and want the broadest integration coverage (51 libraries in dd-trace-go's `contrib/`), Orchestrion is battle-tested and default-wired to dd-trace-go/v2.

The mechanism is identical. Choosing between them is mostly about which tracer SDK you're committing to.

### What it instruments

The OTel blog describes otelc as instrumenting "your code, its dependencies, and the standard library." The exact list of supported frameworks for v1.0.1 is in the repository's instrumentation packages. The Orchestrion + dd-trace-go side (which otelc is converging toward) covers HTTP frameworks (net/http, gin, gorilla/mux, chi, echo, fiber), gRPC, database/sql and ORM layers (sqlx, gorm, mongo-driver), Redis (go-redis v6-v9, redigo, rueidis), Kafka, AWS SDK v1/v2, and Kubernetes client-go.

otelc's coverage is growing toward parity. Check the repo's current state for the exact list — it will have changed between when this was written and when you read it.

### Where it fits relative to OBI

OBI and otelc address the same underlying problem — zero source code changes — but from opposite ends.

OBI attaches from outside the process at runtime. It requires no rebuild, works immediately on deployed services, and handles multiple languages from a single DaemonSet. But it's bounded by what eBPF can observe at library boundaries: RED metrics and library-level spans for the 13 Go libraries it supports. It cannot generate custom spans or instrument business logic.

otelc works at build time. It requires a rebuild and Go 1.25+. In exchange, it can instrument anything: stdlib internals, your own functions, dependencies, business logic. The injected spans have the same fidelity as manually written OTel SDK calls, because after the AST rewrite, they are manually written OTel SDK calls — the compiler just doesn't know you didn't type them.

The decision rule I use:

- Already deployed, can't rebuild, need baseline visibility across services → **OBI**
- Building or rebuilding, want granular spans, on Go 1.25+ → **otelc**
- Running Datadog APM with the widest framework coverage → **Orchestrion**

For GopherCon UK 2026, otelc landing at v1.0.1 two weeks before the conference is the most timely piece of the story. The first stable release of an OTel-native compile-time Go instrumentation tool is a meaningful moment in the "Go without a single line of code" narrative, even if "without a single line" really means "with one build command substitution and Go 1.25 on your toolchain."

The `-toolexec` mechanism is one of Go's least-discussed build features. It was designed for code coverage and cgo toolchains — the Go team did not plan it as an instrumentation API. It turns out to be exactly the right hook for compile-time AOP anyway.
