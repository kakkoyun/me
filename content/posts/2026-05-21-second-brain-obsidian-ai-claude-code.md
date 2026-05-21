---
title: "Your Second Brain, Upgraded: Integrating Obsidian with AI Tools and Claude Code"
description: "How I connected Obsidian, MCP servers, qmd semantic search, and Claude Code skills into a living knowledge system that actually gets smarter over time."
publishDate: "2026-05-21T00:00:00Z"
date: "2026-05-21T00:00:00Z"
draft: true
categories:
  - "technical-findings"
tags:
  - "tools"
  - "productivity"
  - "obsidian"
  - "claude-code"
  - "second-brain"
  - "pkm"
  - "ai"
  - "mcp"
  - "blog"
showToc: true
tocOpen: false
---

> TL;DR: Your Obsidian vault is full of context your AI tools can't see. I fixed that by
> wiring together an MCP server, a local semantic search engine (`qmd`), and Claude Code
> skills into a stack where your second brain and your AI agent share the same knowledge.
> Here's exactly how it works — and why it's the most useful thing I've built for my own
> workflow.

## The Problem Nobody Talks About

There's a quiet contradiction at the heart of modern knowledge work.

On one side: you've spent months (or years) building a second brain in Obsidian. Your notes
have structure. They link to each other. You've captured decisions, ideas, devlogs, reading
highlights, and retrospectives. It's a genuine asset.

On the other side: you're using Claude Code, Cursor, or similar tools every day — and they
have no idea any of that context exists. Every session starts from scratch. You re-explain
your architecture, your preferences, your past decisions. The AI is smart, but it's amnesiac
about *you*.

The gap between those two sides is the problem. Closing it is what this post is about.

## The Stack

Before diving in, here's what I ended up building. Each piece has a specific job:

| Layer | Tool | Role |
|---|---|---|
| Knowledge store | Obsidian + Markdown | Ground truth, human-readable |
| Semantic search | `qmd` | Local BM25 + vector retrieval |
| Connection layer | MCP servers | AI ↔ vault read/write |
| Agent | Claude Code | Reasoning + execution |
| Persistent workflows | Claude Code skills | Reusable vault operations |

None of these pieces are exotic. The insight is in *how they connect*.

## The Foundation: Obsidian as a Local-First Knowledge Graph

I've been using Obsidian with the PARA method for a few years now. Two vaults: one personal,
one work. Daily journals, weekly reviews, project notes, reading highlights from Readwise,
architecture decisions, devlogs.

What makes Obsidian the right foundation isn't the plugins or the UI — it's the storage
model. Everything lives in plain Markdown files on your filesystem. No proprietary database.
No sync service you need to trust. The vault is just a folder.

That "just a folder" property is exactly what makes the rest of this stack possible.

## The Connection Layer: MCP

