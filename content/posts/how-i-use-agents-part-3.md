---
title: "How I Use Agents, Part 3: One Memory, Many Harnesses"
description: "My CLAUDE.md is a symlink. One AGENTS.md and one set of guard scripts serve Claude Code, pi, and codex, and a model router decides who does the work."
date: 2026-07-09T00:00:00Z
publishDate: 2026-09-15T00:00:00Z
categories:
  - blogmentation
tags:
  - blog
  - agentic-coding
  - claude-code
  - pi
  - ai
  - tools
series: "How I Use Agents"
showToc: true
tocOpen: false
draft: true
promote: false
---

My `CLAUDE.md` is a symlink.

It points at a file named `AGENTS.md`, and that file does not care which agent is reading it. [AGENTS.md](https://agents.md) is an open convention these days — "a README for agents," stewarded under the Linux Foundation — but I would have arrived at the symlink out of plain laziness anyway. I was not going to maintain three copies of "don't commit to main" in three vendor dialects.

## One memory

Each agent gets the same file through whatever door it prefers. [pi](https://pi.dev) reads `~/AGENTS.md` natively. codex reads a symlink at its own config path. Claude Code imports it from the global `CLAUDE.md` with a one-line `@~/AGENTS.md`. The rules live exactly once: coding style, security posture, git workflow, the worktree policy from [Part 2](/posts/how-i-use-agents-part-2/), and every correction I have caught myself making twice — [Part 1](/posts/how-i-use-agents/)'s rule about promoting repeated chat corrections into files applies across agents, not per agent. At the top sits a five-clause working agreement, priority-ordered: ask don't assume, right-size the solution, stay in scope, flag uncertainty, suggest better ways.

The vendor-named file is an entry point, not a source of truth.

Memory also flows the other way. A small CLI I call `recall` indexes the transcripts of all of it (Claude Code, codex, pi, and Claude Desktop) into one searchable store (full-text plus BM25 plus recency). "What did I decide about the retry backoff" is one query across every agent I have ever discussed it with, which is the point: the conversations belong to me, not to whichever harness hosted them. Three weeks in, that index holds 885 sessions and just under twenty thousand messages.

## One set of guards

Some policies have to hold no matter which agent is driving. The load-bearing one for me: no edits on `main` or `master` outside a worktree, ever.

In Claude Code that is a `PreToolUse` hook calling a guard script. In pi it is a small TypeScript extension that intercepts the write tools and shells out to the *same script*. For codex, the same script again. One law, three courthouses. When the policy changes, I edit one file of bash and every agent obeys at once.

This matters more for pi than for the others, because pi has no permission popups by design. The guard script is not a second layer of defense there; it is the layer.

## Different philosophies, same habits

Claude Code is batteries-included: plan mode, permission prompts, compaction, subagents, skills, a diff panel. pi ships almost none of that, on purpose. Its site says "There are many agent harnesses—but this one is yours," and the design language is primitives, not features: no built-in MCP, no subagents, no plan mode, no permission popups. You add what you need as TypeScript modules, and what you don't add doesn't exist.

Claude Code is a furnished apartment. pi is a well-plumbed empty one. I keep keys to both.

`af` from [Part 2](/posts/how-i-use-agents-part-2/) treats them as interchangeable providers behind one interface ([ADR-043](https://github.com/kakkoyun/af/blob/main/docs/adr/043-agent-providers.md)), and the seams show exactly where the philosophies differ. Claude launches with a deterministic `--session-id` and has a skip-permissions flag I only allow inside sandboxes; pi launches bare, resumes with `--continue`, and has no such flag at all, because approvals are its own internal business. codex, the third key on the ring, splits the difference with two profiles: one configured to plan, one to implement. Real differences — and all of them below the habit layer. Plan first, fresh sessions, write it down: none of that cares which binary is running. My own logs make the case better than I can: fifty-one plan-mode approvals in the last week, and the single most common opening prompt across my history is, verbatim, "Implement the following plan:".

## The router

My pi setup runs a model router with three profiles: deep, cheap, and an auto mode that picks between them. Keywords escalate — "security" or "deploy" routes deep, "typo" or "lint" routes cheap. A per-session budget caps spend at ten dollars. When a provider rate-limits, the router degrades to local models running under Ollama: slower, free, always on. Subagents are tiered the same way — planners and reviewers get the big model, workers the middle one, scouts the small one.

The router has no loyalty. As I write this, pi's default model is not an Anthropic one, while the heavy review work still routes to Claude models. That is not a contradiction; it is the point. Habits stay put while providers rotate underneath them.

## Where each wins, for me, today

Deep work on code I do not know: Claude Code, running its plan-then-execute model split (a big model argues about direction, a cheaper one types), because plan mode plus the review loop is still the best thinking surface I have used. Cheap parallel chores, and any day I want to change how the harness itself behaves: pi, because changing pi is a TypeScript file, not a feature request.

A postscript that proves the theme: Part 1 of this series was drafted with Claude Code's Explanatory output style. Between drafting and publication, the standalone `/output-style` command was deprecated and removed (gone in v2.1.91; it is a settings field now). A post in this series aged out of a command before it aged into print, which is most of the argument for keeping your habits one level above anyone's feature list.

The question I have not settled: does this converge or fragment? AGENTS.md spreading suggests convergence; every harness growing its own extension format suggests the opposite. I am betting on the habits either way. If your agents read a different file than mine, I would like to know which one.
