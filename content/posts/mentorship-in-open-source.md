---
title: "Why I Keep Mentoring in Open Source"
description: "Series opener — a few words on why I keep saying yes to mentorship in open source, and what's coming next."
date: 2026-05-02T00:00:00Z
publishDate: 2026-05-02T00:00:00Z
categories:
  - reflection
tags:
  - blog
  - mentorship
  - open-source
  - community
  - cncf
  - lfx
  - gsoc
  - gobridge
  - communitybridge
  - reflection
series:
  - Mentorship in Open Source
cover:
  image: /uploads/otel_unplugged_2026_community.jpeg
  alt: OTel Unplugged EU 2026 — community gathering at Sparks Meeting, Brussels
  caption: OTel Unplugged EU 2026 — the community room. Most of the people I now call colleagues started in rooms like this one.
---

There's a moment that keeps happening to me. Someone I mentored two or three years ago shows up in a SIG call, on a maintainers' list, on a stage at KubeCon. They've shipped something I couldn't have shipped alone. They're answering questions I once answered for them. And — this is the part that gets me — they're already mentoring someone else.

That moment is the thing. {{< sidenote side="alternate" label="why" >}}It's also the only honest answer to "why do you keep doing this when it's not your job?" — because the loop closes, and you get to watch.{{< /sidenote >}} Everything else I write in this little series is a footnote to that moment.

### The line on my About page

If you've ever read [my About page](/about/), you've seen this sentence:

> "I've mentored through CNCF {{< tooltip term="LFX" >}}LFX Mentorship — the Linux Foundation's structured open-source mentorship program, run in cohorts with stipends.{{< /tooltip >}}, Google Summer of Code, CommunityBridge, and GoBridge, helping others find their way into open source."

It has been there for years. I've never written about what it actually means. That's a strange omission for someone who blogs about almost everything else they do at work, and the reason is simple: mentorship is hard to talk about without it sounding either like humble-bragging ("look at me, generously donating my time") or like a program brochure ("apply today, terms and conditions apply"). Both are boring. Neither is what mentorship feels like from the inside.

So I'm going to try a different shape: a short series of three posts, each aimed at a different reader.

### What's in this series

1. **This post** — why I keep saying yes. A reflection, mostly for me, but also for anyone who's wondering whether to start.
2. **[Part 2 — The mentee playbook](/posts/mentorship-in-open-source-part-2-mentee-playbook/).** {{< sidenote >}}Link goes live when Part 2 lands.{{< /sidenote >}} If you want to be mentored — through LFX, GSoC, Outreachy, GoBridge, CommunityBridge, or just by cold-DMing a maintainer — here's what works, what doesn't, and how to write a proposal that actually gets picked.
3. **[Part 3 — Stewardship inside OpenTelemetry](/posts/mentorship-in-open-source-part-3-stewardship/).** {{< sidenote >}}Link goes live when Part 3 lands.{{< /sidenote >}} A live example. The CNCF and Bloomberg recently published a piece I keep coming back to — *[Sustaining OpenTelemetry: Moving from Dependency Management to Stewardship](https://www.cncf.io/blog/2026/03/31/sustaining-opentelemetry-moving-from-dependency-management-to-stewardship/)*. Part 3 is about what stewardship looks like at the SIG level when the goal is to grow people, not just code.

### Why I keep saying yes

A few honest reasons, in no particular order.

**Because someone did it for me.** Early in my open-source life, more than one maintainer reviewed my embarrassingly bad PRs without making me feel embarrassed. {{< sidenote side="alternate" >}}If any of you are reading this — you know who you are. The debt is real and uncollectable. The interest payment is mentoring the next person.{{< /sidenote >}} They explained why a comment was worth more than a clever line of code. They told me when an idea was wrong, and stayed in the thread until I understood why. I am here because of them, and the only useful response I've found to that fact is to do the same for someone else.

**Because the work is selfish.** Mentoring forces me to articulate things I've stopped noticing. *Why* do we test this way? *Why* is this the right abstraction? *Why* did we name the thing this way and not that way? When you have to explain something to a smart person who hasn't yet absorbed your team's folklore, you discover how much of what you "know" is actually superstition. Every cohort makes me a better engineer.

**Because the projects need it.** I lifted this line from my [own field notes at OTel Unplugged](/posts/otel-unplugged-eu-2026/#the-maintainer-crisis), but it's worth repeating:

> "Maintainership is privilege AND responsibility."

CNCF projects are running on tired maintainers. {{< sidenote side="alternate" >}}This is the unspoken background to half the project meetings I attend. It's also why "stewardship" is the word of the moment.{{< /sidenote >}} The dependency-management model — *"we use this, we patch it when it breaks"* — does not produce the next generation of maintainers. Mentorship does. Slowly, inefficiently, one human at a time. There is no other mechanism I know of that reliably converts someone from a user of a project into a steward of it.

**Because the people are the best part.** This is the one I'd rather not admit, because it sounds saccharine. But the truth is that every cohort of mentees I've worked with — through CNCF [LFX Mentorship](https://lfx.linuxfoundation.org/tools/mentorship/), [Google Summer of Code](https://summerofcode.withgoogle.com/), [GoBridge](https://gobridge.org/), [CommunityBridge](https://communitybridge.org/) — has been more interesting than most of my coworkers in any given quarter. They show up with weird backgrounds, sharp questions, and an almost embarrassing amount of energy. They make me want to keep going.

### What this series is not

It's not a victory lap. I have made every mistake a mentor can make. {{< sidenote >}}Top three: scoping projects too ambitiously, ghosting someone for three weeks during a release crunch, and confusing "I would do it this way" with "this is the right way."{{< /sidenote >}} I have lost touch with people I should have kept in touch with. I have written reference letters too late. I am not the right person to write a definitive guide to anything.

It's also not a recruiting pitch for a particular program. The programs I'll talk about — LFX, GSoC, Outreachy, GoBridge, CommunityBridge — each do something different, and you can find the canonical guides in the [CNCF mentoring repository](https://github.com/cncf/mentoring) or on each program's own site. What I can offer is what those guides can't: the texture of doing this for years, the patterns I see across mentees, and the parts that surprised me.

### Where this goes next

Two more posts are coming. Part 2, for the people thinking *"I want to do this — where do I start?"*. Part 3, for the maintainers thinking *"I want to do this — how do I make it part of how my project runs?"*.

If you're already on either side of that conversation and want to compare notes — or you're a mentee looking at a 2026 cohort and want a second pair of eyes on a draft proposal — my DMs are open on the [usual places](/about/#where-to-find-me).

See you in Part 2.
