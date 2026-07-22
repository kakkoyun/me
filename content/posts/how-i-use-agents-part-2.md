---
title: "How I Use Agents, Part 2: One Workstream per Task"
description: "The 1,777-line shell function that ran my task isolation for a year, the Go tool replacing it, and why every agent task gets its own worktree, tmux session, and conversation."
date: 2026-07-09T00:00:00Z
publishDate: 2026-09-11T00:00:00Z
categories:
  - blogmentation
tags:
  - blog
  - agentic-coding
  - claude-code
  - pi
  - git
  - tmux
  - tools
series: "How I Use Agents"
showToc: true
tocOpen: false
draft: true
promote: false
---

The shell function that runs my task isolation is 1,777 lines long, and the TODO file next to it schedules it for deletion.

Both facts are correct, and the distance between them is this post. [Part 1](/posts/how-i-use-agents/) argued for fresh sessions: every conversation starts clean, and context comes from disk. This part is about where the freshness comes from, because a fresh conversation is not worth much if it opens in a dirty working tree.

## The rule

One task, one branch, one worktree, one tmux session, one agent conversation.

If any of those is shared between two tasks, the two tasks eventually share a mistake. You ask an agent to fix a bug while a half-staged refactor sits in the same tree, and twenty minutes later `git status` is archaeology: which of these changes is the fix, which is the refactor, and which is the agent helpfully "cleaning up" something it was never asked about. I stopped debugging that class of accident by making it impossible. Three weeks of my own session logs agree it stuck: 885 agent sessions, and nearly all of the code work happened inside a task worktree, never on `main`.

## `cf`: the shell function

The first implementation was a zsh function called `cf` (claude-focus). `cf issue-42` does five things in order: fetches and resolves the base branch, checks out a fresh worktree at `~/Workspace/.worktrees/<repo>/issue-42`, derives a session ID as uuid5 over the repo and branch, creates a detached tmux session named after the branch, and launches Claude Code with that session ID.

The uuid5 is the part I would keep if I had to throw away the rest. A deterministic ID means the same task always resumes the same conversation, on purpose, even after a reboot, so I never end up scrolling a session picker trying to remember which of nine conversations was the one about the flaky test.

Around `cf` grew a small family: `cfr` resumes (and falls back to `claude --continue` inside the worktree when the tmux session died with the machine), `cfd` tears down the session, worktree, and branch in one motion, `cfl` lists everything and flags orphans, `cf --from-pr 42` forks a worktree straight off a pull request, and `cfgc` garbage-collects worktrees whose branches merged. Unnamed tasks get generated names, so my session history reads like a ship manifest: `eloquent-cohen`, `naughty-dubinsky`, `clever-chaum`. There is a hard cap of ten live sessions. The cap exists because it has been hit.

Then the backends multiplied. Some tasks want the agent inside a microVM sandbox with the worktree mounted in. Some want the worktree local but the agent watched. Some want the whole session on a remote machine over SSH, where the build caches live. `cf` grew a flag for each.

I am not linking the source, because it lives in my private dotfiles. The design fits on this page anyway, and the interesting parts are above.

## Where bash ran out

Every one of those features works. Each also carries its own failure shape: metadata that has to survive reboots in sidecar files, a reconstruction path for when the metadata is missing, health checks before resume, backoff when SSH drops. Roughly thirty lines per edge case, and the edge cases compound.

The moment of clarity was `cfgc` learning to detect squash merges by fingerprinting diffs, because branch history alone can't tell you a squashed branch is safe to delete. When your shell function starts fingerprinting diffs, it is filing a formal request to become a real program.

## `af`: the same idea as a program

The request was granted. [`af`](https://github.com/kakkoyun/af) is the Go successor, and as of this summer it is public. The README's own pitch:

> **af** manages isolated AI-agent workstreams across git worktrees, tmux sessions, sandboxes, and SSH remotes.

Its [SPEC](https://github.com/kakkoyun/af/blob/main/docs/SPEC.md) names the unit `cf` never had a word for. A **workstream** is the triple of a worktree, a tmux session, and one or more agents ([pi](https://pi.dev) by default, `claude` or `codex` on demand). The lifecycle is a state machine instead of a pile of flags:

```
af create issue-42   →  active
af suspend issue-42  →  suspended  (tmux down, VM destroyed if any)
af resume  issue-42  →  active again
af done    issue-42  →  completed  (or abandoned)
```

State lives in a `state.toml` under `~/.local/share/af/v1/sessions/<name>/`, so there is nothing to reconstruct from tmux environment variables and no sidecar files to lose. When a task needs parallel subagents, each gets a sibling branch and sibling worktree named `<branch>--<slot>`, which is [ADR-038](https://github.com/kakkoyun/af/blob/main/docs/adr/038-workstream-and-worktree-layout.md)'s answer to two agents fighting over one file tree: full git isolation, and merge-back stays deliberately manual in v1 because I want to read what comes back. One Go interface drives all three agents ([ADR-043](https://github.com/kakkoyun/af/blob/main/docs/adr/043-agent-providers.md)). That abstraction is Part 3's whole subject.

Honest status: the v1 ADRs are closed (42 complete, one not-applicable, zero pending) and the remaining work is tagging v1.0.0. "Binaries are not published; this is a single-user tool," says the README, and it is right. Also honest: the migration is underway, not done. `cf` still lingers on my machine while `af` takes over task by task, and the primitive shell scripts get to watch their replacement being raised in a proper test suite.

## What transfers

If you use a different harness, or no harness, three things carry over anyway. Deterministic names buy you resumability for free; anything derived from `repo/branch` means never asking "which session was that." State belongs on disk, in a file you can `cat`, not in whatever your shell happened to export. And teardown deserves as much design as create: `cfd` and `af done` are the reason my machine has worktrees instead of a worktree midden.

The old ceiling on parallel work was typing speed. The new one is review bandwidth: ten concurrent workstreams fit in tmux, but they do not fit in my head. Claude Code's own usage report puts a number on it — this week, 39% of my messages were sent while at least one other session was running in parallel. [WakaTime](https://wakatime.com) keeps the other half of the ledger: where the hours actually went, by repo and by language, agent sessions included via its Claude Code plugin. The feeling of "that took all afternoon" gets checked against a number too. Some weeks my real number is three; some weeks it is one. If you run agents in parallel, I would genuinely like to know yours.
