---
title: "How I Use Claude Code: The Basics That Actually Help"
description: "The habits, settings, and mental models behind a daily Claude Code workflow — not the polished demo version."
date: 2026-05-21T00:00:00Z
publishDate: 2026-05-21T00:00:00Z
categories:
  - blogmentation
tags:
  - blog
  - claude-code
  - ai
  - productivity
  - tools
series: "How I Use Claude Code"
showToc: true
tocOpen: false
draft: true
---

Every post about AI coding tools sounds the same. Some tool "transformed" the author's workflow, and now they ship 10× faster, sleep better, and make their own pasta. This is not that post.

I've been using Claude Code daily for months — for my [personal CLI project `af`](https://github.com/kakkoyun/af), for incident investigations at work, for ADRs, for this blog. It's genuinely useful. It also requires deliberate habits to avoid it becoming a sophisticated way to generate confident nonsense.

This series is about the habits that actually help. We'll cover: plan mode, session hygiene, persistent tracking, worktree isolation with `claude-focus`, configuring output styles, and keeping work-specific context available without it leaking everywhere.

Part 1 covers the basics — the three things I'd tell anyone starting out.

---

## Start every session in plan mode

The single most impactful change I made: I press `Shift+Tab` twice before doing anything non-trivial. That switches Claude Code into plan mode, where it can read and reason but cannot write files or run commands. It can only propose.

The default instinct with any AI coding tool is to describe what you want and let it run. That works fine for small, self-contained tasks. For anything that touches multiple files or depends on project-specific conventions, the result is code that compiles but does the wrong thing — confidently.

Plan mode forces a conversation about *what* we're building before anything gets written. I put in:

- what I want to happen
- the current state (what exists, what's broken, what was tried)
- constraints that aren't obvious from the code (no new dependencies, test first, don't touch this module yet)

The plan that comes back is a checkpoint. I read it, push back on anything that looks wrong, and only then approve. Approving a plan is not approving a first draft — it's agreeing on intent. The implementation will have its own review loop. {{< sidenote side="alternate" >}}The plan approval step also forces me to articulate constraints I'd otherwise communicate mid-implementation, when Claude is already halfway down the wrong path.{{< /sidenote >}}

The 10–15 minutes spent in plan mode consistently saves more time than it costs. The sessions where I skip it are the ones where I end up reverting and starting over.

One more thing: plan mode also keeps the permissions model honest. When you approve a plan, you're approving *intent*, not granting a blank check to run arbitrary commands. The tool calls that follow still go through the normal approve/deny flow — plan mode just means you've seen the strategy before the tactics start.

---

## Open a fresh session for every distinct task

Claude Code remembers nothing between sessions by default. This sounds like a limitation. In practice it's a feature.

A clean session means no accumulated context drift. No "but I thought we agreed earlier that the cache should be invalidated eagerly." No session where Claude has been working with a subtly wrong assumption for an hour and every subsequent suggestion bakes in the error. The context window is a whiteboard; wiping it between tasks keeps it useful.

So: I open a new session for each distinct task. The cost of re-establishing context — the project conventions, the architectural constraints, the things Claude needs to know — is covered by [`CLAUDE.md`](https://docs.anthropic.com/en/docs/claude-code/memory) and project memory files. These load automatically at the start of every session and rebuild the relevant context without any conversational residue. {{< sidenote side="alternate" >}}CLAUDE.md is the constitution: rules that are non-negotiable, conventions Claude needs to know, architectural constraints. It runs at session start every time, so it's worth keeping precise and current.{{< /sidenote >}}

What I *do* keep across sessions: the permissions allowlist. The first time Claude asks to run `go test ./...`, I approve it and add it to `settings.json`. I don't want to approve the same low-risk command 40 times a day. The allowlist is the right place for "yes, always." The confirmation prompt is the right place for "yes, this time."

Fresh session + persistent permissions: clean context without friction.

---

## Write things down in the repo, not in the chat

Context windows compact. Long sessions degrade. Claude will helpfully pretend to remember things it no longer has access to.

The answer is to write things down in the repo itself, not in the conversation.

I keep two files per project:

- **`PROGRESS.md`** — a narrative log, appended at the end of each work session. What changed, what got blocked, what the next step is. One honest paragraph after each session is more useful than a detailed design doc written before you knew what you were doing.
- **`TODO.md`** — a checkbox task list. I mark things done as I go and add blockers as inline notes.

Inside a session, I use Claude Code's `TodoWrite` tool to track work in flight. The key property: task state created with `TodoWrite` survives context compaction. The conversation history gets trimmed; the task list does not. Claude keeps tracking what's done and what's pending even when it can no longer read the messages that created the tasks. {{< sidenote side="alternate" >}}Think of TodoWrite as a shared scratchpad that lives outside the conversation scroll. When sessions get long, it's what keeps things coherent.{{< /sidenote >}}

The combination of `PROGRESS.md` (cross-session narrative), `TODO.md` (cross-session checklist), and `TodoWrite` (in-session state) means there's always a clear answer to "where were we?" — whether that question comes from me opening the project after a week away, or from Claude after the context window has been compacted.

---

## What's next in the series

Three habits — plan mode, fresh sessions, persistent tracking — are enough to make Claude Code reliably useful day-to-day. The rest of the series goes deeper:

- **Part 2: Session hygiene with `claude-focus`** — worktree-isolated sessions that keep the main branch clean while agents do their work
- **Part 3: Output styles and `/insights`** — configuring Claude to explain its reasoning as it works, and why that's worth the token overhead
- **Part 4: Company context** — keeping work-specific knowledge (internal systems, conventions, on-call playbooks) available without it leaking between personal and work projects

None of this is magic. It's just enough structure to make the tool predictable.
