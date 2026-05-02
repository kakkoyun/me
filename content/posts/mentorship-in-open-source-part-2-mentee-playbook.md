---
title: "Mentorship in Open Source — Part 2: The Mentee Playbook"
description: "A practical guide to getting into open-source through structured mentorship — LFX, GSoC, Outreachy, GoBridge, and CommunityBridge. What works, what doesn't, and how to write a proposal that gets picked."
date: 2026-05-09T00:00:00Z
publishDate: 2026-05-09T00:00:00Z
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
  - communitybridge
  - career
series:
  - Mentorship in Open Source
showToc: true
tocOpen: false
cover:
  image: /uploads/otel_unplugged_2026_stickies.jpeg
  alt: OTel Unplugged EU 2026 — sticky notes from a brainstorming session
  caption: A wall of sticky notes from OTel Unplugged 2026. Most good mentorship projects start as one of these.
---

This is Part 2 of a small series. [Part 1](/posts/mentorship-in-open-source/) was the *why*. This one is the *how* — specifically, how to be a mentee in 2026.

I've spent the last few years on the mentor side of CNCF {{< tooltip term="LFX" >}}LFX Mentorship — the Linux Foundation's structured mentorship program. Cohorts run quarterly, projects are scoped to ~12 weeks, and mentees receive a stipend.{{< /tooltip >}}, [Google Summer of Code](https://summerofcode.withgoogle.com/) ({{< tooltip term="GSoC" >}}A Google-funded program where students contribute to open-source projects over the summer, paired with mentors from those projects.{{< /tooltip >}}), [GoBridge](https://gobridge.org/), and [CommunityBridge](https://communitybridge.org/), mostly through [Parca](https://github.com/parca-dev/parca), [Thanos](https://github.com/thanos-io/thanos), and now various [OpenTelemetry](https://github.com/open-telemetry) projects. Every cohort I've run, the same questions keep coming up from people who *want* to apply but don't know how to start.

This is the post I wish I could send those folks.

## Who this is for

You've heard about open-source mentorship programs and you want in. You might be:

- A student looking for a structured summer project (GSoC's bullseye).
- A working engineer wanting to break into a CNCF or {{< tooltip term="OSS" >}}Open-source software.{{< /tooltip >}} ecosystem you respect (LFX is your friend).
- An engineer from a background under-represented in tech (Outreachy is built for you).
- Someone who's tried "just contribute to open source" and bounced off the gravitational well of unread Slack channels (you want a structured program with a mentor whose job it is to talk to you).

If any of those is you, keep reading.

## The four programs I've worked through

I've personally been involved with four. There are more — these are the ones I can speak to with first-hand experience.

### CNCF LFX Mentorship

- **What it is.** A structured cohort-based program run by the Linux Foundation. Each project is scoped for one cohort (~12 weeks), assigned 1–2 mentors, and pays a stipend.
- **Cadence.** Multiple cohorts per year. Spring/summer/fall — see the [active terms](https://mentorship.lfx.linuxfoundation.org/) for current dates.
- **Project list.** Lives in the [`cncf/mentoring`](https://github.com/cncf/mentoring) repo under `programs/lfx-mentorship/`. The structure rewards reading: each project has a description, required skills, mentor names, and (usually) example issues.
- **What makes it special.** Every mentor on LFX has agreed to commit a meaningful chunk of time. That is a contract you don't get from "show up in the GitHub issues."

### Google Summer of Code

- **What it is.** Google's long-running OSS internship. Originally student-only; for a few years now it's been open to "beginners to open source," not just students.
- **Cadence.** Annual. Applications open in spring, work happens over summer.
- **Project list.** Each participating org publishes its own ideas list. CNCF orgs aggregate theirs in [`cncf/mentoring`](https://github.com/cncf/mentoring/tree/main/programs/summerofcode).
- **What makes it special.** GSoC has the strongest "first-time mentee" track record I've seen. The structure is forgiving enough that someone with rough Git fundamentals can still ship something real by August.

### Outreachy

- **What it is.** A program for people from groups traditionally under-represented in tech, including those affected by systemic bias.
- **Cadence.** Two cohorts per year (May–August and December–March).
- **How to apply.** Outreachy's intake is more rigorous than the others — there's a contribution period before the formal proposal, and it's [run from outreachy.org directly](https://www.outreachy.org/).
- **What makes it special.** It has the lowest tolerance for the "open-source as boys' club" failure mode of any program I've seen. If you've felt locked out of OSS communities, this is the door.

### GoBridge & CommunityBridge

- **What they are.** Less structured than the above. [GoBridge](https://gobridge.org/) runs workshops, scholarships, and mentor pairings focused on the Go community. [CommunityBridge](https://communitybridge.org/) is the Linux Foundation's broader umbrella for sponsored mentorship and project funding.
- **Why I list them.** Not every door is a 12-week cohort. Sometimes a one-week workshop or a 1:1 office-hours pairing is exactly the right starting size.

## What I look for in a proposal

Most proposals get rejected for the same reasons. Most accepted proposals share the same shape. Here's what I look for as a mentor — your mileage may vary, but ask any LFX/GSoC mentor and you'll hear most of this.

- [ ] **You have read the project's recent issues, PRs, and design docs.** Not all of them — but enough that you can name two open issues by number and explain why they matter.
- [ ] **Your scope fits in 12 weeks.** Not 12 weeks of full-time senior-engineer effort — 12 weeks of *your* effort, with reasonable assumptions about ramp-up. {{< sidenote side="alternate" >}}A great heuristic: if you can't draft a one-paragraph milestone for week 4 *right now*, your scope is too vague.{{< /sidenote >}}
- [ ] **You've made one small PR already.** Even a typo fix in the README. It tells me you can find your way around the codebase, run the tests, and follow the contribution guide.
- [ ] **You've named the trade-offs.** Every interesting project has at least one. If your proposal reads like a feature spec with no tensions, you haven't engaged with the problem deeply enough.
- [ ] **You've written the proposal *as a collaboration plan*, not a job application.** I want to know *how we're going to work together*, not how impressive you are.

That last bullet is the one I see violated most often. A mentorship proposal is not a CV. It's a draft of the conversation we're going to have for the next three months.

## What makes a good first contribution

If you're not yet at proposal stage — you just want to do *something* — start here.

1. **Pick the project before the program.** Find a CNCF or Go project whose docs you've actually read for fun. Whose maintainers you've watched on a podcast or at a meet-up. {{< sidenote >}}If no project meets that bar yet, your first task is to find one. Spend a week with the [CNCF Landscape](https://landscape.cncf.io/) and the [TAG observability group](https://github.com/cncf/tag-observability).{{< /sidenote >}} Programs are the scaffolding. The project is the building.
2. **Read the issue tracker for an hour.** Not to pick an issue — to understand the *vocabulary*. What does "OBI" mean to this project? What's a "sidecar" here? Who's `@nickname` and why do they have opinions?
3. **Find a "good first issue" or a `help-wanted` that hasn't been touched in a few weeks.** If it's been claimed and abandoned, comment asking if you can pick it up. If it's untouched, comment with your understanding of the problem and a sketch of an approach *before* you write code.
4. **Submit a small, working PR.** Tests included. Description that explains the *why*, not the *what*. Ask for review explicitly.
5. **Stay in the thread.** This is the most under-rated step. Half of first-time contributors disappear after their PR gets review comments. The half that stay through one round of revisions become contributors.

## The five mistakes I see most

I've watched these patterns play out across cohorts. They are not character flaws — they are easy traps. Knowing about them will not stop you from falling into one of them. But it might shorten the climb out.

### 1. Picking a project you're not actually curious about

The single best predictor of whether a mentee finishes their project is whether they *want to use the thing they're building*. If your project is "add a feature to a database I've never touched," you will run out of motivation by week 6. If your project is "make this tool I rely on do the thing I keep wishing it did," you will finish.

### 2. Scoping too big

Almost every first-draft proposal I review is 2–3× too ambitious. {{< sidenote side="alternate" >}}I've done this myself. As a mentor I now reflexively halve my mentees' first-draft scopes before we publish.{{< /sidenote >}} The tell is when you can describe your "milestones" only as topic areas: *"week 1–4: research; week 5–8: implementation; week 9–12: polish."* Real milestones name the artifact. *"By end of week 4, the parser handles X; PR open for early review."*

### 3. Ghosting

If you don't hear from your mentor for a week, send a message. If you don't hear from yourself for a week — that is, if you've gone quiet on your own project — send a message anyway. *"I'm stuck"* is always a better message than no message. Mentors are not graders; we cannot help you if we don't know what's happening.

### 4. Treating reviews as criticism

I once spent twenty minutes writing a careful review comment explaining why a particular abstraction was the wrong fit, and got back a one-line *"ok will fix"*. Three weeks later the mentee told me they'd been demoralized by that review. Reviews are the actual product of mentorship. The PR is the medium; the review is the message. If a review confuses you, ask. If it stings, sit with it for a day, then ask. The mentor who took twenty minutes to write a careful review wants you to push back when they're wrong.

### 5. Disappearing after the cohort ends

This one is on both sides — mentors do it too. The cohort has a hard end date. The relationship doesn't have to. The mentees I'm proudest of are the ones who kept poking me with PR links and SIG-meeting questions for *years* after their LFX project closed. The official program is a starter loan; the real currency is the ongoing connection.

## Concrete examples (from my own cohorts)

I've mentored on Parca, Thanos, and various OpenTelemetry projects through these programs. {{< sidenote side="alternate" >}}I'll add specific mentee credits and merged-PR links here as I get clearance from the folks involved — naming people in a blog post without asking is exactly the kind of thing I'm trying to teach mentees not to do.{{< /sidenote >}} A handful of patterns that show up across cohorts:

- The strongest proposals always referenced specific open issues by number, not abstract feature ideas.
- The mentees who finished early *all* did one small "warm-up" PR before the cohort officially started.
- The mentees who became maintainers were the ones who kept showing up to community meetings *during* their project, not just at the end.

If you're a former mentee of mine and you'd like me to credit your work in a follow-up post, drop me a line — happy to.

## Call to action — for mentees

If you're thinking about applying:

1. **Pick a current cohort.** Start with [`cncf/mentoring`](https://github.com/cncf/mentoring). For LFX, the [active terms page](https://mentorship.lfx.linuxfoundation.org/) lists what's open right now. For Outreachy, [outreachy.org](https://www.outreachy.org/) has the next intake. GSoC's calendar is at [summerofcode.withgoogle.com](https://summerofcode.withgoogle.com/).
2. **Read three project descriptions, fully.** Not five. Three. Pick the one whose problem you find most interesting, not the one whose description is shortest.
3. **Write a draft proposal *before* you contact a mentor.** A 500-word draft with one concrete milestone is enough.
4. **Send it to me.** {{< sidenote >}}Please. I read these. I'd rather review your draft for an hour than read your rejection email later.{{< /sidenote >}} My DMs are on the [usual places](/about/#where-to-find-me). I will tell you honestly whether the scope fits, what the mentor will be looking for, and where the proposal needs work — for any program, on any CNCF project, not just the ones I'm directly involved in.

There's no admission test for asking. The only failure mode is not asking.

---

*Part 3 of this series — [Stewardship inside OpenTelemetry](/posts/mentorship-in-open-source-part-3-stewardship/) — is for the people on the other side of the table: the maintainers thinking about whether to sign up to mentor at all.*
