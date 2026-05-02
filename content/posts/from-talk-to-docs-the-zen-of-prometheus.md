---
title: "From talk to docs: The Zen of Prometheus"
description: "A talk I gave at PromCon Online 2020 has been adopted as part of the official Prometheus documentation. A short, grateful reflection on the journey from conference slides to canonical guidance."
date: 2026-05-02T00:00:00Z
publishDate: 2026-05-02T00:00:00Z
categories:
  - reflection
tags:
  - blog
  - prometheus
  - observability
  - community
  - open-source
cover:
  image: https://img.youtube.com/vi/Nqp4fjw_omU/maxresdefault.jpg
  alt: The Zen of Prometheus
  caption: The Zen of Prometheus — PromCon Online 2020
---

Every now and then a project surprises you by remembering something you said years ago. This week was one of those weeks. A talk I gave at [PromCon Online 2020](/talks/the-zen-of-prometheus/) — *The Zen of Prometheus* — has quietly become part of the [official Prometheus documentation](https://prometheus.io/docs/practices/the_zen/).

I am still sitting with it.

### Where it started

The talk was born in the strangest year of my career. PromCon 2020 was online, like everything else. I was a few years deep into running Prometheus in anger, collecting scars from instrumenting services that didn't want to be instrumented and writing alerts that kept me up at night for the wrong reasons. I wanted a way to package those lessons that wasn't another forty-slide deck of bullet points.

So I borrowed a frame from somewhere I love. [PEP 20 — *The Zen of Python*](https://peps.python.org/pep-0020/) — the small, almost-koan list that has shaped how an entire community talks to itself. *Beautiful is better than ugly. Simple is better than complex.* I wondered if the same shape could carry the lessons we keep relearning about metrics, instrumentation, and alerting. The result was *The Zen of Prometheus*: a handful of aphorisms, a [companion site](https://the-zen-of-prometheus.netlify.app/), some [slides](https://github.com/kakkoyun/the-zen-of-prometheus), and a [recording](https://www.youtube.com/watch?v=Nqp4fjw_omU) for anyone who wanted to follow along.

I thought it would live the typical conference-talk life: watched a few times, cited in a Slack thread, then politely forgotten.

### What it became

It didn't get forgotten. Other people kept linking to it, kept asking about it, kept finding it useful — and now it has [a home in the official Prometheus docs](https://prometheus.io/docs/practices/the_zen/).

That word, *home*, is the one that keeps coming back to me. A talk is a moment. A docs page is a place. When something moves from the first into the second, it stops being *Kemal's slides from a 2020 PromCon* and becomes something a newcomer reads on day one without ever needing to know who wrote it. That is exactly what I would have wanted, and I'm not sure I would have had the nerve to ask for it.

I won't reproduce the principles here. They live on the official page now, and that's where they should be read — alongside the rest of the practices, maintained by people whose job it is to keep them honest as the project evolves.

### Looking back

The version of me that wrote those lines was not trying to be authoritative. He was trying to write down enough hard-won lessons that the next person would not have to learn them at three in the morning. Most of what ended up in *The Zen of Prometheus* came from mistakes — mine and the teams I worked with — and from the slow realisation that good instrumentation is mostly a discipline of restraint.

It is a strange and quietly emotional thing to see those notes outlast the moment they were written for. The talk was a small gesture. The fact that it found its way into the docs says less about the talk and more about the Prometheus community: a project that is still willing to listen to its users, fold their field notes back into its canon, and treat best practices as a living document rather than a finished one. That is rare, and it is the reason I keep coming back to this ecosystem.

### Thanks

Thank you to the Prometheus maintainers — for stewarding the project, for keeping its documentation alive and opinionated, and for making space for community contributions to grow into something canonical. Thank you to everyone who shared the talk over the years, asked sharp questions about it, and pushed back where I was wrong. A particular nod to the [follow-up at PromCon EU 2022](/talks/best-practices-and-pitfalls-of-instrumenting-your-cloud-native-application/), which carried the same thread further with a co-speaker who made it sharper than I could have alone.

A talk only ever belongs to its speaker for an hour. After that, it belongs to whoever finds it useful.

### Read it, improve it

If you have not yet, [read the page](https://prometheus.io/docs/practices/the_zen/). And if your own production scars suggest a principle that is missing, propose it. The docs are alive. *Same team, different companies* — and the canon gets better when more of us write into it.
