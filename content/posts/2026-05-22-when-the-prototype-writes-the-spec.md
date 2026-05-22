---
title: "When the prototype writes the spec"
description: "OpenTelemetry's first reference implementation shipped two weeks before the cross-language working groups started. That order has consequences, and seven years later the project is still installing the gate it should have built in 2019."
date: 2026-05-22T00:00:00Z
publishDate: 2026-05-22T00:00:00Z
slug: when-the-prototype-writes-the-spec
categories:
  - engineering
tags:
  - process
  - sdk
  - observability
  - opentelemetry
  - rfc
  - cross-language
  - blog
draft: true
showToc: true
tocOpen: false
---

OpenTelemetry's first reference implementation shipped on April 24, 2019. It was Java. The official cross-language working groups started two weeks after that.[^1]

I think about that timeline a lot, because I work on tracer libraries for a living, and the order in which a multi-language SDK gets built keeps mattering more than the documented process suggests.

You can call this pattern "PoC first, RFC later." That's what we tell ourselves we're doing. In practice it tends to slide into "PoC ships, RFC never," and then six other languages spend the next year matching whatever the first implementation already did. I'd like to think there's a clean way out of this. I'm not sure there is. There's a less-messy way, though, and I want to write down what I think it looks like.

## What "first" looks like in OpenTelemetry

When OTel was announced in March 2019, the seed governance committee had to deliver something that worked. They picked Java. The Java prototype landed on April 24, and cross-language work formally kicked off on May 8.[^1] By September the project was aiming for production parity in C#, Go, Java, Node.js, and Python.[^2]

Two weeks isn't enough time for a multi-language working group to sit down, look at the prototype, and ask "okay, but how does this map to Go's `context.Context` and Python's `contextvars` and JavaScript's `AsyncLocalStorage`?" Those conversations happened later, in parallel with implementations, and a fair amount of what shipped in 2019 reflected what was natural to write in Java in 2019. That isn't anyone's fault. It's how the calendar shook out.

Seven years later, the constraints of that early shape still leak. Java's thread-local context model is the cleanest case. Python had to graft OTel context onto `contextvars`, and the language version mattered: `asyncio.Task` only auto-copies contextvars from 3.7 onward, which produced a long tail of subtly-broken async traces.[^3] Go's eBPF-based auto-instrumentation explicitly notes the current design "correlates spans to the same trace if they are being executed by the same goroutine," with a TODO to track the goroutine tree properly later.[^4] None of these are bugs. They're impedance mismatches between a model and the languages it has to express itself in.

## The pattern, written down

If I tighten the screws, the pattern looks like this:

1. A team builds a prototype in one language to figure out what the design even is.
2. The prototype ships, because shipping is good and we have customers.
3. The features people use become the spec by accumulation.
4. When languages two through ten run into mismatches, the conversation defaults to "but the reference does X."
5. By the time anyone writes a formal cross-language spec, it's mostly archaeology.

Step one is genuinely useful. Trying to write a credible RFC for something you've never built is mostly creative fiction. The PoC tells you which corners of the design are sharp. The trouble is step three, where the things you wrote down to *learn* what the design could be become the thing the design *is*, mostly because nobody scheduled the meeting to decide otherwise.

I keep finding myself in step four, defending or apologizing for a decision made by a calendar in 2019.

## Rust got this right by accident

Rust's RFC process is the case I keep returning to. It also does PoC-first. The difference is what happens *between* the PoC and "this is shipped." When an RFC is accepted, the implementation lives behind an unstable feature gate (`#![feature(...)]`) on the nightly channel. People use it. They report what's awkward. There's a separate, deliberate stabilization step where someone files a stabilization report and the team approves a final comment period. The feature doesn't become stable by accident; it becomes stable on purpose.[^5]

The PoC and the spec are decoupled by a flag and a vote. The flag is what gives you permission to revise the design without breaking anyone's production code. The vote is what forces you to actually look at the design before promising not to change it.

Most SDK projects don't have either of these things. The flag, maybe, in the form of "experimental" labels that nobody reads. The vote, almost never.

