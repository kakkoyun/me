---
title: "My Daily Working System"
description: "How I structure focused work in mid-2026: Things3 for capture, one isolated worktree per task with tmux and Claude Code, and a Go CLI called af that's absorbing the shell glue."
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
  - blog
showToc: false
tocOpen: false
---

I rebuild parts of this setup every few months and forget why I made the choices I did. So this is a snapshot of the version that works in May 2026, with enough references that future-me can argue with present-me.

## Capture: Things3

Everything possible goes into Things3. It's a capture-first inbox I triage on weekends, not a real-time tracker. The inbox currently holds around 970 items, which is somewhere between "honest capture" and "avoidance."

The tags do the actual work:

- `P0` / `P1` / `P2` — I don't trust "Today" because every snoozed thing looks like today.
- `High Mental Energy` / `Low Mental Energy` — important-but-hard tasks die when you lie to yourself about which is which.
- Role tags (`architect`, `coder`, `mentor`, `communicator`, `researcher`) — useful for batching context.

The query I open on Monday morning: `P0 + High Mental Energy`. Everything else can wait.

## Isolation: one worktree per task

A task is a branch, and a branch gets its own everything — file tree, terminal, AI conversation.

- Git worktrees check out one branch per directory at `~/Workspace/.worktrees/<repo>/<branch>/`.
- tmux runs one named session per task.
- Claude Code gets a deterministic session ID (uuid5 over `repo/branch`), so the same task always resumes the same conversation — even after a reboot.

This started as a shell function called `cf` (claude-focus), which I wrote up [here](/posts/one-command-isolated-claude-code-sessions/). `cf issue-42` does the whole setup; `cfr` resumes; `cfd` tears it down.

The shell function is now growing a Go successor called `af` (agentic-flow / automatic-flow / as-fuck, pick your mood). Same job, but with proper lifecycle semantics, layered config, and a test harness instead of accumulating bash edge cases.

`af` calls the worktree-plus-tmux-plus-agent triple a **workstream**:

```
af create issue-42   →  active
af suspend issue-42  →  suspended  (tmux down, VM destroyed if any)
af resume  issue-42  →  active again
af done    issue-42  →  completed  (or abandoned)
```

State lives at `~/.local/share/af/v1/sessions/<name>/state.toml` — no hidden tmux env vars, no fragile shell state [ADR-037, ADR-046]. The worktree layout, including subagent sub-worktrees at `<branch>--<slot>` on sibling branches, is pinned in [ADR-038]. Multiplexer is tmux-only [ADR-040]; agents are `claude`, `pi` (default), or `codex` behind a single Go interface [ADR-039, ADR-043].

`af`'s core (ADRs 031 through 065) is implementation-complete and runs my day. The heavy development right now is in newer ADRs — agent-session sync between VM and host, PR-state TTL caching, an `af review` command that drives a configurable PR review through any agent [ADR-073]. So this isn't a vapourware post; it's a tool I use, with new features showing up faster than I can blog about them.

## Development: TDD with Claude as draft generator

Inside a worktree, the loop is intentionally boring:

1. Write the failing test.
2. Write the minimum implementation.
3. Refactor.
4. Run `make check`.

`make check` runs `gofumpt`, `goimports`, `golangci-lint` (every linter on, no exceptions), and `go test -race -count=1 ./...`. If any of it is red, the work isn't done.

Claude Code accelerates the middle step. I describe the problem, it sketches an approach, I push back on the sketch, it implements, I read every diff. The AI's output is a draft; the test suite is the ground truth. I don't ship code I haven't read.

For multi-issue work, `af` spawns subagents in their own sub-worktrees on sibling branches (`<branch>--<slot>`), so they don't fight over the same files [ADR-038, ADR-039]. Overkill most days; essential a few times a month.

## Notes: Obsidian + qmd

Two Obsidian vaults — personal and work — structured PARA-style. I search across them with `qmd`, a local-first tool I run via CLI or MCP that combines BM25 keyword search, vector embeddings, and LLM reranking. In practice it's `grep` for a corpus I can't remember the shape of: *"find the note where I was thinking about GLS leak detection"* → three results, pick the right one, full document in hand.

The piece I haven't built yet: `af create` should stub out a note per workstream in the work vault, linked from `state.toml` [ADR-047]. Right now I keep the link manually, which means I sometimes don't.

## What's still rough

- **Inbox triage.** Capture is working; triage is not. No tool fixes this — only doing it does.
- **`af` ↔ `cf` overlap.** Both exist on my machine. I haven't migrated long-lived `cf` sessions to `af` yet, so I run both.
- **Obsidian linking** is designed in [ADR-047] but not implemented.
- **Notes-to-blog pipeline.** Getting from a good Obsidian note to a published post has enough manual friction that this post is its own counterexample — three drafts and a slop-cleaning pass before shipping.

---

If you want the working pieces: `cf` is documented in the [earlier post](/posts/one-command-isolated-claude-code-sessions/). `af` is single-user, single-machine, and not packaged for release — it solves my problem and the design is settled enough that I'd rather build the remaining features than productize the parts that work.