[Model Context Protocol](https://modelcontextprotocol.io) (MCP) is the piece that changed
everything. It's an open protocol that lets AI models talk to external tools through a
standardised interface — think of it as USB-C for AI integrations.

For Obsidian, there's
[`obsidian-mcp`](https://github.com/newtype-01/obsidian-mcp) — an MCP server that exposes
your vault as a set of tools Claude (or any MCP-compatible agent) can call: read a note,
search notes, create a note, list recent files, follow backlinks. Your AI can now
*navigate* your second brain rather than being told about it.

The configuration is straightforward — add it to your `~/.claude/mcp.json`:

```json
{
  "mcpServers": {
    "obsidian": {
      "command": "npx",
      "args": ["-y", "obsidian-mcp"],
      "env": {
        "VAULT_PATH": "/path/to/your/vault"
      }
    }
  }
}
```

Once connected, Claude can read your daily notes, check your project files, and write new
entries — all without you having to copy-paste anything. The first time Claude automatically
pulled context from my devlog to continue work from the previous session, I felt the gap
finally closing.

### Basic Memory: A Persistent Semantic Graph

One step further: [`basic-memory`](https://github.com/basicmachines-co/basic-memory) layers
a persistent semantic graph on top of your Markdown files. Every conversation with Claude
that touches your vault can leave structured knowledge behind — observations, relations,
entity links — all stored as standard Markdown that Obsidian renders beautifully.

The key pattern is in the note format:

```markdown
## Observations
- [decision] Chose qmd over Typesense for local-first semantic search — no server to run
- [principle] All knowledge stays in files I control

## Relations
- relates_to [[Search Architecture]]
- informs [[Claude Code Setup]]
```

This is how conversations *compound*. Each session adds to the graph rather than
evaporating. Install it with `uv tool install basic-memory`, point it at your vault, and
add it to your MCP config.

## Semantic Search: `qmd`

Native Obsidian search is keyword-only. When you have thousands of notes, "find everything
related to distributed tracing" returns either too much or nothing useful. What you actually
want is semantic retrieval: *find notes that are about this concept*, not just notes that
contain these words.

[`qmd`](https://github.com/qmd-lab/qmd) solves this. It's a local CLI tool that indexes
your Markdown collections with BM25 + vector embeddings + LLM reranking — no external API,
no data leaving your machine. The local-first constraint was non-negotiable for me: my vaults
contain work notes, personal reflections, architectural decisions — none of that should
touch a third-party indexing service.

Setup is a one-time index build:

```bash
# Add your vaults as collections
qmd collection add ~/Vaults/personal --name personal
qmd collection add ~/Vaults/work --name work

# Build the initial index
qmd embed -c personal
qmd embed -c work
```

Then searching feels like talking to someone who has read everything in your vault:

```bash
# Natural language — hybrid BM25 + semantic + rerank
qmd query "how did I decide on the authentication architecture" -c work

# Find by what the answer would sound like (HyDE)
qmd query $'hyde: A note explaining why I chose Obsidian over Notion'
```

`qmd` also ships an MCP server — add `qmd mcp` to your config and Claude can retrieve
semantically relevant notes *during* a session, without you manually pasting context. With
both `obsidian-mcp` and `qmd` wired in, Claude can find the right context from thousands of
notes *and* navigate to the full document: combining keyword precision with semantic recall.

## The Devlog Pattern: Making Activity Automatic

One of the highest-ROI things I've done is an automated devlog that writes itself.

The idea: at the end of each day, a Claude Code skill pulls activity from GitHub (PRs
opened, reviewed, merged), Jira (tickets closed, commented), and Things3 (tasks completed),
then synthesises a structured devlog entry and writes it to the Obsidian work vault:

```
work/devlog/2026/2026-05-21-Wed.md
```

Each entry has a consistent structure — summary, what I shipped, blockers, decisions made.
`qmd` indexes everything, so future sessions can retrieve it semantically. "What was the
context around the auth refactor last March?" becomes a real question Claude can answer from
*your own notes*.

The MCP stack that makes this work:

```json
{
  "mcpServers": {
    "github":    { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-github"] },
    "atlassian": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-atlassian"] },
    "things":    { "command": "uvx", "args": ["things-mcp"] },
    "obsidian":  { "command": "npx", "args": ["-y", "obsidian-mcp"] }
  }
}
```

The skill aggregates data from all four sources, synthesises the entry, and writes it. No
manual journaling required — the record keeps itself.

## The LLM Wiki Pattern

This is the idea I keep coming back to. Andrej Karpathy described something like it: an
"LLM wiki" where sessions write back what they learn, creating a compounding knowledge base
rather than ephemeral conversations. Turned inward, the same pattern applies to personal
knowledge: each session makes the next one smarter.

The practical implementation in Obsidian:

1. **Every significant session leaves a trace.** Decisions, discoveries, rejected
   approaches — all written to structured notes in the vault via a skill.
2. **Notes link to each other.** New context connects to existing knowledge via
   wikilinks and the `Relations` block from basic-memory.
3. **`qmd` indexes everything.** Future sessions retrieve relevant prior context
   automatically.
4. **Skills encode recurring operations.** The `vault-wiki` skill in Claude Code handles
   the ingestion protocol so every session follows the same pattern.

The result: Claude gets *better at working with your specific context* over time, because
accumulated knowledge lives in your vault and gets loaded via semantic retrieval at session
start.

```bash
# At the start of a heavy session:
qmd query "recent decisions about [current project]" -c work -n 5
# Paste the relevant hits into the session context
```

## Claude Code Skills as Persistent Vault Workflows

Claude Code skills are Markdown files that describe a reusable workflow. I've built a small
set specifically for vault operations:

**`vault-wiki`** — Ingest a source (meeting notes, article, session summary) into the LLM
Wiki layer. Handles entity extraction, relation linking, and writing structured notes to the
vault.

**`obsidian:obsidian-cli`** — Interact with the vault from the terminal: create notes,
search, read properties, manage tasks. Useful for scripted operations outside a full Claude
session.

**`qmd`** — Full semantic search workflow with collection-scoping, query-type selection,
and follow-up `get` for full documents.

**`reader-recap`** — Pull recent Readwise highlights, synthesise insights, write a note to
the vault. Reading becomes a vault operation.

The pattern for authoring a new skill is simple: write a Markdown file in
`~/.claude/skills/<name>/SKILL.md` describing the workflow, the tools it uses, and example
commands. Claude routes to it automatically when the matching keywords appear in a prompt.
Your recurring workflows become first-class tools.

## The Practical Getting-Started Path

If you're starting from zero, this is the order that makes sense:

**Week 1: Add semantic search.** Install `qmd`, index your vault, start using it for
retrieval. This immediately makes your existing notes more useful — no AI agent required
yet.

**Week 2: Add `obsidian-mcp`.** Wire it into Claude Code or your editor. Start asking
Claude questions that require vault context and watch it navigate your notes.

**Week 3: Add `basic-memory`.** Let sessions write structured observations back to your
vault. After a month, you'll have a genuine knowledge graph of your work and thinking.

**Ongoing: Build skills for your recurring workflows.** Every time you catch yourself doing
the same thing twice — synthesising meeting notes, summarising a project week, writing a
decision record — turn it into a skill.

## What Changes

The shift isn't just productivity. It's epistemic.

When your AI tool can read your actual notes, you stop describing your context and start
*using* it. "What did I decide about X?" is no longer a question you answer from memory —
Claude retrieves it from your vault and quotes you back to yourself.

When sessions leave structured traces in the vault, knowledge compounds across months rather
than evaporating between tabs. The vault becomes a living record of how you think, not just
what you captured.

And when the whole stack is local-first — files on your disk, embeddings in a local SQLite
database, no data leaving your machine — you can extend it without worrying about what
you're handing over.

The second brain was always meant to be an extension of your cognition. Connecting it to AI
tools is just finishing the job.

---

*Tools mentioned: [obsidian-mcp](https://github.com/newtype-01/obsidian-mcp),
[basic-memory](https://github.com/basicmachines-co/basic-memory),
[qmd](https://github.com/qmd-lab/qmd),
[Claude Code](https://claude.ai/code). Related earlier post:
[Vibe Coding with Cursor](/posts/2024-03-21-vibe-coding-with-cursor/).*
