---
description: Capture a technical moment as a blog draft. Supports blogmentation (short-form solution posts) with optional weekly session-log review mode.
allowed-tools: Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(recall:*), Bash(python3 ~/.agents/skills/recall/scripts/recall.py:*), Bash(ls:*), Read, Write, Edit
---

# /capture — Capture a technical moment as a blog draft

Dispatches to a capture-type skill based on the first argument.

## Usage

```
/capture <type> [flags] [topic]
/capture blogmentation [--weekly [--since Nd]] [topic]
```

## Supported capture types

| Type | What it creates | Invoke | Skill |
|---|---|---|---|
| `blogmentation` | Short-form solution post (300-800 words), categories: [blogmentation] | `/capture blogmentation [topic]` | `.agents/skills/blogmentation/SKILL.md` |

Additional types (`post`, `idea`) are not wired yet. If an unknown type is
passed, print:

> Unknown capture type: `<type>`. Supported types: `blogmentation`.

## Dispatch

Parse `$ARGUMENTS`:

1. Extract the first word as `<type>`.
2. Pass the remainder (`[flags] [topic]`) to the skill.

For `blogmentation`:

Read `.agents/skills/blogmentation/SKILL.md` and follow the instructions
there, passing the remainder of `$ARGUMENTS` as the skill's `$ARGUMENTS`.

- If `--weekly` is in the remainder → the skill enters **Weekly mode**
  (session-log review, candidate list, no auto-drafting).
- Otherwise → the skill enters **single-topic capture** mode.

## Examples

```
# Capture a specific fix
/capture blogmentation goproxy fallback behind vpn

# Capture from git context (auto-detect)
/capture blogmentation

# Weekly review — surface this week's candidates
/capture blogmentation --weekly

# Weekly review with a longer window
/capture blogmentation --weekly --since 14d
```
