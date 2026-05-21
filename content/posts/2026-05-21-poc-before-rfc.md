---
title: "PoC First, RFC Never"
description: "Multi-language SDKs keep shipping Java prototypes as cross-language specs. Here's why the PoC-as-spec pattern is so sticky — and what the pipeline should actually look like."
date: 2026-05-21T00:00:00Z
publishDate: 2026-05-21T00:00:00Z
slug: poc-first-rfc-never
categories:
  - engineering
tags:
  - process
  - sdk
  - rfc
  - cross-language
  - engineering-culture
draft: true
toc: true
---

There's a conversation that happens in every SDK team sooner or later. It goes something like this:

> "We found a problem with the timeout behavior. The semantics don't make sense for Python's async model."
>
> "Yeah, I know. But Java already shipped with the current behavior. That's what the spec says now."
>
> "The spec says that *because Java shipped it*, though."
>
> "Correct."

This is not a hypothetical. It's a pattern so familiar it barely registers as a problem anymore — which is exactly what makes it so insidious.

---

## The Allure of Prototype-First

Let me be clear upfront: **prototyping first is a good instinct.** Writing an RFC for something you don't fully understand is an exercise in confident fiction. You'll miss the hard cases, underspecify the edge conditions, and paper over the parts where the design breaks down — because you haven't tried to build it yet.

A PoC forces you to reckon with reality. It surfaces the awkward corners. It tells you whether your mental model of the problem was even approximately correct. It gives reviewers something concrete to react to rather than hand-waving in a document.

The Rust community figured this out. Their RFC process explicitly carves out space for prototypes: if the design space is unclear, *build something unstable first*, get feedback, then write the RFC that reflects what you actually learned. The prototype lives behind a feature flag. It informs the spec. It does not become the spec.

The distinction sounds subtle. In practice, it's everything.

---

## The Invisible Crossing

At some point during every PoC, something happens that nobody announces. The prototype stops being a question ("can this work?") and starts being an answer ("this is how it works"). The shift is gradual, almost imperceptible. A few people start relying on the behavior. Someone writes a test against it. Someone else asks "is this stable?" and the answer is a shrug that gets interpreted as a yes.

By the time the RFC conversation comes up, the PoC has been running in production — or at least in one language's SDK — for three months. The RFC now has a much harder job: it isn't designing a system, it's retroactively documenting one that already exists and has users.

That's a completely different document, written for a completely different reason, with a completely different outcome.

---

## Why Multi-Language SDKs Make This Catastrophic

For a backend service, prototype-as-spec is bad but recoverable. The codebase is in one place. A motivated team can refactor it. The "spec" and the "implementation" are colocated, and changing one changes the other.

For multi-language SDKs, the calculus is radically different. When you're shipping an observability tracer, an API client, or a developer platform library across Java, Python, Go, Ruby, .NET, PHP, and Node.js — a behavioral decision made in the first implementation isn't just a local choice. It becomes a cross-language contract that seven teams must independently implement and maintain forever.

The problem compounds because different languages have wildly different assumptions baked in:

- Java's type system encourages class hierarchies and checked exceptions. Its natural implementation of an error model looks nothing like idiomatic Go.
- Python's async ecosystem (asyncio, trio, anyio) makes certain timeout and cancellation semantics that are natural in Java actively harmful.
- Ruby's threading model means concurrency abstractions need careful rethinking, not mechanical translation.
- Go doesn't have optional fields in the same way. The "Java way" of passing nulls to indicate absent values simply doesn't map cleanly.

When a Java PoC becomes the spec, it doesn't just describe *behavior* — it encodes *Java's way of expressing* that behavior. And the encoding is rarely called out explicitly, because whoever wrote the Java code wasn't thinking in cross-language terms. They were solving the immediate problem in front of them.

The spec you get is not "this feature does X." It's "this feature does X in the way Java naturally wants to do X, with none of those assumptions documented, because they felt obvious."

---

## The Sunk Cost That Isn't

When implementation teams in other languages find problems — and they always find problems — the answer is almost always the same: "that's what Java does, and Java has already shipped."