I don't think Rust set out to solve "PoC writes the spec" specifically. They got a flag-and-vote model partly because compilers shipping breaking changes is unusually catastrophic, and partly because the team that wrote the process knew language design has a longer half-life than most software. But the result is a process where the PoC has somewhere to live that isn't your customers' code. Most multi-language SDK projects have nowhere to put a PoC, so it ends up in the customers' code by default.

## OTel's slow course correction

Here's the part I find genuinely encouraging. The OpenTelemetry Governance Committee announced a "stable by default" proposal in 2025.[^6] The headline is that OTel distributions should ship stable behavior by default, and users should have to opt in to experimental features through a standardized mechanism. They explicitly want a "single, clear, and consistent set of criteria for stability that includes documentation, performance testing, benchmarks." There's also mention of "epoch releases" so that downstream consumers can adopt changes on a cadence they can plan around.

That's, structurally, the same shape as the Rust nightly/stable split. It's also an admission that the original "let things stabilize through use" approach produced too many de-facto-stable-but-officially-experimental features that downstream vendors and instrumentation authors are now stuck with.

It's interesting to me that this is happening seven years in. The PoC-first instinct produced a usable observability standard faster than waiting for a complete spec would have. I don't think anyone regrets that. The cost is showing up now as a governance project to retroactively install the gate that Rust had from the start.

## So what do we do

Most teams I've worked on don't have the scale to run a Rust-style RFC process, and I don't think they should. The takeaway I keep landing on is smaller:

If you're shipping a multi-language SDK, treat the first implementation as a prototype, and mean it. Put it behind a feature flag, or a clearly-labeled unstable major version, or both. Decline to ship it to general availability until at least one other language has implemented against the spec rather than against the prototype's source.

This will be annoying. It slows the first language down, forces a documentation step that nobody wants to do, and surfaces the assumptions that don't translate before any customers are affected. I'd rather find those during the second implementation than during the seventh.

I'm not certain about any of this. I'd be curious whether anyone reading this has watched a project actually hold that GA gate, and what it cost them in time-to-market versus what it bought them in coherence later. The Rust crowd has the only example I know of where the gate worked at scale, and Rust is unusual in a lot of ways. If you've seen something closer to home, I want to hear about it.

## References

[^1]: ["A Roadmap to Convergence" — Ted Young, OpenTracing on Medium (April 2019)](https://medium.com/opentracing/a-roadmap-to-convergence-b074e5815289). Java reference implementation date (April 24, 2019) and the May 8, 2019 cross-language kickoff.

[^2]: ["OpenTelemetry: The Merger of OpenCensus and OpenTracing" — Google Open Source Blog (May 2019)](https://opensource.googleblog.com/2019/05/opentelemetry-merger-of-opencensus-and.html). Initial seed governance committee and the September 2019 parity target for C#, Go, Java, Node.js, and Python.

[^3]: [`opentelemetry-python` issue #71 — asyncio context propagation in Python 3.5/3.6](https://github.com/open-telemetry/opentelemetry-python/issues/71). Historical record of the contextvars/asyncio integration gap and the version-dependent behavior.

[^4]: [`opentelemetry-go-instrumentation` — Context Propagation design doc](https://github.com/open-telemetry/opentelemetry-go-instrumentation/blob/main/docs/design/context-propagation.md). The current goroutine-tree limitation in eBPF auto-instrumentation, including the TODO for proper tree tracking.

[^5]: [Rust RFCs — `rust-lang/rfcs` repository README](https://github.com/rust-lang/rfcs). The RFC process, the use of unstable feature flags (`#![feature(...)]`) on the nightly channel, and the stabilization workflow via final comment period.

[^6]: ["Evolving OpenTelemetry's Stabilization and Release Practices" — OpenTelemetry Blog (2025)](https://opentelemetry.io/blog/2025/stability-proposal-announcement/). The Governance Committee's "stable by default" proposal, opt-in mechanisms for experimental features, and the "epoch releases" idea.
