---
title: "My Daily Working System"
description: "How I actually work: Things3 for task capture, isolated workstreams per task, Claude Code in every terminal, and Obsidian as the exocortex. An honest account of the stack, the friction, and what I'm still building."
date: 2026-05-21T00:00:00Z
publishDate: 2026-07-17T00:00:00Z
draft: true
categories:
  - journal
  - tools
tags:
  - productivity
  - workflow
  - claude-code
  - tmux
  - obsidian
  - things3
  - git
  - tools
  - blog
showToc: true
tocOpen: false
---

> TL;DR: I capture everything in Things3, pull tasks into isolated worktrees with a single shell command, run Claude Code inside each one, keep notes in Obsidian, and am slowly replacing the shell glue with a Go CLI called `af`. It works well enough that I felt like writing it down.

I've been meaning to document my working system for a while, mostly for myself. Every few months I rebuild some piece of it and immediately forget why I made the choices I did. So this is that document — a snapshot of how I actually work in mid-2026, what each tool does, and what's still rough around the edges.

---

## The problem this system is solving

Before I describe the tools: what problem am I actually trying to solve? "Productivity system" is one of those phrases that hides a lot of variance.

My work spans multiple contexts that genuinely don't belong together:

- Deep work on Go internals at Datadog (compile-time instrumentation, AST manipulation, profiler integration)
- Open-source contributions that need their own branches and conversations
- Personal projects (`af`, this blog) that I pick up and put down across weeks
- Writing — notes, blog posts, ADRs, documentation

The enemy is **context bleed**. Switching from one task to another without fully resetting means carrying mental residue: open tabs from the last problem, a half-written test, a terminal still in the wrong directory, an AI conversation that thinks it's still working on issue #42 when you're now looking at issue #71.

I used to fight this with discipline. That didn't work. The system I have now fights it with structure: each task gets its own isolated environment, and switching contexts means switching environments.

---

## Task layer: Things3

Everything I might ever work on goes into Things3. I use it as a capture-first inbox that I triage once or twice a week, not as a real-time tracker.

The tags are what make it work for prioritization:

- **Priority**: `P0`, `P1`, `P2` — I don't trust "Today" in task managers because every day you snooze something looks like today
- **Energy**: `High Mental Energy`, `Low Mental Energy` — because not all tasks deserve a fresh morning brain, and lying to yourself about this is how important-but-hard things stay perpetually unstarted
- **Role**: `architect`, `coder`, `mentor`, `communicator`, `researcher` — useful for batching context switches

The inbox is almost always bloated. At last count it held around 970 items, which is somewhere between "honest capture" and "avoidance behaviour." I triage it down in grooming sessions every week or two, but there's always more coming in than going out. I've made peace with that.

The most useful tag combination is `P0` + `High Mental Energy`. That's the list I open on Monday morning when I have energy and no meetings yet. Everything else can wait.

What I don't use Things3 for: tracking progress on active work, daily notes, or anything that needs a conversation thread. Those live in Obsidian.

---

## Isolation layer: workstreams

This is the part of the system I've spent the most time on, and the part that matters most.

The core insight is simple: **a task is a branch, and a branch should have its own everything** — its own file tree, its own terminal session, its own AI conversation.

Git worktrees solve the file tree problem. Instead of stashing and switching branches, I create a worktree at a stable path:

```
~/Workspace/.worktrees/<repo>/<branch>/
```

This means `issue-42` and `feature-auth` can both be checked out simultaneously, in separate directories, without touching each other.

tmux solves the terminal problem. One named session per task, so I can detach and reattach without hunting for my place.

Claude Code solves the AI conversation problem. Each worktree gets its own session, and because I use a deterministic session ID derived from the branch name (uuid5 over `repo/branch`), the same session always maps to the same conversation — even across reboots.

All of this was originally a shell function called `claude-focus` (aliased to `cf`). I wrote about it [here](/posts/one-command-isolated-claude-code-sessions/). The short version: `cf issue-42` does the entire setup in one command, and `cfr` resumes from wherever you left off.

That shell function still exists and still works. But I've been slowly replacing the glue with a proper Go CLI called `af` (agentic-flow). The motivation: shell functions don't compose cleanly, can't be unit-tested, and accumulate edge cases in ways that are painful to audit. A Go binary with `testscript` golden tests and `golangci-lint` on all linters is a different story.

`af` calls a workstream what `cf` calls a focus session: the triple of a worktree, a tmux session, and one or more running agents. Lifecycle looks like:

```
af create issue-42   →  active
af suspend issue-42  →  suspended (tmux down, VM destroyed if any)
af resume  issue-42  →  active again
af done    issue-42  →  completed
```

The state lives in `~/.local/share/af/v1/sessions/<name>/state.toml`. No hidden tmux env vars, no fragile shell state.

`af` is still being built — it's not at feature parity with `cf` yet. In the meantime the two coexist: `cf` for existing sessions, `af` for new work where I want proper lifecycle semantics.

