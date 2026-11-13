---
title: "Parkinson's Law in Reverse: Garbage Collecting My Work Before a Team Change"
description: "Changing teams put a hard date on everything I owned, and running a garbage collector over my work showed me how little of it was still live."
date: 2026-10-23T00:00:00Z
publishDate: 2026-10-23T00:00:00Z
categories:
  - reflection
tags:
  - career
  - focus
  - productivity
  - reflection
  - blog
  - engineering
promote: false
---

> "It is a commonplace observation that work expands so as to fill the time available for its completion."

That's the first sentence of [C. Northcote Parkinson's essay](https://www.economist.com/news/1955/11/19/parkinsons-law) in *The Economist*, November 1955, better known as [Parkinson's law](https://en.wikipedia.org/wiki/Parkinson%27s_Law). His example is an "elderly lady of leisure" who spends a whole day sending one postcard to her niece at Bognor Regis, a job a busy man would finish in three minutes.

Fun fact: that sentence isn't even the law. The rest of [the essay](https://doc.cat-v.org/economics/parkinsons-law/the-economist-article.pdf) is about why government offices keep growing, with rules like "Officials make work for each other." I never needed an official. I made work for myself just fine.

I've known this law and quoted it for ages. I had never watched it run in reverse. I'm changing teams within the company, and the move date turned "the time available" from "forever, more or less" into "a few weeks". The work shrank to fit.

It looked a lot like a garbage collector running over my to-do list, so that's the lens. Too cheesy? Probably. Bear with me. 🙃

## A Deadline the Work Didn't Choose

Before the move, almost nothing I owned had a real deadline. Tickets had target dates that slid whenever something more urgent showed up, and side ideas had "next quarter", a date that never arrives. Each open thing was cheap on its own.

The move date didn't care whether any given ticket was done, but it applied to all of them at once. And no one else could finish my half-done things after I left. A ticket that says "investigate X" with no notes doesn't survive a handover. I could close it or make it transferable; otherwise it would rot in someone else's backlog. That's when the collector kicked in.

## Mark: What Is Still Reachable?

A tracing garbage collector, like the one in Go, "walks the object graph starting at the program's roots", as the [Go GC guide](https://go.dev/doc/gc-guide) puts it. Whatever it reaches is live. The rest is garbage, however much effort went into allocating it.

My roots were the team's goals and the people waiting on me. My heap was tickets I'd opened as reminders, docs with "WIP" in the title for far too long, and a few guilds, the cross-team groups around a shared interest, that I'd started with a lot of enthusiasm. For each one I asked a single question: **if I stop pointing at it, does anyone else?**

For a handful of things, yes. For most of the list, no.

## Sweep: Handover or Free

The reachable work went to successors. I picked people who already cared about the outcome, wrote handovers that answered the questions they'd otherwise ask me, and walked through each one with them.

The guilds were the hard part. Attendance was thin, and none of them had a goal sharp enough to tell me whether they were working. They were alive only because I kept sending the invite. Tearing them down meant admitting that in the same channels where I'd announced them. I canceled the meetings and posted a short note on what we'd tried and why we were stopping. A couple of people said they had assumed the guilds were dead already, which is its own kind of feedback. 😅

That note is the part I'd keep. A guild that just stops meeting comes back as "whatever happened to that guild?", while a few sentences on what we learned give the next person a head start.

## The Live Heap Is Small

What survived was a fraction of what I'd been carrying. The guide says the collector's cost scales "proportionally with the size of the live heap." For me, the cost was attention: every item I still pointed at got scanned again on every planning pass. With a smaller heap, focus came back, and the only thing that had changed was that I had less to do.

I'd been running with an enormous `GOGC`: collect rarely, carry a lot. The team change forced a full collection. On the new team I want to collect more often: every new guild or side project gets a goal on day one, and once a quarter I pretend I'm leaving. 

Ask me in six months whether it stuck.

## Try It Yourself

I guess you don't need a team change for this, or to leave your company.
Pick a date three weeks out and pretend it's your last day. List everything you own, and mark what's reachable from a real goal or a real person.
Find a new owner for what deserves one, with the notes you'd want to receive. For the rest, write a short goodbye note.

That note is a postcard, really. Give it the busy man's three minutes, not the lady's whole day.

Then look at what's left. I bet it's smaller than you think.

*Work expands to fill the time available.*
Give it less time. ♻️
