---
title: "My Second Brain System: PARA, Readwise, and an LLM That Takes Notes"
description: "How I built a knowledge management system on top of Obsidian that captures everything automatically, organizes it with PARA, and uses an LLM to synthesize it into a persistent wiki."
date: 2026-05-21T00:00:00Z
publishDate: 2026-06-12T00:00:00Z
categories:
  - blogmentation
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
---

A few months back I asked Claude a question about a book I had read. It gave me a decent answer. Then I pushed: "What about the thing Sönke Ahrens said about permanent notes?" Claude pulled the highlight from my Readwise sync, cross-referenced it with a zettelkasten note I had written, and produced an answer I could not have reached from memory alone.

That worked because of a system I have been building for a couple of years. Here is how it is put together.

## The problem

I read a lot. I take notes in meetings. I bookmark things. I write daily journal entries. For most of my career, all of that landed in separate places and mostly disappeared. I could feel myself re-learning the same things every six months.

More discipline is not the answer. A system that captures without friction and retrieves without effort is.

## The architecture

Three layers:

1. **Capture** — everything flows in automatically
2. **Organize** — PARA gives it a home
3. **Synthesize** — an LLM turns raw material into connected knowledge

Each layer feeds the next.

## Layer 1: Capture

### Readwise

[Readwise](https://readwise.io) syncs highlights from books (Kindle), articles (Reader), tweets, podcasts, and web clips into `curation/readwise/`. I do not curate at this layer. Everything lands. Highlights from a book I read in 2023 are still there, indexed, searchable.

### pkm-tool

Every morning a Python CLI I wrote called `pkm-tool` runs and generates a daily activity report. It pulls from:

- GitHub (PRs opened, reviewed, merged)
- Jira (tickets resolved, commented on)
- Wakatime (time by project and language)
- Whoop (sleep quality, HRV, recovery score)
- Apple Calendar (meetings, blocks)
- Things 3 (tasks completed and scheduled)
- Google Docs (documents created or edited)

The output lands in my daily note under a `## Activity` section. I do not have to remember what I did on any given day.

### Journal

The daily note is ADHD-optimized. I write a few lines. Claude Code reads the activity data and asks three or four follow-up questions based on what happened — a late meeting, a blocked PR, a dropped workout. I answer, and the entry fills out from there. Over 800 entries now.

## Layer 2: Organize

The vault uses [PARA](https://fortelabs.com/blog/para/) — Projects, Areas, Resources, Archive — across about 3,600 files.

```
projects/      — active work, one folder per project
areas/         — ongoing responsibilities
resources/     — reference material, concepts, patterns
archive/       — completed or inactive
curation/      — raw captures (immutable, never edited)
zettelkasten/  — atomic permanent notes
journal/       — dated entries
periodic/      — weekly, monthly, yearly reviews
```

The [Waypoint](https://github.com/nickmilo/waypoint) plugin auto-generates MOC (Map of Content) index files for each folder. Maintenance is not manual.

## Layer 3: Synthesize — the LLM Wiki

This is where it diverges from a standard PARA setup.

I implemented Karpathy's [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f). The premise: raw sources are immutable and the LLM never edits them. Instead, it reads them and writes distilled synthesis pages that persist across sessions. Knowledge compounds rather than resetting.

The schema lives in `system/wiki/SCHEMA.md` and declares three operations:

- **Ingest** — read a new source, extract entities and claims, write or update synthesis pages, check for contradictions, append to the ingestion log
- **Query** — answer a question, then file the answer back as new wiki content if it contains new insight
- **Lint** — health check: find orphaned pages, stale references, missing citations

Synthesis pages live in:

```
zettelkasten/           — atomic knowledge units
resources/concepts/     — merged synthesis from multiple sources
resources/patterns/     — reusable frameworks
people/                 — notes about specific people
decisions/              — architecture and personal decisions
reflections/            — ongoing thinking on a topic
```

Each synthesis page carries frontmatter the LLM maintains:

```yaml
sources_cited:
  - "curation/books/Building-a-Second-Brain.md"
last_synthesized: 2026-05-21
confidence: high
contradictions: []
```

The immutability boundary matters here. Raw captures never change. If a synthesis page gets something wrong, the fix is a new synthesis, not an edit to the source. The ingestion log is append-only. This keeps the historical record clean and gives you somewhere to look when something is confusing.

## Retrieval: qmd

Searching across 4,000 markdown files needs to be fast and semantic. I use [qmd](https://github.com/kakkoyun/qmd) — a local-first search engine with BM25 + vector embeddings + LLM reranking. No API call. No network dependency.

```bash
qmd query "how does Ahrens distinguish permanent notes from reference notes" -c personal -n 5
```

Returns the five most relevant passages, ranked. From there I can fetch the full file:

```bash
qmd get qmd://personal/zettelkasten/permanent-notes.md
```

The BM25+vector combination handles how I actually write notes — loose headings, partial thoughts, abbreviations that only make sense in context.

## Claude Code integration

The vault has a `CLAUDE.md` — an agent contract. Any Claude Code session that opens inside the vault loads it automatically. It declares the three-layer architecture, the PARA directory roles, the metadata schema, and which operations the LLM owns versus the human.

Two MCP servers connect to the vault:

- **obsidian-mcp** — read/write access from any agent session
- **Basic Memory MCP** — semantic knowledge graph; the frontmatter schema is a superset compatible with its observation/relation model

The `vault-wiki` skill routes ingest, query, and lint commands to the correct workflow file. From any Claude Code session, `/vault-wiki` loads `SCHEMA.md`, asks what you want to do, and runs the workflow.

obsidian-git handles backup automatically — commit every 70 minutes, push every 7. I have not thought about vault backups in months.

## How a typical day flows

1. `pkm-tool` runs at startup — daily note appears with activity data already filled in
2. I write a few lines in the journal; Claude Code reads the activity data and asks follow-up questions
3. I read in Readwise Reader; highlights sync to `curation/readwise/` in the background
4. Notes and decisions land in `projects/` or `zettelkasten/` as I work
5. When I want to understand something I run a `qmd` query; if the answer surfaces new insight, the wiki files update
6. obsidian-git commits and pushes in the background, unattended

## What works

The retrieval is genuinely good. A `qmd query` across 4,000 files returns useful results in under a second. The daily aggregation via `pkm-tool` has been the biggest friction reducer — the Whoop recovery score in particular is useful for retrospectives. I can look back at a rough week and see the correlation between sleep debt and dropped velocity.

The `CLAUDE.md` agent contract pattern means I do not have to re-explain the vault structure to every new Claude Code session. Open the vault, load the contract, the agent knows the schema.

## What is rough

The journaling workflow depends on four or five MCPs working simultaneously (obsidian-mcp, Whoop, Things 3, Apple Calendar, Basic Memory). When one drops, the enrichment degrades silently. No health check for that yet.

The LLM Wiki layer is new — the schema landed in May 2026, and the ingestion log is still empty. The historical backlog of 500+ Readwise sources has not been processed through INGEST. The structure is there; the synthesis layer needs to catch up to the capture layer.

There is also a question I have not settled: when the LLM maintains synthesis pages, how much of that knowledge is mine? When I read a concept page six months from now, will it feel like my thinking or a summary someone handed me? I am genuinely not sure. The Karpathy pattern assumes this is fine. I want to run it longer before I agree.

## What I would try next

Running the INGEST workflow against the full Readwise backlog would test whether the synthesis layer actually compounds the way the theory describes. Five hundred sources is enough to see whether the cross-references get interesting or just noisy.

I am also curious whether the `decisions/` folder can replace ADR documents for personal projects. The format is similar to architecture decision records, but the retrieval story is much better — `qmd query` beats `grep` through a folder of numbered markdown files.

The open question is whether the system is doing my thinking or replacing it. I will report back.
