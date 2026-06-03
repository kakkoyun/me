---
title: "Mentorship in Open Source — Part 3: Stewardship Inside OpenTelemetry"
description: "Closing the series with a live example — what mentorship looks like inside the OpenTelemetry project today, and why it's the mechanism that turns dependency management into stewardship."
date: 2026-06-05T00:00:00Z
publishDate: 2026-06-05T00:00:00Z
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
  image: /uploads/bloomberg-engineering-logo.png
  alt: Bloomberg Engineering logo
  caption: Bloomberg Engineering — whose CNCF piece on sustaining OpenTelemetry frames this post.
---

[The first post in this thread](/posts/mentorship-in-open-source/) was about why I keep saying yes to mentorship. [The second](/posts/mentorship-in-open-source-part-2-mentee-playbook/) was the playbook for mentees. This one is for the people on the other side of the table: the maintainers, the SIG leads, the engineers in companies that *depend on* a project and are starting to wonder whether depending on it's enough.

The frame I'm borrowing comes from a piece my colleagues at Bloomberg published with the CNCF in March: *[Sustaining OpenTelemetry: Moving from Dependency Management to Stewardship](https://www.cncf.io/blog/2026/03/31/sustaining-opentelemetry-moving-from-dependency-management-to-stewardship/)* (also on [Bloomberg's company stories](https://www.bloomberg.com/company/stories/sustaining-opentelemetry-cncf-moving-from-dependency-management-to-stewardship/)). The phrase has stuck with me. It names something I've been trying to articulate for years, and gives me a concrete vocabulary for talking about what mentorship is *for* inside a project the size of [OpenTelemetry](https://opentelemetry.io/).

## From dependency management to stewardship

Most companies use open source the same way they use electricity. {{< sidenote side="alternate" >}}You don't think about the grid until the lights go out.{{< /sidenote >}} You depend on it, you patch when it breaks, you grumble when an upgrade is painful, you upstream a fix when you absolutely have to. That's *dependency management*: a relationship in which the project is something you consume.

Stewardship is the opposite stance. You don't just consume the project; you take responsibility for the version of it that exists ten years from now. You pay for that version not just with code but with **time spent growing the people who will maintain it**. {{< sidenote >}}This is the part most "open-source strategy" decks omit. Code contributions are the easy half.{{< /sidenote >}}

The Bloomberg piece is making this case at the level of an organization. I want to make it at the level of a single SIG meeting.

## A glimpse from the SIG room

In [my field notes from OTel Unplugged EU 2026](/posts/otel-unplugged-eu-2026/#the-maintainer-crisis), the maintainer crisis came up in at least three rooms:

> "Not enough maintainers, too many PRs, codeowners disappearing. The JavaScript {{< tooltip term="SIG" >}}Special Interest Group — OpenTelemetry's organizational unit, roughly one per language or component (e.g. SIG Go, SIG JavaScript, SIG Collector).{{< /tooltip >}} has an automated script to move inactive maintainers to emeritus after three months. […] Some SIGs have tried a buddy/mentor system for onboarding new contributors — it helps, but it doesn't scale across all SIGs when the existing maintainers barely have time to review PRs."

And the line that stuck with me from those rooms:

> "Maintainership is privilege AND responsibility."

That tension (privilege, responsibility, not enough hours) is the texture of stewardship in practice. Mentorship is the mechanism by which a project produces *more* maintainers, not just more PRs. {{< sidenote side="alternate" >}}This is why I keep saying that the work is unglamorous. It does not show up in your release notes. It shows up two cohorts later, when the person you mentored opens a PR you would have had to write yourself.{{< /sidenote >}}

## Where mentorship plugs in

OpenTelemetry's contribution surface is enormous: protocol specs, language SDKs, the Collector, instrumentation libraries, semantic conventions, and an [exhaustive list of SIGs](https://github.com/open-telemetry/community#special-interest-groups). New contributors look at that surface and freeze. Maintainers look at it and triage by exhaustion.

Structured mentorship ([LFX](https://lfx.linuxfoundation.org/tools/mentorship/), [GSoC](https://summerofcode.withgoogle.com/), [Outreachy](https://www.outreachy.org/)) works because it converts that two-way frozenness into a contract. The mentee gets a scoped problem, a stipend, and a guaranteed reviewer. The SIG gets a contributor whose entire job for 12 weeks is to make their problem smaller. Both sides agree to spend time on each other.

What I've seen work, and what I've seen fail:

### What works

- **Tying mentorship slots to SIG roadmap items.** The strongest LFX projects I've mentored were ones a SIG genuinely wanted done. The mentee's work landed in a release. The mentee got reviewers who were already invested.
- **Pairing every mentee with two mentors.** One technical, one navigational. The technical mentor reviews code; the navigational mentor explains why a particular working group meets on Tuesdays and how to ask a question without it sounding like a bug report.
- **Promoting good mentees into reviewers, not just contributors.** The fastest way to grow your maintainer pool is to give the people you've already mentored a reviewer bit before they think they're ready. {{< sidenote >}}They are always more ready than they think.{{< /sidenote >}}

### What doesn't

- **Treating LFX as a free-labor faucet.** A mentee is not a contractor. If the SIG isn't prepared to spend a few hours a week on review, the mentorship will fail and the project will get a worse reputation in the next cohort.
- **Vague project descriptions.** "Improve the X SDK" is not a project. "Add the W3C Baggage propagator to the Foo SDK with conformance tests against the upstream test suite" is.
- **Disappearing reviewers.** I've watched cohorts stall because the listed mentor was on a release crunch and the buddy system never kicked in. Buddies need buddies.

## What I'm working on right now

A piece of this is concrete and currently happening. I work at DataDog APM on compile-time instrumentation, runtime profiling, and performance tooling for Go services. Most of that work happens in the open in [`Datadog/Orchestrion`](https://github.com/Datadog/Orchestrion), which is basically melting into the upstream [`opentelemetry-go-compile-instrumentation`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation) project. And as I write this, [Dario Castañé](https://github.com/darccio) and I are co-mentoring an LFX 2026 Jun–Aug cohort on that exact surface; the framing lives in [issue #446](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/issues/446), and [Part 1](/posts/mentorship-in-open-source/) and [Part 2](/posts/mentorship-in-open-source-part-2-mentee-playbook/) already covered the project itself, so I'll stop pitching it.

What matters more here is the lineage. Before DataDog, I co-mentored on [Thanos](https://github.com/thanos-io/thanos) for a few years through the early LFX Mentorship cohorts (back when the platform was still branded CommunityBridge): the [2020 Q2 query-limits project](https://github.com/cncf/mentoring/blob/main/programs/lfx-mentorship/2020/q2/selected_projects.md) and [2020 Q3–Q4 UI components](https://github.com/cncf/mentoring/blob/main/programs/lfx-mentorship/2020/q3-q4/selected_projects.md) with [Bartek Płotka](https://www.bwplotka.dev/) and [Prem Saraswat](https://github.com/onprem); [2021 Spring multi-tenancy](https://github.com/cncf/mentoring/blob/main/programs/lfx-mentorship/2021/01-Spring/README.md) with [@yashrsharma44](https://github.com/yashrsharma44); the [2021 Fall protobuf migration](https://github.com/cncf/mentoring/blob/main/programs/lfx-mentorship/2021/03-Fall/README.md) with [Lucas Servén Marín](https://github.com/squat) and [Giedrius Statkevičius](https://github.com/GiedriusS); plus a [GSoC 2021 Thanos TLS project](https://github.com/cncf/mentoring/blob/main/programs/summerofcode/2021.md). More recently on Prometheus: [`client_golang` instrumentation work in LFX 2024 Mar–May](https://github.com/cncf/mentoring/blob/main/programs/lfx-mentorship/2024/01-Mar-May/README.md) with [Arthur Sens](https://github.com/ArthurSens), and [`prometheus/test-infra` in LFX 2024 Sep–Nov](https://github.com/cncf/mentoring/blob/main/programs/lfx-mentorship/2024/03-Sep-Nov/README.md) with [Bryan Boreham](https://github.com/bboreham). Each was a different SIG, a different co-mentor, a different mentee picking up something that became a real piece of the project. They are all on [`cncf/mentoring`](https://github.com/cncf/mentoring) if you want to read the project framings up close. {{< sidenote >}}Bartek is the same maintainer I credited in [Part 1](/posts/mentorship-in-open-source/) for showing me what a maintainer relationship is supposed to feel like. He'd been my mentor on Thanos a year earlier; by 2020 we were co-mentoring together. That's the loop running once, on a five-year cycle.{{< /sidenote >}}

What sticks with me from those years isn't any single PR. Some of those mentees are now maintainers themselves. That's the loop closing: the thing Part 1 was really about.

This is what stewardship looks like, in the small. Not "we contribute back when we have to." Rather: *we own a piece of the upstream future, we use the program structures (LFX cohorts, GSoC slots, mentor pairings) to grow more people who can own it with us, and we plan for the version of the project that exists when we're not the ones running it anymore.*

## Why this is the hard part

Many ways exist to "support open source" that look great on a slide and produce little. Sponsorship dollars. Logos at conferences. PRs filed by an engineer who already had everything they needed to file the PR.

Mentorship is the one that produces compounding returns and almost no easy metrics. It's slow. It's lossy: most cohorts produce one strong maintainer-track contributor, not five. It does not show up in the release notes. It does not have a nice ROI graph. It will not survive the first round of cuts in a product-led quarter unless someone with budget authority decides it's a strategic choice.

And yet it's the mechanism. The reason the projects you depend on still exist in five years is that someone, somewhere, in 2024, mentored the person who will be on call the night your service crashes in 2030.

## Call to action — for maintainers and the companies they work for

If you maintain a CNCF project, or you work for a company that depends heavily on one, here is what I'd ask:

1. **List your project on the next [LFX cohort](https://mentorship.lfx.linuxfoundation.org/).** The intake portal is in [`cncf/mentoring`](https://github.com/cncf/mentoring). It takes a few hours to write up three good project ideas.
2. **Write project descriptions that name a real artifact.** Not "improve X." Name the file, the test suite, the missing feature, the open issue number.
3. **Commit reviewer time *before* the cohort starts.** Block the calendar. Tell the buddy. The mentee will know within two weeks whether the project is real or a slot to be ignored.
4. **Promote your strong mentees into reviewer roles.** The most consequential move a maintainer can make is making the next maintainer.
5. **If you're an engineering leader at a company that depends on the project, fund the time.** Stewardship that lives only on engineers' weekends is fragile. Make it part of someone's quarter, with a roadmap row and a name. {{< sidenote >}}This is, in part, what the [Bloomberg / CNCF piece](https://www.cncf.io/blog/2026/03/31/sustaining-opentelemetry-moving-from-dependency-management-to-stewardship/) is making the corporate case for. Steal their language. It works on executives.{{< /sidenote >}}

If you read this far and you're already doing this: drop me a line. I'd love to compare notes on what's working in your project and what isn't. The most useful thing the CNCF mentorship community has produced isn't the formal program structure; it's the back-channel of mentors comparing notes after a bad cohort. That's how the program gets better.

---

*This closes the series. [Part 1](/posts/mentorship-in-open-source/) was the why. [Part 2](/posts/mentorship-in-open-source-part-2-mentee-playbook/) was the mentee playbook. If any of the three landed for you, share it with the person you've been meaning to nudge into open source. That's the mechanism.*
