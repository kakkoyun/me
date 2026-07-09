---
title: "My Second Brain System: PARA, Readwise, and an LLM That Takes Notes"
description: "What I actually built, what does most of the work, and the one design choice that distinguishes this from every other Obsidian-plus-AI setup."
date: 2026-05-22T00:00:00Z
publishDate: 2026-08-11T00:00:00Z
categories:
  - technical-findings
tags:
  - blog
  - obsidian
  - second-brain
  - pkm
  - llm
  - claude-code
  - tooling
showToc: true
draft: true
promote: false
---

It is 9:14am on a Wednesday. I open the laptop. The daily note for today is already there.

Above the fold: a Whoop recovery score of 62 (fine), a Wakatime row showing 4h 21m on the OpenTelemetry contrib repo yesterday, three GitHub PRs waiting on review, and a Things 3 task that has been sliding forward for nine days: *[FILL: real task, e.g. "Reply to <person> about <thing>"]*. Each previous day the task migrated, and the journal entry from that day is one click away. The reason it kept slipping is in those entries somewhere.

The system did not make the task less unpleasant. It made the unpleasantness traceable. That is the smaller of the two things this setup buys me. The larger one is that an LLM has been quietly reading everything I capture and writing a layer of synthesis on top, and once a week that synthesis answers a question I would not have been able to ask my past self without it.

This is the description of what I built, and the one design choice I think makes the whole thing work. I am going to lead with the boring parts on purpose.

## The 80% that does the work

Three workhorses. None of them are interesting.

