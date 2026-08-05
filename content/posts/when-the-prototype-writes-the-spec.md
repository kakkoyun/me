---
title: "When the prototype writes the spec"
description: "OpenTelemetry's reference implementation was slated to land two weeks before work began in every other language. That order has consequences, and seven years later the project is still installing the gate it should have built in 2019."
date: 2026-08-06T00:00:00Z
publishDate: 2026-08-06T00:00:00Z
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
showToc: true
tocOpen: false
promote: false
---

OpenTelemetry's reference implementation was slated to land on April 24, 2019. It was Java. Work in every other language was scheduled to begin two weeks after that.[^1]

I think about that timeline a lot, because I work on tracer libraries for a living, and the order in which a multi-language SDK gets built keeps mattering more than the documented process suggests.

You can call this pattern "PoC first, RFC later." That's what we tell ourselves we're doing. In practice it tends to slide into "PoC ships, RFC never," and then six other languages spend the next year matching whatever the first implementation already did. There's a less-messy way, though, and I want to write down what I think it looks like.

## What "first" looks like in OpenTelemetry

When the merger was announced in March 2019, the bootstrap committee handed the details of the API and reference implementation to a small technical committee.[^2] What came out was Java. The prototype was scheduled for April 24, and work began in all the other languages on May 8.[^1] By September the project was aiming for parity with existing projects in C#, Go, Java, Node.js, and Python.[^1]

A first draft of the cross-language specification was on the schedule too, due the same day work began in every language.[^1] Two weeks isn't enough time for a multi-language working group to sit down, look at the prototype, and ask "okay, but how does this map to Go's `context.Context` and Python's `contextvars` and JavaScript's `AsyncLocalStorage`?" Those conversations happened later, in parallel with implementations, and a fair amount of what shipped in 2019 reflected what was natural to write in Java in 2019. That's how the calendar shook out.

Seven years later, the constraints of that early shape still leak. Java's thread-local context model is the cleanest case. Python had to graft OTel context onto `contextvars`, and the language version mattered: `contextvars`, and asyncio's automatic per-task copy of them, only exist from Python 3.7 onward. There was a PyPI backport for 3.5 and 3.6, but it didn't integrate with asyncio, which is why the proposal to depend on it was closed unmerged; Python carried a thread-local fallback instead and eventually dropped both versions.[^3] Go's eBPF auto-instrumentation is the case that did get fixed, and the paper trail is the interesting part. The original design proposal noted that the implementation "correlates spans to the same trace if they are being executed by the same goroutine," with proper goroutine-tree tracking listed as future work. The tracking shipped about a year later. The design proposal still says "currently."[^4] None of these are bugs. They're impedance mismatches between a model and the languages it has to express itself in.

## The pattern, written down

If I tighten the screws, the pattern looks like this:

1. A team builds a prototype in one language to figure out what the design even is.
2. The prototype ships, because shipping is good and we have customers.
3. The features people use become the spec by accumulation.
4. When languages two through ten run into mismatches, the conversation defaults to "but the reference does X."
5. By the time anyone writes a formal cross-language spec, it's mostly archaeology.

Step one is genuinely useful. Trying to write a credible RFC for something you've never built is mostly creative fiction. The PoC tells you which corners of the design are sharp. The trouble is step three, where the things you wrote down to *learn* what the design could be become the thing the design *is*, mostly because nobody scheduled the meeting to decide otherwise.

I keep finding myself in step four. The specifics usually belong to an employer rather than to me, so here is the pattern rather than the story. Someone reports that one language behaves differently from another. You go and read what the reference implementation does. Whatever you find there tends to settle it, because the other implementations already match it and moving all of them costs more than absorbing the difference. Nobody in that conversation chose the 2019 constraint. Everyone is working around a calendar.

## Rust wrote the gate down on purpose

Rust's RFC process is the case I keep returning to. It also does PoC-first. The difference is what happens *between* the PoC and "this is shipped." When an RFC is accepted, the implementation lives behind an unstable feature gate (`#![feature(...)]`) on the nightly channel. People use it. They report what's awkward. There's a separate, deliberate stabilization step where someone files a stabilization report and the team approves a final comment period. The feature doesn't become stable by accident; it becomes stable on purpose.[^5]

The PoC and the spec are decoupled by a flag and a vote. The flag is what gives you permission to revise the design without breaking anyone's production code. The vote is what forces you to actually look at the design before promising not to change it.

Most SDK projects don't have either of these things. The flag, maybe, in the form of "experimental" labels that nobody reads. The vote, almost never.

Rust did set out to solve this, and wrote down why. The contributor docs give the reasoning behind the feature gate directly: users must not "accidentally depend on that new feature," because otherwise it "would end up de facto stable and we'll not be able to make changes in it without breaking people's code." The same page adds a line I wish every SDK project would post on a wall: "Features do not gain tenure by being unstable and unchanged for long periods of time."[^5] Compilers probably got there first because shipping a breaking change is unusually catastrophic for them, but the mechanism travels. It gives the PoC somewhere to live that isn't your customers' code. Most multi-language SDK projects have nowhere to put a PoC, so it ends up in the customers' code by default.

## OTel's slow course correction