This argument has surface-level coherence. You can't break existing users. You have a compatibility obligation. The path of least resistance is to implement the same behavior and move on.

But notice what's happening: the sunk cost isn't really technical. It's social and political. The Java team shipped a PoC. It acquired users. Now changing it requires coordination, deprecation notices, migration guides, and apologies — not because the behavior was *right*, but because it *shipped*. The irreversibility was created by the act of shipping, not by some inherent necessity of the design.

The RFC, had it come first, would have been a document on a PR. A comment saying "this doesn't work for Go's context model" would have cost an hour of revision. Instead, it costs a year of cross-language inconsistency and the occasional production incident.

---

## What "PoC First, RFC Later" Actually Means

The principle *should* work like this:

**1. Build the PoC in one language to understand the problem space.** This is non-negotiable and good. You cannot write a credible RFC for a feature you don't understand.

**2. Treat the PoC as evidence, not output.** The PoC answers: "Is this approach viable?" and "What did we learn?" It is not the implementation. It should probably be thrown away, or at minimum held at arm's length.

**3. Write the RFC that the PoC now lets you write.** This is the step that keeps getting skipped. The RFC should explicitly surface the assumptions uncovered during prototyping — *especially* the ones that felt obvious in the PoC language. What does this behavior mean in a language without checked exceptions? What happens in an async context? What's the contract when the underlying platform has different threading guarantees?

**4. Let the multi-language RFC drive the implementations.** Not the PoC. Not the Java version. The reviewed, cross-language-considered spec.

The PoC is the prerequisite for writing a good RFC. It is not a substitute for one.

---

## The RFC Nobody Writes

Here's the uncomfortable truth: the reason teams skip the RFC isn't laziness or bad intentions. It's that writing a *good* cross-language RFC is genuinely hard work. It requires thinking through implementations you haven't written yet, in languages whose idioms you may not know well. It requires predicting the awkward corners in Ruby or the async complications in Python from a standing start.

That difficulty is real. But the alternative — discovering all those awkward corners during implementation, after Java has already shipped — is not cheaper. It's just deferred and distributed. The cost gets paid in seven separate implementation teams independently discovering the same problems, arriving at seven slightly different solutions, and then spending months reconciling them.

The RFC is the hard work that makes everything else easier. Skipping it doesn't avoid the hard work. It just spreads it across the entire codebase.

---

## A Concrete Proposal

Here's what this looks like in practice:

**PoC phase** (timebox: 1–2 sprints):
- Single language, explicit "disposable" framing
- Goal: answer specific unknowns, not ship a feature
- Output: a writeup of what was learned, not the code itself

**RFC phase** (follows PoC immediately, before any shipping):
- Spec written with multi-language implementors in the room
- Explicitly calls out assumptions inherited from the PoC language
- "How does this map to Go?" is a first-class question, not an afterthought
- PoC code cited as evidence, not referenced as the canonical implementation

**Implementation phase**:
- Each language implements from the RFC, not from the PoC
- The first shipped language does not become the reference; the RFC is the reference
- Cross-language review before any language reaches GA

The key constraint: **no language ships to GA until the RFC exists.** The PoC language can reach beta or live behind a flag. Shipping to GA before the RFC creates the sunk cost. That's the gate that must hold.

---

## Taking the Principle at Its Word

Most engineering cultures already endorse the idea that RFCs should precede significant features. The problem is that "PoC first" gets treated as an exception — a pragmatic shortcut for building understanding — and then the exception quietly becomes the rule.

It doesn't have to work this way. The insight from the Rust community's process is that these two ideas aren't in tension: *you can prototype first and still have a rigorous RFC process.* You just have to mean it when you say the PoC is a proof of concept, not a specification.

When someone asks why we're writing an RFC after the PoC already exists, the answer is simple: the PoC proved we *can* build this. The RFC is how we decide what we *should* build — in a way that works across seven languages, not just the one where it felt obvious.

A PoC that becomes the spec isn't a PoC that succeeded. It's an RFC that never got written.
