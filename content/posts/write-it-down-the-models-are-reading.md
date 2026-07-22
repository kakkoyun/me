---
title: "Write it down. The models are reading."
description: "Stack Overflow is dead, we lean on frozen training data, and the answers to recent problems aren't getting posted anywhere. A case for writing down what you solved, and for telling the models to go read the web."
date: 2026-07-22T00:00:00Z
publishDate: 2026-07-22T00:00:00Z
categories:
  - reflection
tags:
  - blog
  - ai
  - llms
  - writing
  - developer-experience
---

For years my debugging reflex was muscle memory. Copy the error, paste it into Google, click the Stack Overflow result, scroll to the green-checked answer from 2014 with four hundred upvotes and a comment thread arguing about the edge cases. It worked so well I stopped noticing it was a system. Someone, years before me, had hit the exact wall I was hitting, written down what fixed it, and left it out in the open where I could find it.

I don't do that anymore. Now I paste the error into a model. Most of the time it's genuinely good, faster than the old ritual and patient with my follow-up questions. But every so often it answers with total confidence about a world that no longer exists: a flag that got renamed two releases ago, a library API that was deprecated last year, the 2021 answer to a 2024 problem. It isn't lying to me. It's remembering. A model is a photograph of the web taken at some cutoff date, and the photo is quietly aging on the wall.

Here's the part that nags at me. When I do finally crack the recent problem myself, the one the model couldn't help with because the fix is younger than its training data, I don't write it down anywhere. Neither do you. The green-checked answer that future-me needs is never going to get posted, because the place we used to post it is a ghost town.

### Stack Overflow is dead, and we got exactly what we asked for

I don't mean this as a hot take. Look at the traffic charts, or the volume of new questions, or how long a genuine question survives now before it's closed as a duplicate of something that isn't quite the same. As a place where a stranger's problem meets a stranger's answer in public, Stack Overflow is mostly over. And I understand why. Asking there was often unpleasant. A model in a private chat never tells you your question is a duplicate, never downvotes you for not reading the sidebar, never makes you feel twelve years old for not knowing the thing you came to learn. Of course we switched.

But something got lost in the switch, and it took me a while to name it. Every one of those private chats is an answer that helped exactly one person and then evaporated. The fix I worked out with a model at 2am is not indexed anywhere. It didn't get written into the shared record. Multiply that by every developer who used to leave a trail and now doesn't, and the commons that trained these models in the first place is thinning out at precisely the moment the models are freezing the last good snapshot of it into their weights.

That's the loop I keep turning over. The models are good because people wrote things down in public for twenty years. We've stopped writing things down in public because the models are good. Nobody decided this. It's just where the path of least resistance leads.

### The cutoff is a real wall, and it moves

A training cutoff is easy to wave away until it bites you. The model knows an enormous amount about the world up to some date, and then it knows nothing, except that it doesn't sound like it knows nothing. It will describe the config option that used to exist with the same fluency it describes the one that still does.

I hit this constantly with recent, narrow problems. The exact ones worth writing about. A while back I lost an afternoon to Go module downloads timing out behind a corporate VPN, and the model kept confidently suggesting fixes for the wrong failure mode. The actual answer was a single-character change, a pipe instead of a comma in `GOPROXY`, and once I understood it I [wrote the whole thing up](/posts/goproxy-fallback-behind-vpn/) so the next person searching that error would land on something true. That post is now the artifact I wish had existed when I started. Future-me will Google that error again in three years, having forgotten everything, and find his own answer waiting. That alone is worth the twenty minutes it took to write.

None of this is anti-model. I [live inside these tools now](/posts/2024-03-21-vibe-coding-with-cursor/), and I'm not giving them up. The point is narrower: fluency is not freshness, and the gap between them is exactly the territory where recent, hard-won fixes live. If we want that territory covered, someone has to keep writing.

### Two small things that help

The first is boring and it's the whole point of this post: write down what you solved. Not a polished tutorial. The problem, the error message, what actually fixed it. This blog has a category for it, [blogmentation](/categories/blogmentation/), and the bar is deliberately low, three hundred words and a code block. It helps the next human who hits the wall at 3am. It also helps the next model, because a public post is something a crawler can index and a search tool can hand back with a citation. Your afternoon of pain becomes searchable, and one fewer person gets stuck.

The second is a habit rather than an artifact: when you're working with a model on anything recent, tell it to go read the web. Turn on search. Point it at the changelog, or the issue thread, or whatever the actual docs say now. A model that can read your fresh blog post beats a model reciting a stale one from memory, every time. I've tried to make that easy from my side of the wire. This site serves a plain-markdown version of every page if you append `index.md` to the URL, publishes an [`llms.txt`](/llms.txt) that tells a model how to fetch context, and its `robots.txt` waves the AI crawlers in rather than shutting them out. If the machines are going to read us, we may as well set the table.

### The experiment: make writing it down nearly free

My honest problem with all of the above is simple. I believe it, and I still don't do it often enough, because the moment right after solving something is the moment I least want to write a blog post. The friction wins.

So I want to try attacking the friction directly. I already generate a rich trail while I work: my coding sessions with agents are logged, the dead ends and the fix that finally stuck all sitting there in the transcript. What if a tool did the tedious first pass? Read back the week's sessions, pull out the two or three real solves, and hand me a rough draft I only have to edit and publish, instead of a blank page I have to start.

That's the next thing I'm building, and I'm going to run it in public. A small, mostly-auto-generated newsletter drafted from my actual working sessions, the raw dump of what broke and how I got out. I'm calling it [CoreDump](/newsletter/coredump/), because a core dump is the thing you go read to find out what went wrong. It's an experiment, and it might turn out that a machine draft of my week is either too dull or too wrong to salvage. I'll find out in the open.

If the incentive to post publicly really is eroding, maybe the answer isn't to guilt each other into writing more. Maybe it's to make writing it down so cheap that not doing it stops making sense. I don't know if that works. But I know the alternative is a slow fade where all our answers live in private chat logs that no one else will ever read, and the shared record just stops getting written. I'd rather leave a trail. Even a messy, half-automated one.
