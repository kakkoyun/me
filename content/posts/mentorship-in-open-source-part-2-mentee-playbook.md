---
title: "Mentorship in Open Source — Part 2: The Mentee Playbook"
description: "A practical guide to getting into open-source through structured mentorship — LFX, GSoC, Outreachy, and GoBridge. What works, what doesn't, and how to write a proposal that gets picked."
date: 2026-05-29T00:00:00Z
publishDate: 2026-05-29T00:00:00Z
categories:
  - blogmentation
tags:
  - blog
  - mentorship
  - open-source
  - community
  - cncf
  - lfx
  - gsoc
  - outreachy
  - gobridge
  - career
series:
  - Mentorship in Open Source
showToc: true
tocOpen: false
cover:
  image: /uploads/lfx-mentorship.svg
  alt: CNCF LFX Mentorship logo
  caption: The CNCF LFX Mentorship program — one of the four doors this post is about.
---

[Last time](/posts/mentorship-in-open-source/) I wrote about why I keep saying yes to open-source mentorship. This post is the *how*: specifically, how to be a mentee in 2026.

I've spent the last few years on the mentor side of CNCF {{< tooltip term="LFX" >}}LFX Mentorship — the Linux Foundation's structured mentorship program. Cohorts run quarterly, projects are scoped to ~12 weeks, and mentees receive a stipend.{{< /tooltip >}}, [Google Summer of Code](https://summerofcode.withgoogle.com/) ({{< tooltip term="GSoC" >}}A Google-funded program where students contribute to open-source projects over the summer, paired with mentors from those projects.{{< /tooltip >}}), and [GoBridge](https://gobridge.org/), mostly through [Thanos](https://github.com/thanos-io/thanos), [Prometheus](https://github.com/prometheus/prometheus), and now various [OpenTelemetry](https://github.com/open-telemetry) projects. Every cohort I've run, the same questions keep coming up from people who *want* to apply but don't know how to start.

This is the post I wish I could send those folks.

## Who this is for

You've heard about open-source mentorship programs and you want in. You might be:

- A student looking for a structured summer project (GSoC's bullseye).
- A working engineer wanting to break into a CNCF or {{< tooltip term="OSS" >}}Open-source software.{{< /tooltip >}} community you respect (LFX is your friend).
- An engineer from a background under-represented in tech (Outreachy is built for you).
- Someone who's tried "just contribute to open source" and bounced off the gravitational well of unread Slack channels (you want a structured program with a mentor whose job it is to talk to you).

If any of those is you, keep reading.

## Who this is not for

Before you spend a weekend writing a proposal, please read the program's eligibility documentation carefully. For LFX, that's [`docs.linuxfoundation.org/lfx/mentorship/mentees`](https://docs.linuxfoundation.org/lfx/mentorship/mentees). Each program has its own version, and they are gold mines: eligibility, expectations, time commitment, conflict-of-interest rules, how the stipend works. Outreachy's [eligibility page](https://www.outreachy.org/apply/eligibility/) is written for a specific reason and is worth reading slowly. Skipping this step is the single biggest reason proposals never reach a mentor.

Beyond the eligibility check, three patterns make me say "please don't apply this cohort."

If you can scope the work, set up the dev environment, and ship the first milestone in two weekends by yourself, you don't need a mentor — and someone with less experience does. These programs exist to help people get into open source who otherwise can't break in. Taking a slot to add a stipend and a credential to your CV when you could have just opened the PRs yourself is taking it from someone who needs it more. {{< sidenote >}}Not hypothetical. I have rejected proposals from clearly capable engineers and felt good about it, because the next in the queue came from someone who needed the structure.{{< /sidenote >}}

If you have exam season halfway through the cohort, an internship that overlaps, or this is the third thing on your list behind two more important commitments: don't apply this round. Apply next time. A part-time mentee is worse than no mentee, because the mentor's hours are already committed and now they're spent waiting for messages that don't come. Mentors do this for free, in our personal time, on top of day jobs. Wasted mentor time is the failure mode we feel most. Plenty of other people are ready to commit fully; let them have the slot.

And if your goal is a CV line, please pick a different path. "LFX mentee" looks good on a resume; "LFX mentee who became a maintainer of $project" looks much better, and only one of those two requires you to still be around three months after the program ends. If the line on the CV is the point, mentorship is not the cheapest way to get it.

The mentorship is about helping and enabling. If you fit, apply enthusiastically. If you don't, apply later, or apply somewhere else.

## The four programs

I've personally mentored through three of these: LFX, GSoC, and GoBridge. Outreachy I include because it's the door I most want under-represented contributors to know about; the Outreachy section below is description from the outside, not first-hand experience. There are more programs out there — these are the ones I can speak to.

### CNCF LFX Mentorship

A structured cohort-based program run by the Linux Foundation. Each project is scoped for one cohort (~12 weeks), assigned 1–2 mentors, and pays a stipend. There are multiple cohorts per year; the [active terms page](https://mentorship.lfx.linuxfoundation.org/) lists what's open right now, and the project list lives in the [`cncf/mentoring`](https://github.com/cncf/mentoring) repo under `programs/lfx-mentorship/`. The structure rewards reading: each project has a description, required skills, mentor names, and (usually) example issues. Every mentor on LFX has agreed to commit a meaningful chunk of time; that's a contract you don't get from "show up in the GitHub issues."

### Google Summer of Code

Google's long-running OSS internship. Originally student-only; for a few years now it's been open to "beginners to open source," not just students. Applications open in spring, work happens over summer. Each participating org publishes its own ideas list, and CNCF orgs aggregate theirs in [`cncf/mentoring`](https://github.com/cncf/mentoring/tree/main/programs/summerofcode). GSoC has the strongest "first-time mentee" track record I've seen: the structure is forgiving enough that someone with rough Git fundamentals can still ship something real by August.

### Outreachy

A program for people from groups traditionally under-represented in tech, including those affected by systemic bias. Two cohorts per year (May–August and December–March). The intake is more rigorous than the others: there's a contribution period before the formal proposal, and it's [run from outreachy.org directly](https://www.outreachy.org/). Outreachy has the lowest tolerance for the "open-source as boys' club" failure mode of any program I've seen. If you've felt locked out of OSS communities, this is the door.

### GoBridge

Less structured than the above. [GoBridge](https://gobridge.org/) runs workshops, scholarships, and mentor pairings focused on the Go community. I list it because not every door is a 12-week cohort. Sometimes a one-week workshop or a 1:1 office-hours pairing is exactly the right starting size. {{< sidenote >}}If you've seen references to **CommunityBridge** in older blog posts or my About page, that's the platform CNCF LFX Mentorship used to run on; the Linux Foundation rebranded it to LFX Mentorship around 2020. Same plumbing, different name.{{< /sidenote >}}

## What I look for in a proposal

Most proposals get rejected for the same reasons. Most accepted proposals share the same shape. Here's what I look for as a mentor — your mileage may vary, but ask any LFX/GSoC mentor and you'll hear most of this.

- [ ] **You have read the project's recent issues, PRs, and design docs.** Not all of them — but enough that you can name two open issues by number and explain why they matter.
- [ ] **Your scope fits in 12 weeks.** Not 12 weeks of full-time senior-engineer effort — 12 weeks of *your* effort, with reasonable assumptions about ramp-up. {{< sidenote side="alternate" >}}A great heuristic: if you can't draft a one-paragraph milestone for week 4 *right now*, your scope is too vague.{{< /sidenote >}}
- [ ] **You've made one small PR already.** Even a typo fix in the README. It tells me you can find your way around the codebase, run the tests, and follow the contribution guide.
- [ ] **You've named the trade-offs.** Every interesting project has at least one. If your proposal reads like a feature spec with no tensions, you haven't engaged with the problem deeply enough.
- [ ] **You've written the proposal *as a collaboration plan*, not a job application.** I want to know *how we're going to work together*, not how impressive you are.

That last bullet is the one I see violated most often. A mentorship proposal is not a CV. It's a draft of the conversation we're going to have for the next three months.

One more thing worth saying clearly, now that the agentic coding tools are everywhere: use AI to do reconnaissance in the codebase, summarize design docs, get up to speed on the project, learn unfamiliar concepts. All fine. Don't use it to write the proposal. We will ask questions in selection. We hold you accountable for the understanding the proposal claims. A proposal you can't defend in a thirty-minute conversation won't be picked, and the AI-drafted ones are usually obvious within two.

## What makes a good first contribution

If you're not yet at proposal stage and just want to do *something*, start here.

1. **Pick the project before the program.** Find a CNCF or Go project whose docs you've actually read for fun. Whose maintainers you've watched on a podcast or at a meet-up. {{< sidenote >}}If no project meets that bar yet, your first task is to find one. Start with the [CNCF Landscape](https://landscape.cncf.io/) and look at which projects are listed in the current LFX, GSoC, or Outreachy cohorts — that tells you who is actively running mentorships. Even better: some of the best applicants I've seen reached out to a project they loved and asked the maintainers whether they'd consider running a cohort. Brilliant move, every time.{{< /sidenote >}} Programs are the scaffolding. The project is the building.
2. **Read the issue tracker for an hour.** Not to pick an issue — to understand the *vocabulary*. What does "OBI" mean to this project? What's a "sidecar" here? Who's `@nickname` and why do they have opinions?
3. **Find a "good first issue" or a `help-wanted` that hasn't been touched in a few weeks.** If it's been claimed and abandoned, comment asking if you can pick it up. If it's untouched, comment with your understanding of the problem and a sketch of an approach *before* you write code.
4. **Submit a small, working PR.** Tests included. Description that explains the *why*, not the *what*. Ask for review explicitly.
5. **Stay in the thread.** This is the most under-rated step. Half of first-time contributors disappear after their PR gets review comments. The half that stay through one round of revisions become contributors.

## The five mistakes I see most

I've watched these patterns play out across cohorts. They're easy traps, not character flaws. Knowing about them will not stop you from falling into one of them, but it might shorten the climb out.

### 1. Picking a project you're not actually curious about

The single best predictor of whether a mentee finishes their project is whether they *want to use the thing they're building*. If your project is "add a feature to a database I've never touched," you will run out of motivation by week 6. If your project is "make this tool I rely on do the thing I keep wishing it did," you will finish.

### 2. Scoping too big

Almost every first-draft proposal I review is 2–3× too ambitious. {{< sidenote side="alternate" >}}I've done this myself. As a mentor I now reflexively halve my mentees' first-draft scopes before we publish.{{< /sidenote >}} The tell is when you can describe your "milestones" only as topic areas: *"week 1–4: research; week 5–8: implementation; week 9–12: polish."* Real milestones name the artifact. *"By end of week 4, the parser handles X; PR open for early review."*

### 3. Ghosting

If you don't hear from your mentor for a week, send a message. If you don't hear from yourself for a week (that is, if you've gone quiet on your own project), send a message anyway. *"I'm stuck"* is always a better message than no message. Mentors are not graders; we cannot help you if we don't know what's happening.

### 4. Treating reviews as criticism

I once spent twenty minutes writing a careful review comment explaining why a particular abstraction was the wrong fit, and got back a one-line *"ok will fix"*. Three weeks later the mentee told me they'd been demoralized by that review. Reviews are the actual product of mentorship. The PR is the medium; the review is the message. If a review confuses you, ask. If it stings, sit with it for a day, then ask. The mentor who took twenty minutes to write a careful review wants you to push back when they're wrong.

### 5. Disappearing after the cohort ends

This one is on both sides — mentors do it too. The cohort has a hard end date. The relationship doesn't have to.

The mentees I'm proudest of are the ones who kept poking me with PR links and SIG-meeting questions for *years* after their LFX project closed. The ones I'm least proud of are the ones who disappeared the day the certificate landed and resurfaced two years later asking for a reference letter for a job application. {{< sidenote side="alternate" >}}I write the reference letter anyway. But I notice.{{< /sidenote >}}

Don't be that person. Don't be selfish. We do this in the hope that the next generation of maintainers comes from somewhere, which requires you to stick around long enough to *become* the next generation. The official program is a starter loan; the real currency is the ongoing connection. Repay it by being present.

## Concrete examples (from my own cohorts)

I've mentored on Thanos, Prometheus, and various OpenTelemetry projects through these programs. The most concrete current example, while this post goes live: [Dario Castañé](https://github.com/darccio) and I are about to start co-mentoring [Expanding Go Compile-Time Instrumentation Support and Improving otelc Tooling](https://github.com/cncf/mentoring/blob/main/programs/lfx-mentorship/2026/02-Jun-Aug/README.md#expanding-go-compile-time-instrumentation-support-and-improving-otelc-tooling) in the LFX 2026 Jun–Aug cohort. The framing lives in [`opentelemetry-go-compile-instrumentation#446`](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/issues/446). Applications closed before this post published; we're choosing a mentee now, with the cohort itself starting in June. The next cohort's listings tend to land in [`cncf/mentoring`](https://github.com/cncf/mentoring) a few weeks before each term opens, so the next round to apply to will go up there. {{< sidenote side="alternate" >}}I'll add older mentee credits and merged-PR links here as I get clearance from the folks involved. Naming people in a blog post without asking is exactly the kind of thing I'm trying to teach mentees not to do.{{< /sidenote >}}

A handful of patterns that show up across cohorts:

- The strongest proposals always referenced specific open issues by number, not abstract feature ideas.
- The mentees who finished early *all* did one small "warm-up" PR before the cohort officially started.
- The mentees who became maintainers were the ones who kept showing up to community meetings *during* their project, then kept showing up after it closed.

If you're a former mentee of mine and you'd like me to credit your work in a follow-up post, drop me a line — happy to.

## Call to action — for mentees

If you're thinking about applying:

1. **Pick a current cohort.** Start with [`cncf/mentoring`](https://github.com/cncf/mentoring). For LFX, the [active terms page](https://mentorship.lfx.linuxfoundation.org/) lists what's open right now. For Outreachy, [outreachy.org](https://www.outreachy.org/) has the next intake. GSoC's calendar is at [summerofcode.withgoogle.com](https://summerofcode.withgoogle.com/).
2. **Read three project descriptions, fully.** Not five. Three. Pick the one whose problem you find most interesting, not the one whose description is shortest.
3. **Write a draft proposal *before* you contact a mentor.** A 500-word draft with one concrete milestone is enough.
4. **Send it to me, with one caveat.** If I'm on the selection committee for your target program, I can't review your draft; that would be unfair to other applicants and would turn selection into a spam channel. For LFX 2026 Jun–Aug on `opentelemetry-go-compile-instrumentation` (the cohort [Dario](https://github.com/darccio) and I are running): please don't send me a draft. For any other program, on any other CNCF project where I'm an outsider, my DMs are on the [usual places](/about/#where-to-find-me). {{< sidenote >}}I'd rather review your draft for an hour than read your rejection email later. Just not on programs where I have a vote.{{< /sidenote >}} I'll tell you honestly whether the scope fits, what the mentor will be looking for, and where the proposal needs work.

There's no admission test for asking. The only failure mode is not asking.

---

*Part 3 of this series, "Stewardship inside OpenTelemetry", is for the people on the other side of the table: the maintainers thinking about whether to sign up to mentor at all. Coming next week.*