Here's the part I find genuinely encouraging. The OpenTelemetry Governance Committee announced a "stable by default" proposal in November 2025.[^6] The headline is that OTel distributions should ship stable behavior by default, and users should have to opt in to experimental features through a standardized mechanism. They explicitly want a "single, clear, and consistent set of criteria for stability that includes documentation, performance testing, benchmarks…" There's also mention of "epoch releases" so that downstream consumers can adopt changes on a cadence they can plan around.

That's, structurally, the same shape as the Rust nightly/stable split. It's also an admission that the original "let things stabilize through use" approach produced too many de-facto-stable-but-officially-experimental features that downstream vendors and instrumentation authors are now stuck with.

It's interesting to me that this is happening seven years in. The PoC-first instinct produced a usable observability standard faster than waiting for a complete spec would have. I don't think anyone regrets that. The cost is showing up now as a governance project to retroactively install the gate that Rust had from the start.

## Gate GA behind a flag and a second language

Most teams I've worked on don't have the scale to run a Rust-style RFC process, and I don't think they should. The takeaway I keep landing on is smaller:

If you're shipping a multi-language SDK, treat the first implementation as a prototype, and mean it. Put it behind a feature flag, or a clearly labeled unstable major version, or both. Decline to ship it to general availability until at least one other language has implemented against the spec rather than against the prototype's source.

This will be annoying. It slows the first language down, forces a documentation step that nobody wants to do, and surfaces the assumptions that don't translate before any customers are affected. I'd rather find those during the second implementation than during the seventh.

One thing has changed since 2019 that makes this cheaper than it used to be. The expensive part of the gate was always the second implementation: another team, another quarter. Coding agents have taken a bite out of that. A scratch implementation in a second language, generated from the spec alone, is an afternoon's work now, and its only job is to fail wherever the spec is vague. Then you throw it away. Simon Willison's caveat is the part worth keeping in view: writing code got cheap, but delivering *good* code did not, and the spec is the good part.[^7] The current enthusiasm for spec-driven development looks like a lot of people arriving at the same place from the other direction, and rediscovering, as Birgitta Böckeler found, "the pitfalls and challenges of writing an unambiguous and complete specification."[^8]

I'm not certain about any of this. I'd be curious whether anyone reading this has watched a project actually hold that GA gate, and what it cost them in time-to-market versus what it bought them in coherence later. The Rust crowd has the only example I know of where the gate worked at scale, and Rust is unusual in a lot of ways. If you've seen something closer to home, I want to hear about it.

## References

[^1]: ["A Roadmap to Convergence" — Ted Young, OpenTracing on Medium (April 2019)](https://medium.com/opentracing/a-roadmap-to-convergence-b074e5815289). The scheduled April 24, 2019 Java reference implementation, the May 8, 2019 cross-language kickoff, and the September 2019 target of parity with the existing projects for C#, Go, Java, Node.js, and Python.

[^2]: [Ben Sigelman, "Merging OpenTracing and OpenCensus: Goals and Non-Goals" — Medium (March 28, 2019)](https://medium.com/opentracing/merging-opentracing-and-opencensus-f0fe9c7ca6f0). The March 2019 merger announcement by the projects' joint bootstrap committee.

[^3]: [`opentelemetry-python` issue #71 — asyncio context propagation in Python 3.5/3.6](https://github.com/open-telemetry/opentelemetry-python/issues/71) documents the version-dependent behavior. [PR #101](https://github.com/open-telemetry/opentelemetry-python/pull/101) is the proposal to depend on the `contextvars` PyPI backport; it was closed unmerged, with reviewers pointing out that the backport does not integrate with `asyncio`.

[^4]: [`opentelemetry-go-instrumentation` — Context Propagation design proposal](https://github.com/open-telemetry/opentelemetry-go-instrumentation/blob/main/docs/design/context-propagation.md), originally written in 2022. Cross-goroutine context propagation shipped in [PR #118](https://github.com/open-telemetry/opentelemetry-go-instrumentation/pull/118), merged August 2023. The proposal has had no content revision since; as of August 2026 it still describes the goroutine-only behavior as current.

[^5]: The [`rustc` dev guide on implementing new features](https://rustc-dev-guide.rust-lang.org/implementing-new-features.html) covers the unstable feature-gate model (`#![feature(...)]`) on the nightly channel, and the [stabilization guide](https://rustc-dev-guide.rust-lang.org/stabilization-guide.html) covers the stabilization workflow via a stabilization report and `@rfcbot fcp merge` → final comment period. Both quoted passages are from the *Stability* section of the first page. See also the [Rust RFCs README](https://github.com/rust-lang/rfcs) for the acceptance side of the process.

[^6]: ["Evolving OpenTelemetry's Stabilization and Release Practices" — OpenTelemetry Governance Committee, OpenTelemetry Blog (November 7, 2025)](https://opentelemetry.io/blog/2025/stability-proposal-announcement/). The "stable by default" proposal, opt-in mechanisms for experimental features, and the "epoch releases" idea.

[^7]: [Simon Willison, "Writing code is cheap now" — Agentic Engineering Patterns (February 2026)](https://simonwillison.net/guides/agentic-engineering-patterns/code-is-cheap/). Both the cost drop and the caveat that "delivering *good* code remains significantly more expensive than that."

[^8]: [Birgitta Böckeler, "Understanding Spec-Driven-Development: Kiro, spec-kit, and Tessl" — martinfowler.com (October 15, 2025)](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html). A hands-on survey of three spec-driven development tools, including the observation about writing unambiguous and complete specifications.
