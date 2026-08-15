---
title: 'My Second Brain System: PARA, Readwise, and an LLM captures my thoughts'
description: What I built, what does most of the work, and why the LLM never edits a source note.
date: 2026-05-22T00:00:00Z
publishDate: 2026-08-21T00:00:00Z
draft: false
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
tocOpen: false
showCanonicalLink: false
promote: false
---

At 9:14 a.m. on a Wednesday, I open the laptop. The daily briefing for today is already there.

Above the fold: a Whoop recovery score of 62 (fine), a Wakatime row showing 4h 21m on the OpenTelemetry Go compile-time instrumentation repo yesterday, three GitHub PRs waiting on review, and a Things 3 task that has been sliding forward for nine days: _Review that thing from X_. Each previous day the task migrated, and the journal entry from that day is one click away. The reason it kept slipping is in those entries somewhere.

The system did not make the task less unpleasant. It made the unpleasantness traceable. That is the smaller of the two things this setup buys me. The larger one is the synthesis layer: an LLM reads what I capture and writes connections back into the vault without editing the original notes.

This is what I built, plus the one design choice I think makes the whole thing work. I am going to lead with the boring parts on purpose.

## The 80% that does the work

Three workhorses. None of them are interesting.

The first is [PARA](https://www.buildingasecondbrain.com/para) (Projects, Areas, Resources, Archives). It gives roughly 4,000 Markdown files in an Obsidian vault an obvious home, which is its only job. People who prefer [Johnny Decimal](https://johnnydecimal.com/), [ACCESS](https://www.linkingyourthinking.com/), or their own taxonomies are correct that PARA has rough edges. They are also wrong that the rough edges matter. The point of PARA is to stop you from re-litigating where things go.

The second is [Readwise](https://readwise.io). It syncs highlights from Kindle, Reader, Twitter (yes, still Twitter for me), and any podcast clipping I tag into `curation/readwise/`. I do not curate at this layer. Everything lands. A highlight from a book I read in 2023 is still there.

The third is [`obsidian-git`](https://github.com/Vinzent03/obsidian-git). It commits the vault every 70 minutes and pushes every 7. I have not thought about backups in months.

The Whoop score, the Wakatime row, and the PR queue in that morning's daily note came from a Python CLI I wrote called [`pkm-tool`](https://github.com/kakkoyun/pkm-tool). It pulled GitHub, Jira, Wakatime, Whoop, Apple Calendar, Things 3, and Google Docs into one report. The experiment worked, but it also turned my daily note into a small integration platform I had to maintain.

I no longer use it. Today I prefer small deterministic scripts, Obsidian cron jobs, and official connectors where they exist. A handful of small capture jobs now assemble the note instead of one aggregator.

That is the substrate. Other people have described it before. If the post ended here, it would not be worth your time.

## The one design choice

The part I care about most is the boundary between source material and synthesis.

**The LLM never edits a source.**

Most AI-PKM tools work by chewing on your notes and offering to rewrite, tag, or restructure them. [Copilot for Obsidian](https://github.com/logancyang/obsidian-copilot) edits selected text in-editor. Notion AI is happy to rewrite a page. The implicit contract is: your notes are a substrate the AI improves.

I do not want that. I want my raw captures to stay exactly as they were when they hit the disk. That includes Readwise highlights, meeting notes I scribbled in a hurry, and half-baked journal entries. Those are the historical record. If a synthesis is wrong, I want to look at the source and see _why_ it went wrong, without finding that the LLM has already "improved" the source out from under me.

The vault has two halves with a wall between them. On one side are raw sources such as `curation/`, `journal/`, `devlog/`, and `meetings/`. On the other are pages written and maintained by an LLM (Claude Code in my case): `zettelkasten/`, `resources/concepts/`, `decisions/`, and `reflections/`.

The synthesis layer can be wrong, and I can regenerate it. The raw layer remains the source of truth.

This is the [Karpathy LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) applied to a PARA vault. The schema lives in `system/wiki/SCHEMA.md` and declares three operations the LLM is allowed to perform. **Ingest** reads a new source and writes synthesis pages without touching the source. **Query** answers a question and files the answer back as new wiki content if it produced new insight. **Lint** walks the synthesis graph looking for orphans, stale references, and contradictions to flag for me to resolve.

If I had to defend the architecture in one sentence: it lets knowledge accumulate across LLM sessions without letting the LLM rewrite the past. Almost every other choice in the setup followed from that.

## Where it paid off

The retrieval engine is [qmd](https://github.com/tobi/qmd), Tobi Lütke's local-first CLI. It combines BM25, vector embeddings, and local models for query expansion and reranking without sending my notes to an API.

On July 21, while preparing a GopherCon UK talk, I ran:

```sh
qmd query "benchmark overhead auto-instrumentation Go latency allocations" -n 8
```

It found an older GopherCon proposal in `creation/`, a raw auto-instrumentation note imported from iCloud, a saved article about measuring Go performance, and work notes on auto-instrumentation and code origins. None of that material was new. I had forgotten some of those notes existed. The agent used those documents as the starting material for the talk instead of rebuilding the context from scratch.

On August 3, the synthesis side did something different. A connection pass updated `resources/concepts/Go Programming Expertise.md` from a July 24 daily note about Go 1.24 and 1.25 and an August 3 work devlog about benchmark internals. The page links the release-tracking habit to the compiler and benchmarking work behind the talk, cites both source notes, and labels its confidence as low.

That combination is why I trust the design: qmd finds old material, and the wiki records connections without changing the sources. I can follow every claim back to the note that produced it.

## If you are starting from zero

If I rebuilt it, I would do these in this order.

**Get retrieval working before synthesis.** Run `qmd` or another local search over whatever notes you have today. If you cannot reliably find what you have, the synthesis layer will not save you. Most of the value of a "second brain" is retrieval, not generation.

**Do not sync everything immediately.** Resist the urge to dump every Twitter favorite, web clip, and podcast highlight into one folder on day one. Start with one capture channel, such as books, articles you actually read, or your daily journal, and live with it until "I captured something today and I can find it later" feels routine. Add channels once that rhythm exists.

**Be honest about what the wiki layer needs from you.** The LLM Wiki pattern only improves if you actually run it. My ingestion logs are busy now, but the Readwise backlog is still waiting. The structure works. The practice is still catching up. If you are skeptical of "second brain" hype because most setups die at the synthesis layer, you are not wrong. Mine has not proven itself over the long term either.

The capture layer still has failure modes. The live jobs run inside Obsidian through Cron, Shell Commands, Templater, and connectors, so they depend on Obsidian being open. A failed capture can leave a section empty without making the note look broken. I still do not have one health check for the whole pipeline.

## What I cannot tell you yet

When the LLM maintains the synthesis pages, and I read one of those pages six months from now, will it feel like _my_ thinking or like a summary someone handed me?

The Karpathy pattern makes that trade: citations point back to raw sources, and the synthesis can be regenerated as the wiki changes. [Tiago Forte describes progressive summarization](https://fortelabs.com/blog/progressive-summarization-a-practical-technique-for-designing-discoverable-notes/) as "opportunistic compression" that makes notes discoverable later. I am testing what changes when the summarizer is not me.

I am not yet sure I agree. The synthesis pages in my vault from the last month read fluently and cite real sources and make connections I would not have made unaided. They also do not always feel like me. Something about the shape of the paragraphs. Something about which details get kept and which get smoothed away.

I do not know how this resolves. It is possible that in six months the synthesis layer will feel like a colleague I trust, and that is fine. It is possible it will feel like reading someone else's notes about my own life, and that is not fine. I am betting the answer is closer to the first, with limited evidence.

If you build something like this and end up on the other side of the question, I would genuinely like to hear about it.