---

## Development layer: TDD with AI in the loop

Once I'm inside a workstream, the development loop is deliberately boring:

1. Write the test. Watch it fail.
2. Write the minimum implementation to make it pass.
3. Refactor. Run `make check`.
4. Commit.

`make check` runs `gofumpt`, `goimports`, `golangci-lint` (all linters, no exceptions), and `go test -race -count=1 ./...`. If any of it doesn't pass, the work isn't done.

Claude Code is the inner loop accelerant. I don't use it to write code I don't understand — I use it the way I'd use a very fast pair programmer. I describe the problem, it sketches an approach, I critique the sketch, it implements, I review. The session context means it remembers the design decisions from earlier in the session without me having to re-explain them.

The key discipline: the AI's output is a draft. I read every diff before it lands. The test suite is the ground truth, not the AI's confidence.

For larger multi-issue work, `af` can spawn parallel subagents — each in its own sub-worktree on a sibling branch (`<branch>--slot-0`, `<branch>--slot-1`) — with their isolated Claude sessions. This is overkill for most tasks and essential for a few.

---

## Documentation layer: ADRs and PROGRESS

I write an Architecture Decision Record for every non-trivial technical choice. This sounds heavyweight but isn't in practice — each ADR is a short markdown file answering: what did I decide, why, what alternatives did I reject, what are the trade-offs?

The benefit isn't process. The benefit is that when I come back to a project six weeks later with no memory of why the config file is TOML and not YAML, there's an ADR that explains it. ADRs also make it easier to spot when I'm about to make the same mistake twice.

PROGRESS.md is the narrative log — one section per work session, what was done, what's next, what decisions were made before they got their own ADR. It's the log I'd want to read at the start of a new session instead of `git log`.

Both files are append-only. No rewriting history.

---

## Notes layer: Obsidian + qmd

Obsidian is the exocortex. I keep two vaults: personal and work.

Work vault structure follows PARA (Projects, Areas, Resources, Archive). Project notes contain:
- The brief and context
- Meeting notes
- Design scratchpad
- Links to ADRs

Personal vault has journals, reading notes, blog drafts, and the occasional long note on something that doesn't fit in a project.

The vaults are indexed by `qmd`, a local-first search tool I run via CLI or MCP. It supports BM25 keyword search, vector embeddings, and LLM reranking. In practice I use it like grep on a corpus I can't remember the shape of: "find the note where I was thinking about GLS leak detection" → three results, pick the right one, full document in hand.

The integration that's still half-baked: Obsidian notes per workstream, linked from `state.toml`. The vision is that `af create` creates not just the worktree and tmux session but also a note stub in the work vault. I have the shape of this designed (ADR-047), I just haven't built it yet.

---

## Publishing layer: blog as exocortex output

The blog is Hugo + PaperMod, deployed to Netlify. I've had this setup for years and it's invisible, which is exactly what I want from a publishing stack.

What I'm trying to do with the blog: turn the good stuff from the notes layer into something that survives outside my own context. The process is roughly: idea → Things3 → grows in Obsidian → becomes a post draft → edited → published.

In practice it's messier. Most ideas sit in Things3 forever. Some get as far as a draft that lives in the blog repo as `draft: true` for months. A few make it out.

The `one-command-isolated-claude-code-sessions` post started as a PROGRESS.md entry, became a plan file, became a draft, and finally shipped after I'd already iterated on the underlying `cf` function three times. That feels about right for this kind of content: let the ideas settle before publishing them.

---

## What's still rough

Honest accounting:

**Things3 inbox at ~970 items.** Capture is working. Triage is not. I'm not sure there's a fix that isn't just "do the triage."

**`af` is still under construction.** The `cf` shell function exists and works. `af` exists as documentation and ADRs. The gap between them is implementation work I'm doing in the margins. This is fine but means the "workstream" abstraction I described above is partly aspirational.

**Obsidian-workstream integration is a sketch.** The notes live in the vault; the link to the active workstream doesn't exist yet. I manually maintain the connection, which means I sometimes don't.

**The blog-from-notes pipeline has friction.** Getting from a good Obsidian note to a published post requires enough manual effort that it doesn't happen as often as it should. I suspect the fix is better tooling around that transition, not discipline.

---

## Why write this down

Partly for future me, who will have forgotten all of it.

Partly because I've been building `af` for a few months and the act of describing the system it's supposed to support made the design clearer. A few of the ADRs I'm writing right now came directly from writing this post.

And partly because the tooling conversation in the developer community has moved so fast in the last two years — from "GitHub Copilot autocomplete" to "AI agents in isolated worktrees spinning up parallel subagents" — that I think it's worth more people documenting what their actual system looks like. Not the idealized version, but the one with the bloated inbox and the half-built CLI and the draft post from three months ago that still has `draft: true`.

This is mine.
