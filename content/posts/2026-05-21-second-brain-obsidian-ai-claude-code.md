---
title: "Years of Notes I Didn't Know What to Do With"
description: "I've been hoarding Markdown in Obsidian for years with no real system. Then AI tools learned to read it. This is what's possible now — and what I'm still figuring out."
publishDate: "2026-05-22T00:00:00Z"
date: "2026-05-22T00:00:00Z"
draft: true
categories:
  - "technical-findings"
tags:
  - "obsidian"
  - "claude-code"
  - "second-brain"
  - "pkm"
  - "ai"
  - "mcp"
  - "tools"
  - "blog"
showToc: true
tocOpen: false
---

I've been keeping notes in Obsidian for about four years.

I'd love to tell you I had a master plan. I didn't. I started because I read
Tiago Forte's [*Building a Second Brain*](https://www.buildingasecondbrain.com/)
and liked the premise — a trusted external system, all in plain Markdown,
organised loosely with [PARA](https://fortelabs.com/blog/para/). His core
argument stuck with me: we can't use our heads to store everything we need
to know, so we have to put it somewhere else.

So I just... started writing things down.

Daily journals. Reading highlights from Readwise. Architecture decisions at
work. Half-formed ideas from walks. Meeting notes. Project retrospectives.
Notes about notes. Some of it well-organised. Most of it not. I never quite
figured out the perfect structure. I never did the canonical PARA
reorganisation the books recommend. I just kept dumping things into the vault
because the habit felt right and I figured I'd sort it out later.

Then, sometime last year, AI tools learned to read it.

This post is about that — and about how the four years of accidental hoarding
turned out to be the whole investment.

## The thing that changed

I'm not going to overstate this. Most of my notes are still messy. My PARA
folders have weeds growing through them. I'm not a knowledge management
influencer. I forget where I put things constantly.

But something genuinely shifted last year: tools like
[Claude Code](https://www.anthropic.com/claude-code),
[Claude Desktop](https://claude.ai/download), and Cursor learned to speak a
new protocol — the [Model Context Protocol](https://modelcontextprotocol.io/),
Anthropic's open standard for connecting AI applications to external systems.
Their own metaphor on the spec site is *"like a USB-C port for AI
applications."*

That sounds dry. The practical effect is anything but.

It means every disorganised Markdown file I've been hoarding for four years
is now something an agent can read, search, link, and write to. The
accumulated mess is suddenly a corpus.

That accumulated mess turns out to have been the point.

## What's possible right now (with real tools)

Three concrete things you can wire up today. I'll be specific about which
projects I'd actually point you at, with links.

### 1. A bridge between Obsidian and your AI client

[**`mcp-obsidian`**](https://github.com/MarkusPfundstein/mcp-obsidian) by
Markus Pfundstein is the most popular Obsidian MCP server (around 3.8k stars
at time of writing). It talks to your vault through the companion
[Local REST API plugin](https://github.com/coddingtonbear/obsidian-local-rest-api)
by Adam Coddington, which is the prerequisite — you install the plugin in
Obsidian, generate an API token, then point the MCP server at it.

Once wired in, your AI client can read, create, search, and update your notes
directly. No more copy-pasting context into chat. No more re-explaining your
projects from scratch every session.

This is the moment your AI stops being a stranger to your own thinking. It
can answer "what did I decide about X" by actually reading the note where
you decided it.

### 2. A persistent memory layer

[**`basic-memory`**](https://github.com/basicmachines-co/basic-memory) by
Basic Machines (open source, AGPL-3.0) goes a step further. Their tagline is
the honest pitch:

> *"AI conversations that actually remember. Never re-explain your project
> to your AI again."*

Every conversation can leave structured Markdown behind — observations (facts
you've established) and relations (wiki-style links to other concepts) — that
lives in your vault as plain files. Install with `uv tool install basic-memory`,
add it to your MCP config, and your sessions stop being amnesiac across days
and weeks.

### 3. Semantic search over your vault

Native Obsidian search is keyword-only. When you have thousands of notes,
"find everything I've written about distributed tracing" returns either too
much or nothing useful. What you want is semantic retrieval — finding notes
that are *about* a concept, not just notes that contain the words.

Two public tools to look at:

- [**Smart Connections**](https://github.com/brianpetro/obsidian-smart-connections)
  is the most popular Obsidian plugin for this. Local embeddings by default,
  surfaces related notes as you navigate. Worth noting: it's *source-available*
  rather than traditional open source — the licence restricts redistribution
  for competing commercial offerings, and a paid Pro tier funds development.
- [**Khoj**](https://github.com/khoj-ai/khoj) (Apache 2.0) is a fully open
  alternative that runs as a desktop app or service, indexes Markdown and
  PDFs, and can also chat against your notes with local or hosted models.

I personally run a small custom CLI for this — BM25 plus local vector
embeddings plus reranking — but it's not public. If you want something today,
those two are the honest recommendations.

## The compounding idea

There's an idea I keep coming back to, originally articulated by
[Andy Matuschak](https://andymatuschak.org/) in his work on
[evergreen notes](https://notes.andymatuschak.org/Evergreen_notes): notes
should be *"written and organized to evolve, contribute, and accumulate over
time, across projects."* Each note makes the next one more valuable. Knowledge
compounds.

I never managed the discipline Matuschak describes. My notes aren't evergreen
— they're a mix of journals, half-drafts, snapshots, and links. But the
compounding principle plays out anyway, accidentally, with AI in the loop.
Every time a session leaves a structured note behind, the next session has
more to draw on. The vault gets denser. The agent gets sharper at *your*
context, not because the model is getting smarter, but because it has more of
your actual thinking to read.

You don't have to be doing this perfectly. You just have to be doing it.

## A few moments from the last month

Trying to be concrete here, because abstract claims are cheap.

- I asked Claude to help me revisit an architectural decision on a Go side
  project. It pulled an ADR I'd written eight months earlier — one I'd
  half-forgotten — and reminded me what I'd already concluded about the
  trade-off. Saved me an afternoon of re-deriving the argument from scratch.

- A reading highlight I'd captured in February surfaced in a session in May,
  when I was thinking about something seemingly unrelated. The agent spotted
  the connection. I would never have surfaced that link manually.

- "What did I work on this week" — usually a grind to answer when I'm writing
  a retrospective or a status update — turns into "summarise my devlog notes
  for the past 7 days" and the agent does it in seconds.

None of these are magic. They're just years of accumulated context, finally
legible to something that can act on it.

## The honest part

I'm not running every piece of this perfectly. The fully automated devlog I'd
like — pulling from GitHub, Jira, calendar, and Things into a daily entry —
is half-built. Some days it writes itself. Most days I do it by hand. My PARA
folders are still a mess. I still occasionally lose notes because I can't
remember which vault I put them in.

If you came here looking for a complete, polished system to copy: I don't
have one. Nobody really does. Anyone selling a finished system in this space
is selling you the box, not the contents.

What I do have is the realisation that *the habit was always the moat*. The
system can come later, or never. Whatever shape your notes are in, if you
have years of them in plain Markdown, an AI agent can read them today.

## If you want to try this week

The minimum useful stack, in order:

1. **You may already have it: an Obsidian vault**, or any folder of Markdown
   files with some accumulated content.
2. **A bridge:** [`mcp-obsidian`](https://github.com/MarkusPfundstein/mcp-obsidian)
   plus the [Local REST API plugin](https://github.com/coddingtonbear/obsidian-local-rest-api).
3. **A client:** [Claude Code](https://www.anthropic.com/claude-code),
   [Claude Desktop](https://claude.ai/download), or Cursor with the MCP config
   pointing at the bridge.

That's the floor. From there: add
[`basic-memory`](https://github.com/basicmachines-co/basic-memory) when you
want structured memory persisting across sessions. Add
[Smart Connections](https://github.com/brianpetro/obsidian-smart-connections)
or [Khoj](https://github.com/khoj-ai/khoj) when keyword search isn't enough.

If you've been keeping notes for years and wondering whether the effort was
worth it: it turns out the answer is yes — just not for the reasons most of
the second-brain books predicted. Not because you'll go back and re-read
them. Because they're finally readable by something that can do something
with them.

The unglamorous habit was the whole investment. The interesting part is just
starting now.

---

**Further reading:**

- Tiago Forte, *[Building a Second Brain](https://www.buildingasecondbrain.com/)*
  — the original case for an external Markdown brain.
- Andy Matuschak, [Evergreen notes](https://notes.andymatuschak.org/Evergreen_notes)
  — the most precise articulation of why notes compound.
- Anthropic, [Model Context Protocol](https://modelcontextprotocol.io/)
  — the open standard that makes all of this possible.
