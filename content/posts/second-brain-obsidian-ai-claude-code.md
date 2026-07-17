---
title: "Years of Notes I Didn't Know What to Do With"
description: "I've been hoarding Markdown in Obsidian for years with no real system. Then AI tools learned to read it. This is what's possible now — and what I'm still figuring out."
publishDate: 2026-08-04T00:00:00Z
date: 2026-05-22T00:00:00Z
draft: true
categories:
  - technical-findings
tags:
  - obsidian
  - claude-code
  - second-brain
  - pkm
  - ai
  - mcp
  - tools
  - blog
  - agentic-coding
showToc: true
tocOpen: false
promote: false
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

Then, starting in late 2024, AI tools learned to read it.

This post is about that — and about how the four years of accidental hoarding
turned out to be the whole investment.

## The thing that changed

I'm not going to overstate this. Most of my notes are still messy. My PARA
folders have weeds growing through them. I'm not a knowledge management
influencer. I forget where I put things constantly.

But something genuinely shifted last year: tools like
[Claude Code](https://www.anthropic.com/claude-code),
[Claude Desktop](https://claude.ai/download), and Cursor learned to speak a
new protocol — the [Model Context Protocol](https://modelcontextprotocol.io/).
An agent can now open, search, and write to your Markdown directly. No
copy-paste, no re-explaining projects from scratch, no plugin per client.
Four years of disorganised notes became a corpus I could actually query.

## What I actually run

My vault sits at around 3,600 Markdown files — closer to 4,000 across the
personal and work vaults combined. Native Obsidian search is keyword-only,
which stops being useful somewhere around a few hundred notes. "Find
everything I've written about distributed tracing" returns either the whole
vault or none of it.

The tool I reach for most is [`qmd`](https://github.com/tobi/qmd) — a small
CLI by Tobi Lütke that does BM25 for lexical matching, local vector
embeddings for semantics, and a reranker to combine them. It runs entirely
offline, indexes on save, and is the layer everything else in my stack
calls into. I go into how I actually use it — indexing choices, retrieval
quality, the surprises — in a follow-up post on the architecture.

The off-the-shelf pieces around it are shorter to describe:
[`mcp-obsidian`](https://github.com/MarkusPfundstein/mcp-obsidian) (with the
[Local REST API plugin](https://github.com/coddingtonbear/obsidian-local-rest-api))
bridges the vault to any MCP-speaking client;
[`basic-memory`](https://github.com/basicmachines-co/basic-memory) persists
structured observations across sessions so a conversation next week has last
week's notes to draw on. If you don't want to build your own retrieval,
[Smart Connections](https://github.com/brianpetro/obsidian-smart-connections)
and [Khoj](https://github.com/khoj-ai/khoj) are the two I'd point you at.
Their READMEs are better than my paraphrase would be.

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

<!-- TODO(kemal): one more anecdote at the ADR-level specificity — an old
     observability note (or similar technical note) surfacing exactly when
     needed. Include date/topic pair so it lands concrete. -->

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

That's the floor. Add semantic retrieval on top when keyword search runs out —
[Smart Connections](https://github.com/brianpetro/obsidian-smart-connections)
or [Khoj](https://github.com/khoj-ai/khoj) if you want something off the
shelf. I use [`qmd`](https://github.com/tobi/qmd) by Tobi Lütke. Add
[`basic-memory`](https://github.com/basicmachines-co/basic-memory) when you
want structured memory persisting across sessions.

If you've been keeping notes for years and wondering whether the effort was
worth it: yes, but for a different reason than the second-brain books
predicted. You probably won't go back and re-read them. Something else will.

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