The first is [PARA](https://fortelabs.com/blog/para/) — Projects, Areas, Resources, Archive — across roughly 3,600 markdown files in an Obsidian vault. PARA's only job is to give every note an obvious home, which it does. There are people who prefer [Johnny Decimal](https://johnnydecimal.com/) or [ACCESS](https://www.linkingyourthinking.com/) or their own taxonomies, and they are correct that PARA has rough edges. They are also wrong that the rough edges matter. The point of PARA is to stop you from re-litigating where things go.

The second is [Readwise](https://readwise.io). It syncs highlights from Kindle, Reader, Twitter, and any podcast clipping I tag into `curation/readwise/`. I do not curate at this layer. Everything lands. A highlight from a book I read in 2023 is still there.

The third is obsidian-git. It commits the vault every 7 minutes and pushes every 70. I have not thought about backups in months.

The Whoop score, the Wakatime row, and the PR queue in this morning's daily note are stitched together by a small Python CLI I wrote called `pkm-tool`. It pulls from GitHub (PRs opened, reviewed, merged), Jira (tickets resolved and commented on), Wakatime (time by project and language), Whoop (sleep quality, HRV, recovery score), Apple Calendar (meetings and blocks), Things 3 (tasks completed and scheduled), and Google Docs (documents created or edited). It runs as a launchd job at 6am. By the time I open the laptop, the page exists and the activity is filled in.

That is the substrate. Other Obsidian-PARA people have described all of it before. If the post ended here, it would not be worth your time.

## The one design choice

Here is the part that distinguishes this setup from every other Obsidian-plus-AI build I have tried, and from what most "AI second brain" tools ship.

**The LLM never edits a source.**

Most AI-PKM tools work by chewing on your notes and offering to rewrite, tag, or restructure them. [Copilot for Obsidian](https://github.com/logancyang/obsidian-copilot) edits selected text in-editor. Notion AI is happy to rewrite a page. The implicit contract is: your notes are a substrate the AI improves.

I do not want that. I want my raw captures — the Readwise highlights, the meeting notes I scribbled in a hurry, the half-baked journal entries — to stay exactly as they were when they hit the disk. Those are the historical record. If a synthesis is wrong, I want to look at the source and see *why* it went wrong, without finding that the LLM has already "improved" the source out from under me.

So the vault has two halves with a wall between them. On one side, raw, immutable, never edited by anyone but me at the moment of capture: `curation/`, `journal/`, the daily notes. On the other side, written and maintained by an LLM (mostly Claude Code) that reads those sources: `zettelkasten/`, `resources/concepts/`, `decisions/`, `reflections/`.

The synthesis layer can be wrong. The synthesis layer can be regenerated. The raw layer is ground truth.

This is the [Karpathy LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) applied to a PARA vault. The schema lives in `system/wiki/SCHEMA.md` and declares three operations the LLM is allowed to perform. **Ingest** reads a new source and writes synthesis pages without touching the source. **Query** answers a question and files the answer back as new wiki content if it produced new insight. **Lint** walks the synthesis graph looking for orphans, stale references, and contradictions to flag for me to resolve.

If I had to defend the architecture in one sentence: it lets knowledge accumulate across LLM sessions without letting the LLM rewrite the past. Almost every other choice in the setup followed from that.

## A morning when it paid off

The retrieval engine across all of this is [qmd](https://github.com/tobi/qmd) — Tobi Lütke's local-first CLI, BM25 plus vector embeddings plus an LLM reranker, no API call, useful hits across the whole vault in under a second.

A few weeks ago I was writing a section of a Go talk and asked Claude Code: *[FILL: real query, e.g. "what have I written about backpressure in event-stream consumers"]*. Three things came back from three folders, written months apart:

1. A Readwise highlight from *[FILL: book + month, e.g. Designing Data-Intensive Applications, March]*, with a passage I had underlined about *[FILL: the concept]*
2. A meeting note from a *[FILL: project]* design review in *[FILL: month]*, where someone had sketched a whiteboard solution I had transcribed
3. A Sunday journal entry from *[FILL: month]* in which I had written half a paragraph about a similar problem I had hit at *[FILL: previous job]* and forgotten I had thought about

I had not connected the three. The LLM did, and pointed at the shared idea. The synthesis page that came out of that morning is in `resources/concepts/[FILL: filename].md`. It cites all three sources. If I read it next year and disagree, I can walk the citations back and see what I was reading.

This is the kind of retrieval that makes me trust the system. It is not magical. It is searched-and-ranked. But "searched-and-ranked across everything you have ever read or thought, with an LLM doing the connection work" is qualitatively different from "I remembered I had a note somewhere."

## If you are starting from zero

Three things, in order of how I would build it again.

**Get retrieval working before synthesis.** Run `qmd` (or any decent local search — there are several now) over whatever notes you have today. If you cannot search what you have in under a second, the synthesis layer will not save you. Most of the value of a "second brain" is retrieval, not generation.

**Do not sync everything immediately.** Resist the urge to dump every Twitter favorite, web clip, and podcast highlight into one folder on day one. Start with one capture channel — books, or articles you actually read, or your daily journal — and live with it until "I captured something today and I can find it later" feels routine. Add channels once that rhythm exists.

**Be honest about what the wiki layer needs from you.** The LLM Wiki pattern only compounds if you actually run it. My ingestion log is mostly empty. The schema landed in May and I have not pushed even half my Readwise backlog through INGEST. The structure works. The practice has not caught up. If you are skeptical of "second brain" hype because most setups die at the synthesis layer, you are not wrong. Mine has not proven it yet either.

One thing to know before you set up your own version: the daily-note enrichment depends on four or five MCPs working at once (obsidian-mcp, Whoop, Things 3, Apple Calendar, Basic Memory). When one drops, the enrichment degrades silently — you get a page that looks right but is missing yesterday's tasks or your Whoop score. I do not have a health check for that yet.

## The one thing I cannot tell you yet

There is a question I have not settled.

When the LLM maintains the synthesis pages, and I read one of those pages six months from now, will it feel like *my* thinking or like a summary someone handed me?

The Karpathy pattern bets the answer is fine — the citations point back to raw sources, the synthesis is regenerable, and over time the synthesis pages become more useful precisely because they are not subject to my forgetting. Tiago Forte argues progressive summarization *is* the thinking; I am testing whether that holds when the summarizer is not me.

I am not yet sure I agree. The synthesis pages in my vault from the last month read fluently and cite real sources and make connections I would not have made unaided. They also do not always feel like me. Something about the shape of the paragraphs. Something about which details get kept and which get smoothed away.

I do not know how this resolves. It is possible that in six months the synthesis layer will feel like a colleague I trust, and that is fine. It is possible it will feel like reading someone else's notes about my own life, and that is not fine. I am betting the answer is closer to the first, with limited evidence.

If you build something like this and end up on the other side of the question, I would genuinely like to hear about it.
