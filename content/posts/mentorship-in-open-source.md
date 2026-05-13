---
title: "Why I Keep Mentoring in Open Source"
description: "A few words on why I keep saying yes to mentorship in open source."
date: 2026-05-22T00:00:00Z
publishDate: 2026-05-22T00:00:00Z
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
---

There's a moment that keeps happening to me. Someone I mentored two or three years ago shows up in a SIG call, on a maintainers' list, on a stage at KubeCon. They've shipped something I couldn't have shipped alone. They're answering questions I once answered for them. And the part that gets me: they're already mentoring someone else.

That moment is the thing. {{< sidenote side="alternate" label="why" >}}It's also the only honest answer to "why do you keep doing this when it's not your job?" The loop closes, and you get to watch.{{< /sidenote >}} Everything else I write here is a footnote to that moment.

### The line on my About page

If you've ever read [my About page](/about/), you've seen this sentence:

> "I've mentored through CNCF {{< tooltip term="LFX" >}}LFX Mentorship — the Linux Foundation's structured open-source mentorship program, run in cohorts with stipends.{{< /tooltip >}}, Google Summer of Code, CommunityBridge, and GoBridge, helping others find their way into open source."

It has been there for years. I've never written about what it actually means. That's a strange omission for someone who blogs about almost everything else they do at work, and the reason is simple: mentorship is hard to talk about without it sounding either like humble-bragging ("look at me, generously donating my time") or like a program brochure ("apply today, terms and conditions apply"). Both are boring. Neither is what mentorship feels like from the inside.

### I was a mentee first

Before I was anybody's mentor, I was somebody's mentee.

When I was learning to maintain [Thanos](https://github.com/thanos-io/thanos), [Bartek Płotka](https://www.bwplotka.dev/) walked me through review after review. He showed me what good API design looked like by writing it out in PR comments. He told me when an idea was wrong, and stayed in the thread until I understood why. He let me make mistakes in patches I was proud of, then explained, in writing, exactly why the mistake was a mistake. I learned how a maintainer relationship is supposed to feel by being on the receiving end of one done well.

I would not have the career I have without that period. Open source is rare in that the apprenticeship is built into the medium: every PR is a teaching moment if both parties want it to be. The trick is finding people who do.

I've since made every mistake a mentor can make from the other side of that table. {{< sidenote >}}Top three: scoping projects too ambitiously, ghosting someone for three weeks during a release crunch, and confusing "I would do it this way" with "this is the right way."{{< /sidenote >}} I have lost touch with people I should have kept in touch with. I have written reference letters too late. So this post is field notes, not advice from on high.

### Why I keep saying yes

A few honest reasons, in no particular order.

The first is that mentoring is selfish. The best way I know to learn something in depth is to write about it and to teach it. Mentorship is the second of those, on a real project, with real stakes, on someone else's time. It forces me to articulate things I've stopped noticing. *Why* do we test this way? *Why* did we name the thing this way and not that way? When you have to explain something to a smart person who hasn't yet absorbed your team's folklore, you discover how much of what you "know" is actually superstition. Every cohort makes me a better engineer.

The second is that the projects need it. I lifted this line from my [own field notes at OTel Unplugged](/posts/otel-unplugged-eu-2026/#the-maintainer-crisis):

> "Maintainership is privilege AND responsibility."

CNCF projects are running on tired maintainers. {{< sidenote side="alternate" >}}This is the unspoken background to half the project meetings I attend. It's also why "stewardship" is the word of the moment.{{< /sidenote >}} The dependency-management model, *"we use this, we patch it when it breaks"*, does not produce the next generation of maintainers. Mentorship does. Slowly, one human at a time. There is no other mechanism I know of that reliably converts someone from a user of a project into a steward of it.

The last reason is the one I'd rather not admit, because it sounds saccharine. The people are the best part. Every cohort of mentees I've worked with through CNCF [LFX Mentorship](https://lfx.linuxfoundation.org/tools/mentorship/), [Google Summer of Code](https://summerofcode.withgoogle.com/), [GoBridge](https://gobridge.org/), and [CommunityBridge](https://communitybridge.org/) has been more interesting than most of my coworkers in any given quarter. They show up with weird backgrounds, sharp questions, and an almost embarrassing amount of energy. They make me want to keep going.

Underneath all of these is something simpler. I love learning. Open source is one of the few fields where learning is the work itself, yours and the project's at the same time. Sharing what you've picked up is the cheapest way to shorten the next person's curve. Sharing is caring; it also happens to be how the field gets better.

### What's next

If this lands for you, there are two follow-ups in mind: a practical playbook for mentees, and a closing post on what mentorship looks like inside OpenTelemetry right now.

The timing isn't accidental. As I write this, I'm about to start a new cohort: co-mentoring [Expanding Go Compile-Time Instrumentation Support and Improving otelc Tooling](https://github.com/cncf/mentoring/blob/main/programs/lfx-mentorship/2026/02-Jun-Aug/README.md#expanding-go-compile-time-instrumentation-support-and-improving-otelc-tooling) on `opentelemetry-go-compile-instrumentation` with [Dario Castañé](https://github.com/darccio) for the LFX 2026 Jun–Aug round. Applications closed a few weeks ago; we're picking a mentee now, and the cohort itself kicks off in June.

If you're a mentee looking at a future cohort and want a second pair of eyes on a draft proposal, or if you're already mentoring and want to compare notes: my DMs are open on the [usual places](/about/#where-to-find-me).

The timing isn't accidental. As I write this, I'm mid-cohort on the LFX 2026 Jun–Aug round, co-mentoring [Expanding Go Compile-Time Instrumentation Support and Improving otelc Tooling](https://github.com/cncf/mentoring/blob/main/programs/lfx-mentorship/2026/02-Jun-Aug/README.md#expanding-go-compile-time-instrumentation-support-and-improving-otelc-tooling) on `opentelemetry-go-compile-instrumentation` with [Dario Castañé](https://github.com/darccio). Applications closed a few weeks ago; we're picking a mentee now. Part 3 takes that story apart in detail.

If you're already on either side of that conversation and want to compare notes, or if you're a mentee looking at a future 2026 cohort and want a second pair of eyes on a draft proposal: my DMs are open on the [usual places](/about/#where-to-find-me).

See you in [Part 2](/posts/mentorship-in-open-source-part-2-mentee-playbook/).
>>>>>>> 268e82f (post: link Part 1 forward to the now-landing Part 2)
