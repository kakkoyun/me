---
title: "How I Use Claude Code, Part 1: Plan First, Fresh Sessions, Write It Down"
description: "Three habits I actually use day-to-day on a single-user Go project, with one anecdote per habit and what the docs actually guarantee."
date: 2026-05-22T00:00:00Z
publishDate: 2026-09-01T00:00:00Z
categories:
  - blogmentation
tags:
  - blog
  - claude-code
  - ai
  - productivity
  - tools
  - agentic-coding
series: "How I Use Claude Code"
showToc: true
tocOpen: false
draft: true
promote: false
---

I had twenty-three architectural decision records to write, and no idea in what order.

This was day one of pivoting [`af`](https://github.com/kakkoyun/af) from Rust to Go. I knew the scope (Go module layout, CLI framework, multi-agent model, tmux integration, SSH remote, sandbox, secrets, lint, …). What I didn't know was the dependency graph — which decisions blocked which.

So I pressed `Shift+Tab` twice. That switches Claude Code into [plan mode](https://code.claude.com/docs/en/permission-modes#analyze-before-you-edit-with-plan-mode), where it reads and explores but cannot write or run commands.[^1] The session became a forty-minute argument about ordering. Zero files touched.

This is the post about why I do that, and two other habits that work alongside it.

---

## 1. Plan first

The plan we settled on that day became Stages A through E in `PROGRESS.md`: archive the old docs (A), scaffold v1 docs (B), write the spec and conventions (C), land 23 ADRs (D), build the index (E). One commit per ADR. The whole thing is logged under `2026-05-06 — Session 0` in [PROGRESS.md](https://github.com/kakkoyun/af/blob/main/PROGRESS.md).[^2]

The plan didn't write itself, and I'm not pretending it could. What plan mode does is make you commit to the *shape* of the work before any line of it goes on disk. Without that step, by ADR-036 I would have realized that 033 depended on a decision I'd made implicitly in 031, and the next hour would have been reconciliation.

What I put in the plan prompt, every time:

- what I want to happen
- what already exists (file paths, current state, recent commits)
- what I've already tried
- constraints that aren't visible from the code (no new dependency, must land in atomic commits, don't touch this module yet)

The plan that comes back is not a first draft. It is a contract for the direction of the work. The implementation step has its own review loop. {{< sidenote side="alternate" >}}Approving a plan exits plan mode and lets you pick the permission mode that follows (manual review, accept-edits, or auto). The default cycle from `Shift+Tab` is `default → acceptEdits → plan`.{{< /sidenote >}}

Plan mode does not help with everything. When the right next move is "explore the codebase and tell me what's there," staying in plan mode just means exiting it a minute later. I sometimes spend ten minutes in default mode reading, then drop into plan mode once I have an actual question to plan around. Plan mode is for "what should we do next," not "what is going on here."

---

## 2. Fresh sessions, persistent permissions

Each Claude Code session begins with a fresh context window.[^3] That's documented and deliberate.

What gets re-established at the start of every session is what's on disk: project-root `CLAUDE.md`, auto-memory, the `.claude/rules/` directory, the allowlist in `settings.json`. What does *not* get re-established is the conversation. That's the single most useful default Claude Code has.

A clean session means I haven't been arguing with Claude for an hour about a thing I was wrong about. The next prompt sees the project the way a stranger would, except with my CLAUDE.md preloaded as the briefing.

Concretely: my global `~/.claude/settings.json` allowlist has 92 entries as I write this. That has been the working line for months. The first time Claude wanted to run `gh pr view`, I approved it once and added it. Every session since has run `gh pr view` without asking. Same for `git diff`, `make check`, `go test`, the rest. Because the allowlist has absorbed the prompts I'd otherwise be answering by hand, the cost of running a new session is effectively zero.

A snippet of the kind of thing that lives in there:

```json
{
  "permissions": {
    "allow": [
      "Bash(make check)",
      "Bash(go test:*)",
      "Bash(git diff:*)",
      "Bash(gh pr view:*)",
      "Read(//Users/kemal/.config/git/**)"
    ]
  }
}
```

What I do *not* put in the allowlist: anything that writes to protected paths, anything that pushes, anything that touches secrets, anything that modifies shared infrastructure. The allowlist is where "yes, always, this is fine" lives. The permission prompt is where "let me think about this one" lives.

Two corrections to my own first instinct. The first: Claude Code does not "remember nothing between sessions." The conversation is saved on disk, resumable via `claude --continue` or `claude --resume`.[^4] I almost never use them, because that buys me the drift I was trying to avoid. The second: if I find myself correcting Claude on the same thing twice in different sessions, the correction belongs in CLAUDE.md, not the chat. CLAUDE.md is documented to survive `/compact`[^5] and to reload at every session start.

---

## 3. Write it down

The handover snapshot at the top of `TODO.md` in `af` currently reads:

> **Status at HEAD `9f0227c`** (2026-05-22, after Stage 11 + the gap-analysis pass + ADR-073 design):
>
> Every numbered ADR from **031 to 065** is `implementation: complete`. `pending` ADRs: **066** (VM agent-session export), **067** (automatic agent-session sync), **068–072** (operational UX, boundary & privacy, session selection, PR state cache, state.toml schema), **073** (`af review` repo-aware PR review).
>
> `make check` is green: 0 lint, all 21 packages pass `-race -count=1 -shuffle=on`.

That's the canonical answer to "where were we." I write it by hand after each session, in plain English, with commit hashes and ADR numbers. The first thing I read when I come back to the project. The first thing Claude reads, too, because `TODO.md` is referenced from `CLAUDE.md`.

I keep two files per project:

**`PROGRESS.md`** is a chronological narrative log, append-only. One section per work session: goal, what got done, what's blocked, next step. The `af` project's log is at 1,740 lines and eleven sessions. I write the entry at the *end* of the session, when I know what actually happened rather than what I hoped would happen.

**`TODO.md`** is a snapshot of what's pending. Updated as work moves. Has a "Handover snapshot" block at the top that I refresh after each session.

Inside a session I do use Claude Code's `TodoWrite` tool to track work in flight. But I do not trust it for cross-session continuity, and here's why. The docs publish an explicit table of what survives `/compact`:[^6]

| Mechanism | After compaction |
| --- | --- |
| System prompt and output style | Unchanged |
| Project-root CLAUDE.md and unscoped rules | Re-injected from disk |
| Auto memory | Re-injected from disk |
| Invoked skill bodies | Re-injected, with caps |
| Path-scoped rules, nested CLAUDE.md | Lost until trigger file is read again |
| Hooks | Not applicable; hooks run as code, not context |

The conversation itself isn't in the table — the same docs page notes above it that the conversation is replaced with a summary. The in-session task list rides with that summary. CLAUDE.md and auto-memory get re-injected verbatim. If I want a piece of state to mean the same thing tomorrow as it does now, it goes on disk in a file my own CLAUDE.md references.

This isn't an obscure failure mode; I have caught it. From `PROGRESS.md` session 8, verbatim:

> Agent B initially overwrote `PROGRESS.md` with a 10-line stub when it tried to update the file as part of its docs sync. The coordinator detected the regression in `git status`, reverted via `git checkout HEAD -- PROGRESS.md`, and (this session entry) is the authoritative update. No other agent touched outside their declared file boundaries.

What matters is that I detected the regression *because the file was on disk and `git status` told me*. If `PROGRESS.md` had only existed in the conversation, the bad stub would have replaced the good content silently, the compaction would have summarized over the original, and I would have lost it.

Disk is the canon. Chat is the working memory.

---

## What's next

Plan mode has a tax I still misjudge. I sometimes reach for it before I have a question worth planning, and ten minutes of reading in default mode would have gotten me further. What I'd like is a better instinct for when to press `Shift+Tab` in the first place: the signal that says "stop reading, start arguing about direction." I don't have it yet.

Part 2 covers `claude-focus`: worktree-isolated sessions that keep `main` clean while agents work on branches. Part 3 is about output styles, including the [Explanatory](https://code.claude.com/docs/en/output-styles) style I used to draft this one, and what gets paid for in tokens.

---

## References

[^1]: "Plan mode tells Claude to research and propose changes without making them. Claude reads files, runs shell commands to explore, and writes a plan, but does not edit your source." — [Permission modes — Analyze before you edit](https://code.claude.com/docs/en/permission-modes#analyze-before-you-edit-with-plan-mode).

[^2]: [`af/PROGRESS.md`, Session 0 (2026-05-06)](https://github.com/kakkoyun/af/blob/main/PROGRESS.md).

[^3]: [Memory — How Claude remembers your project](https://code.claude.com/docs/en/memory).

[^4]: [Common workflows — Resume previous conversations](https://code.claude.com/docs/en/common-workflows#resume-previous-conversations).

[^5]: "Project-root CLAUDE.md survives compaction: after `/compact`, Claude re-reads it from disk and re-injects it into the session." — [Memory — Troubleshoot memory issues](https://code.claude.com/docs/en/memory#instructions-seem-lost-after-compact).

[^6]: [Context window — What survives compaction](https://code.claude.com/docs/en/context-window#what-survives-compaction).
