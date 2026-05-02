---
title: "Mentorship in Open Source — Part 3: Stewardship Inside OpenTelemetry"
description: "Closing the series with a live example — what mentorship looks like inside the OpenTelemetry project today, and why it's the mechanism that turns dependency management into stewardship."
date: 2026-05-16T00:00:00Z
publishDate: 2026-05-16T00:00:00Z
categories:
  - engineering
tags:
  - blog
  - mentorship
  - open-source
  - community
  - cncf
  - opentelemetry
  - stewardship
  - sig
  - maintainership
  - go
series:
  - Mentorship in Open Source
showToc: true
tocOpen: false
cover:
  image: /uploads/otel_unplugged_2026_crowd.jpeg
  alt: OTel Unplugged EU 2026 — community voting on session topics
  caption: OTel Unplugged EU 2026, Brussels. The room where most of these arguments actually happen.
---

This is the closing post of a small series on mentorship in open source. [Part 1](/posts/mentorship-in-open-source/) was about *why*. [Part 2](/posts/mentorship-in-open-source-part-2-mentee-playbook/) was the playbook for mentees. This one is for the people on the other side of the table: the maintainers, the SIG leads, the engineers in companies that *depend on* a project and are starting to wonder whether depending on it is enough.

The frame I'm borrowing comes from a piece my colleagues at Bloomberg published with the CNCF in March: *[Sustaining OpenTelemetry: Moving from Dependency Management to Stewardship](https://www.cncf.io/blog/2026/03/31/sustaining-opentelemetry-moving-from-dependency-management-to-stewardship/)* (also on [Bloomberg's company stories](https://www.bloomberg.com/company/stories/sustaining-opentelemetry-cncf-moving-from-dependency-management-to-stewardship/)). The phrase has stuck with me. It names something I've been trying to articulate for years — and gives me a concrete vocabulary for talking about what mentorship is actually *for* inside a project the size of [OpenTelemetry](https://opentelemetry.io/).

## From dependency management to stewardship

Most companies use open source the same way they use electricity. {{< sidenote side="alternate" >}}You don't think about the grid until the lights go out.{{< /sidenote >}} You depend on it, you patch when it breaks, you grumble when an upgrade is painful, you upstream a fix when you absolutely have to. That's *dependency management*: a relationship in which the project is something you consume.

Stewardship is the opposite stance. You don't just consume the project; you take responsibility for the version of it that exists ten years from now. You pay for that version not just with code but with **time spent growing the people who will maintain it**. {{< sidenote >}}This is the part most "open-source strategy" decks omit. Code contributions are the easy half.{{< /sidenote >}}

The Bloomberg piece is making this case at the level of an organization. I want to make it at the level of a single SIG meeting.

## A glimpse from the SIG room

In [my field notes from OTel Unplugged EU 2026](/posts/otel-unplugged-eu-2026/#the-maintainer-crisis), the maintainer crisis came up in at least three rooms:

> "Not enough maintainers, too many PRs, codeowners disappearing. The JavaScript {{< tooltip term="SIG" >}}Special Interest Group — OpenTelemetry's organizational unit, roughly one per language or component (e.g. SIG Go, SIG JavaScript, SIG Collector).{{< /tooltip >}} has an automated script to move inactive maintainers to emeritus after three months. […] Some SIGs have tried a buddy/mentor system for onboarding new contributors — it helps, but it doesn't scale across all SIGs when the existing maintainers barely have time to review PRs."

And the line that stuck with me from those rooms:

> "Maintainership is privilege AND responsibility."

That tension — privilege, responsibility, not enough hours — is the texture of stewardship in practice. Mentorship is the mechanism by which a project produces *more* maintainers, not just more PRs. {{< sidenote side="alternate" >}}This is why I keep saying that the work is unglamorous. It does not show up in your release notes. It shows up two cohorts later, when the person you mentored opens a PR you would have had to write yourself.{{< /sidenote >}}

## Where mentorship plugs in

OpenTelemetry's contribution surface is enormous: protocol specs, language SDKs, the Collector, instrumentation libraries, semantic conventions, and an [exhaustive list of SIGs](https://github.com/open-telemetry/community#special-interest-groups). New contributors look at that surface and freeze. Maintainers look at it and triage by exhaustion.

Structured mentorship — [LFX](https://lfx.linuxfoundation.org/tools/mentorship/), [GSoC](https://summerofcode.withgoogle.com/), [Outreachy](https://www.outreachy.org/) — works because it converts that two-way frozenness into a contract. The mentee gets a scoped problem, a stipend, and a guaranteed reviewer. The SIG gets a contributor whose entire job for 12 weeks is to make their problem smaller. Both sides agree to spend time on each other.

What I've seen work, and what I've seen fail:

### What works

- **Tying mentorship slots to SIG roadmap items.** The strongest LFX projects I've mentored were ones a SIG genuinely wanted done. The mentee's work landed in a release. The mentee got reviewers who were already invested.
- **Pairing every mentee with two mentors.** One technical, one navigational. The technical mentor reviews code; the navigational mentor explains why a particular working group meets on Tuesdays and how to ask a question without it sounding like a bug report.
- **Promoting good mentees into reviewers, not just contributors.** The fastest way to grow your maintainer pool is to give the people you've already mentored a reviewer bit before they think they're ready. {{< sidenote >}}They are always more ready than they think.{{< /sidenote >}}

### What doesn't

- **Treating LFX as a free-labor faucet.** A mentee is not a contractor. If the SIG isn't prepared to spend several hours a week on review, the mentorship will fail and the project will get a worse reputation in the next cohort.
- **Vague project descriptions.** "Improve the X SDK" is not a project. "Implement the W3C Baggage propagator for the Foo SDK with conformance tests against the upstream test suite" is.
- **Disappearing reviewers.** I've watched cohorts stall because the listed mentor was on a release crunch and the buddy system never kicked in. Buddies need buddies.

## What I'm working on right now

A piece of this is concrete and currently happening. I work at Datadog APM, on Go-for-Go: compile-time instrumentation, runtime profiling, and performance tooling for Go services. Most of that work happens in the open, across three repositories whose dependency-vs-stewardship tension is exactly the one this series is about:

- [**`open-telemetry/opentelemetry-go-compile-instrumentation`**](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation) — a prototype of compile-time instrumentation for Go. Upstream of any specific vendor.
- [**`Datadog/Orchestrion`**](https://github.com/Datadog/Orchestrion) — Datadog's source-based compile-time instrumentation tool for Go. Open source. The work that lands here informs the upstream prototype above.
- [**`Datadog/dd-trace-go`**](https://github.com/DataDog/dd-trace-go) — Datadog's Go APM tracer. The downstream consumer of much of the above.

These three are in active conversation with each other and with the OTel Go SIG. {{< sidenote side="alternate" >}}I'll be honest: figuring out the right shape of that conversation is *itself* the hard part of stewardship. Code is easy. The relationship is the work.{{< /sidenote >}} If you're a Go engineer who has ever wished that adding instrumentation to your code didn't require modifying it — there is room for you here. The full list of projects I'm in the middle of is on my [open source page](/open_source/).

This is what stewardship looks like, in the small. Not "we contribute back when we have to." Rather: *we own a piece of the upstream future, we use the program structures (LFX cohorts, GSoC slots, mentor pairings) to grow more people who can own it with us, and we plan for the version of the project that exists when we're not the ones running it anymore.*

## Why this is the hard part

There are many ways to "support open source" that look great on a slide and produce little. Sponsorship dollars. Logos at conferences. PRs filed by an engineer who already had everything they needed to file the PR.

Mentorship is the one that produces compounding returns and almost no easy metrics. It's slow. It's lossy — most cohorts produce one strong maintainer-track contributor, not five. It does not show up in the release notes. It does not have a nice ROI graph. It will not survive the first round of cuts in a product-led quarter unless someone with budget authority decides it's a strategic choice.

But it is the mechanism. The reason the projects you depend on still exist in five years is that someone, somewhere, in 2024, mentored the person who will be on call the night your service crashes in 2030.

## Call to action — for maintainers and the companies that employ them

If you maintain a CNCF project, or you work for a company that depends heavily on one, here is what I'd ask:

1. **List your project on the next [LFX cohort](https://mentorship.lfx.linuxfoundation.org/).** The intake portal is in [`cncf/mentoring`](https://github.com/cncf/mentoring). It takes a few hours to write up three good project ideas.
2. **Write project descriptions that name a real artifact.** Not "improve X." Name the file, the test suite, the missing feature, the open issue number.
3. **Commit reviewer time *before* the cohort starts.** Block the calendar. Tell the buddy. The mentee will know within two weeks whether the project is real or a slot to be ignored.
4. **Promote your strong mentees into reviewer roles.** The single highest-leverage move a maintainer can make is making the next maintainer.
5. **If you're an engineering leader at a company that depends on the project — fund the time.** Stewardship that lives only on engineers' weekends is fragile. Make it part of someone's quarter, with a roadmap row and a name. {{< sidenote >}}This is, in part, what the [Bloomberg / CNCF piece](https://www.cncf.io/blog/2026/03/31/sustaining-opentelemetry-moving-from-dependency-management-to-stewardship/) is making the corporate case for. Steal their language. It works on executives.{{< /sidenote >}}

If you read this far and you're already doing this — drop me a line. I'd love to compare notes on what's working in your project and what isn't. The most useful thing the CNCF mentorship community has produced isn't the formal program structure; it's the back-channel of mentors comparing notes after a bad cohort. That's how the program gets better.

---

*This closes the series. [Part 1](/posts/mentorship-in-open-source/) was the why. [Part 2](/posts/mentorship-in-open-source-part-2-mentee-playbook/) was the mentee playbook. If any of the three landed for you — share it with the person you've been meaning to nudge into open source. That's the mechanism.*
