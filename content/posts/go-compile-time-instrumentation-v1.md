---
title: "OpenTelemetry Go Compile-time Instrumentation v1"
description: "OpenTelemetry ships v1 of Go compile-time instrumentation — zero-code telemetry injected via the Go toolchain's -toolexec hook."
date: 2026-07-22T00:00:00Z
publishDate: 2026-07-22T00:00:00Z
categories:
  - engineering
tags:
  - blog
  - opentelemetry
  - otel
  - go
  - observability
  - instrumentation
  - compile-time
showToc: true
tocOpen: false
promote: true
showCanonicalLink: true
canonicalUrl: https://opentelemetry.io/blog/2026/go-compile-time-instrumentation-v1/
---

> [!NOTE]
> This post was originally published on the [OpenTelemetry blog](https://opentelemetry.io/blog/2026/go-compile-time-instrumentation-v1/) on 2026-07-16. I wrote it for the OpenTelemetry community; this is a mirror on my personal blog with some added commentary.

---

## Why this milestone matters to me

I have been involved with the Go Compile-Time Instrumentation SIG since it kicked off at the start of 2025, when Alibaba and Datadog decided to pool their efforts into a single vendor-neutral project. Watching it reach v1 last week felt genuinely satisfying — not because "v1" is a magic number, but because it marks the point where we stopped calling it experimental and started calling it something people should actually run in their builds.

The Go situation has always been a little awkward for OpenTelemetry. Every other language has a story: attach a Java agent, install a Python auto-instrumentation package, load a Node.js module. Go compiles to a static binary with no runtime hook points. The options were either manual instrumentation (correct but tedious) or an eBPF agent running outside the process (zero-code but with its own caveats). Compile-time instrumentation is the third option: use Go's own toolchain machinery (specifically the `-toolexec` flag) to inject instrumentation at build time, not at startup.

The reason I find this bet interesting is that it sits exactly where Go's constraints become an asset. Because we operate during compilation, we have the full type information and package graph available. We can instrument code you didn't write and wouldn't want to modify: the `net/http` standard library, `database/sql`, gRPC, Redis drivers. The binary you ship has the telemetry baked in, so there is no separate process to manage, no LD_PRELOAD tricks, no eBPF programs to load. It is just a Go binary, compiled slightly differently.

I am proud of what the SIG shipped and grateful to the maintainers and contributors who drove it across the finish line. The acknowledgments section below names them properly. v1 is a foundation — coverage will grow, the registry integration will land, and the performance story will get tighter. If you run Go services and want traces and metrics without touching application code, now is a good time to try it.

---

## The announcement

*What follows is the original post as published on the OpenTelemetry blog.*

---

If you write Java, Python, Node.js, or .NET, you have been able to add
OpenTelemetry to an application without editing its code for years: attach an
agent at startup and telemetry starts flowing. Go has been the exception. A Go
program compiles to a single static binary with no runtime to hook into at
startup, so Go developers have had to instrument by hand or reach for an
out-of-process eBPF agent.

That gap is closing. The OpenTelemetry community is announcing the first stable
release of
[OpenTelemetry Go Compile-Time Instrumentation](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation).
When we [announced this SIG](https://opentelemetry.io/blog/2025/go-compile-time-instrumentation/) at the
start of 2025, Alibaba and Datadog joined forces to build one unified,
vendor-neutral way to instrument Go at build time. v1 is that project's first
stable release.

If you build and run Go services, you can change a single line in how you build
your binary or container image and get OpenTelemetry traces and metrics for your
application and its dependencies, with no code changes. For a platform engineer
or an SRE, that means you can add observability to services across your fleet
without waiting for every team to instrument their own code.

## What is Go Compile-time Instrumentation?

Go compiles to a single static binary, which has long made automatic
instrumentation harder than in interpreted languages. This project hooks into
the standard Go toolchain during the build (through its `-toolexec` mechanism)
and injects OpenTelemetry instrumentation into your code, its dependencies, and
the standard library as they are compiled. There is no separate agent and
nothing to attach at runtime.

For you, that means telemetry with no source-code changes: the instrumentation
is compiled directly into your binary. Your application code stays free of
instrumentation concerns, and you get coverage for third-party libraries you
don't own.

## Key capabilities in v1

- **Zero-code instrumentation**: instrument an application and its dependencies
  without manual code changes.
- **Compile-time injection, no added runtime overhead**: instrumentation is
  built into the binary instead of attached at runtime.
- **Third-party and standard-library coverage**: instrument dependencies and
  standard-library packages you don't own.
- **Supported instrumentations in v1**: common libraries and frameworks
  including `net/http`, `database/sql`, gRPC, Redis, and Go runtime metrics,
  with more added regularly. See the
  [supported libraries](https://opentelemetry.io/docs/zero-code/go/compile-time/supported-libraries/)
  for the full, current list.
- **Rule-based and extensible**: add support for new libraries through the SIG's
  instrumentation-rule format. See the
  [instrumentation guide](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.0.0/docs/instrument-guide.md)
  and the
  [rules reference](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.0.0/docs/rules.md).
- **Semantic-convention compliance**: emitted telemetry follows current
  OpenTelemetry semantic conventions.
- **CI/CD friendly**: run the tool at development time or drop it into your
  build pipeline.

## Getting started

The project ships a command-line tool called `otelc` that wraps the standard Go
toolchain. The change to your build is a single line: run `otelc go build` where
you used to run `go build`. Everything after `go` is forwarded to the toolchain,
so the rest of your build stays the same.

Install it with `go install`:

```sh
go install go.opentelemetry.io/otelc/tool/cmd/otelc@latest
```

Then build your application through it:

```sh
otelc go build -o myapp .
```

If you'd rather not change your build command, run `otelc setup` once to prepare
the module, then point the Go toolchain at `otelc` through `GOFLAGS` and keep
running `go build` as usual:

```sh
otelc setup
export GOFLAGS="${GOFLAGS} '-toolexec=otelc toolexec'"
go build -o myapp .
```

By default, `otelc` discovers the supported libraries in your module and
instruments them automatically, with no configuration and no code changes. The
same swap works in a container build: install `otelc` in your build stage and
replace the `go build` line in your `Dockerfile` with `otelc go build`. For the
full walkthrough, see the
[compile-time instrumentation documentation](https://opentelemetry.io/docs/zero-code/go/compile-time/).

## When should you use it?

If you write or operate Go services, you now have three complementary ways to
get OpenTelemetry telemetry, and compile-time instrumentation is the third
option promised in the founding post:

- **Compile-time instrumentation (this project)**: best when you can rebuild the
  application and want no code changes, no added runtime overhead, and coverage
  of dependencies and the standard library.
- **eBPF instrumentation
  ([OpenTelemetry eBPF Instrumentation, or OBI](https://opentelemetry.io/docs/zero-code/obi/))**: best
  when you can't rebuild the binary, or want zero-code, multi-language
  instrumentation from outside the process.
- **Manual instrumentation with the
  [OpenTelemetry Go API](https://opentelemetry.io/docs/languages/go/)**: best for custom spans and
  domain-specific telemetry, and it composes with the other two.

v1 ships a focused set of instrumentations rather than the full breadth of the
Go ecosystem, and coverage will grow with each release. If a library you depend
on isn't covered yet, you can add a rule for it or combine compile-time
instrumentation with manual spans. The three approaches above solve overlapping
problems in different ways, so we're working with the OBI and Go SIGs on
follow-up posts that compare them in more depth.

## What's next

v1 covers the core of the compile-time approach. Our priorities from here:

- **More instrumentations**: broaden coverage across popular Go libraries and
  frameworks so more applications work the moment you swap in `otelc`.
- **Registry-based discovery**: use the existing
  [OpenTelemetry Registry](https://opentelemetry.io/ecosystem/registry/) to discover and distribute
  instrumentations, so you can pick up support for new libraries without waiting
  for a new `otelc` release.
- **Performance**: keep driving down both build-time and runtime cost.
- **Adoption and awareness**: invest in docs, examples, and outreach so teams
  know the tool exists and how to fit it into their build.

## Get involved

Compile-time instrumentation is v1, and the best way to shape where it goes next
is to use it and get involved.

- **Try it and tell us how it went.** Add `otelc` to a build and share what
  worked and what didn't in the project's
  [GitHub discussions and issues](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation).
  Real-world feedback drives the roadmap.
- **Instrument a library you use.** Coverage grows through the SIG's rule
  format; the
  [instrumentation guide](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.0.0/docs/instrument-guide.md)
  walks through adding one.
- **Join the SIG.** Find us in
  [#otel-go-compile-instrumentation](https://cloud-native.slack.com/archives/C088D8GSSSF)
  on the CNCF Slack and at our SIG meetings.

## Acknowledgments

Reaching v1 is a milestone for the whole Go Compile-Time Instrumentation SIG.
Thank you to the maintainers who drove the release through to stable, including
[Xabier Martinez](https://github.com/txabman42) (Cabify),
[Yi Yang](https://github.com/y1yang0) (Alibaba),
[Haibin Zhang](https://github.com/NameHaibinZhang) (Alibaba), and
[Dario Castañé](https://github.com/darccio) (Datadog), along with everyone who
contributed code, rules, documentation, and feedback.

A special thank-you to [Azhar Momin](https://github.com/amazingakai), who joined
the project through the
[LFX Mentorship program](https://mentorship.lfx.linuxfoundation.org/project/3e530f5c-12f3-4321-836a-39de799a4d15)
and has become one of its most active contributors and an approver.

---

## References

- [Original post on the OpenTelemetry blog](https://opentelemetry.io/blog/2026/go-compile-time-instrumentation-v1/) (2026-07-16)
- [opentelemetry-go-compile-instrumentation](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation) — the project on GitHub
- [otelc module](https://pkg.go.dev/go.opentelemetry.io/otelc) — `go.opentelemetry.io/otelc`
- [Supported libraries](https://opentelemetry.io/docs/zero-code/go/compile-time/supported-libraries/)
- [OpenTelemetry Registry](https://opentelemetry.io/ecosystem/registry/)
- [Original SIG announcement post](https://opentelemetry.io/blog/2025/go-compile-time-instrumentation/) (2025)
- [PR #10760](https://github.com/open-telemetry/opentelemetry.io/pull/10760) — the community blog post PR
