---
name: blogmentation
description: >
  Captures a technical solution as a short-form blog post (300-800 words).
  Problem → solution → result structure. Auto-detects topic from git context.
  Supports weekly mode that scans recent Claude Code sessions and surfaces
  candidates for drafting. Creates Hugo drafts in categories: [blogmentation].
  USE WHEN user says "blogmentation", "capture solution", "blog this fix",
  "shipped it", "weekly blogmentation", or "blog from notes".
disable-model-invocation: true
argument-hint: "[--weekly [--since Nd]] | [topic]"
---

# /capture blogmentation — Capture a technical solution as a short-form blog post

"Blogmentation" — a short-form blog post documenting a technical solution, bug
fix, or learning. Lighter and faster than a full blog post: 300-800 words, code
snippets, imperative steps. Structure: **Problem → solution → result**.

Before drafting any prose, read `.agents/skills/kemal-voice/SKILL.md`
(symlinked at `.claude/skills/kemal-voice/SKILL.md`). All prose must pass the
authoring checklist there. Do not use any banned vocabulary or formulaic
openers.

## Arguments

- `$ARGUMENTS` — Topic or description of the problem/solution. If empty,
  auto-detect from git context. If `--weekly` is present, enter Weekly mode
  (see below) instead of single-topic capture.

---

## Single-topic capture (default)

### 1. Determine the topic

Parse `$ARGUMENTS`:

- If `--weekly` is present → skip to **Weekly mode**.
- If a topic string is provided → use it.
- If no argument is given → auto-detect from git context:
  ```bash
  git diff --stat HEAD~1
  git log --oneline -5
  git diff HEAD~1 --name-only
  ```
  Summarise what changed and confirm with the user:
  > Based on your recent changes, it looks like you [summary]. Want to
  > blogment this?

  If not in a git repo or no recent changes, prompt:
  > What problem did you solve, bug did you fix, or thing did you learn?

### 2. Capture the three elements

Ask the user for each, or extract from git context and ask to confirm:

**The Problem:**
> What was the issue? What error did you see, or what wasn't working?

**The Solution:**
> What fixed it? Include the key command, config change, or code.

**The Insight:**
> What's the takeaway? What would you tell someone hitting this for the first
> time?

### 3. Draft the blogmentation

Write 300-800 words. Follow the `blogmentation` tone from `kemal-voice`:
tutorial, code-heavy, imperative steps. Open with a concrete hook — an error
message, a number, a short anecdote. Do not start with a banned opener.

Structure:

```markdown
[Opening: 1-2 sentences that drop the reader straight into the problem.
 Start with a concrete observation — the exact error, the broken command,
 the confusing output. Not a template sentence.]

## The problem

[Describe the error, symptom, or situation. Include exact error messages or
output if available.]

```
[code block: error output, failing command, or broken config]
```

## The fix

[Explain the solution. Be specific and actionable.]

```
[code block: the fix, command, or config change]
```

## Result

[Show what success looks like — the passing command, the clean output, the thing that
 now behaves correctly. One concrete indicator that confirms the fix worked.]

## Why it works

[Explain the underlying cause and why the fix resolves it. Be specific about
the root cause, not just "this fixes it".]

## TL;DR (optional)

[Include only if the fix is a single command or one-liner worth calling out
for readers who scan. Skip if the fix is multi-step or context-dependent.]
```

Keep the tone direct and technical. Permit humour; a wry aside or
self-deprecating one-liner is on-tone. End on a trade-off or open question
rather than a summary paragraph.

### 4. Scaffold the Hugo post

Generate a kebab-case slug from the title (no date prefix). Verify that
`content/posts/` exists relative to the current working directory. If it does
not, inform the user and ask for the correct path.

Present the file to be created (path, title, tags) and **ask the user to
confirm before writing**.

Frontmatter template:

```yaml
---
title: "Post Title"
description: "One-sentence summary."
date: YYYY-MM-DDT00:00:00Z
publishDate: YYYY-MM-DDT00:00:00Z
draft: true
categories:
  - blogmentation
tags:
  - relevant-tech-tag
  - blog
showToc: false
tocOpen: false
---
```

Rules:
- `categories` must be `[blogmentation]`. Never `[deep-dive]`.
- Do **not** put `blogmentation` in `tags` — it belongs in `categories`.
- Always include `blog` in `tags`.
- Set `showToc: false` — these are short posts.
- Set `draft: true` — never publish directly from this workflow.
- Do not quote scalar YAML values (dates, booleans).

### 5. Cross-reference with Obsidian daily note (optional)

Check if the `obsidian-cli` skill is available. If so, append a link to the
blogmentation in today's daily note:

```markdown
- Blogmentation: [[Post Title]] — one-line summary
```

**Fallback:** Search for today's daily note in `~/Vaults/personal/` using
Glob and append manually. If the daily note does not exist or neither approach
works, skip and inform the user.

### 6. Create a Things 3 task

Check if Things 3 MCP tools are available (`things/add_todo`). If available,
present the task details and ask the user to confirm before creating:

> I'll create a Things 3 task: "Review and publish: Post Title" with tags
> writing, blog. Proceed?

On confirmation:
- Title: `Review and publish blogmentation: "Post Title"`
- Notes: `Draft at content/posts/<slug>.md`
- Tags: `writing`, `blog`

**Fallback:** If Things 3 MCP is not available, print the task in a copyable
format instead.

### 7. Present the result

Show:
- Full path to the created draft
- Brief summary of the post content
- Things 3 task (if created)
- Reminder: post is set to `draft: true`
- Suggestion: run `make prose` before opening a PR

---

## Weekly mode (`--weekly`)

Invoked when `$ARGUMENTS` contains `--weekly`. Surfaces candidates from the
past week of Claude Code sessions — does **not** auto-draft anything. The user
picks which candidates to convert into posts.

### W1. Determine the window

Default: last 7 days.

Accept `--since Nd` (e.g. `--since 14d`) to override. Parse the integer from
the flag and pass it as `--days N` to `recall`.

### W2. Enumerate blog session directories

Collect all blog-related session dirs. Claude Code encodes a project path by replacing
`/` with `-` and removing the leading `/`. Run the following to discover all matches
(adjust the pattern if your macOS username differs):

```bash
ls ~/.claude/projects/ | grep -E '^-Users-kemal-akkoyun-(Vaults-blog$|Workspace--worktrees-blog-)'
```

### W3. Collect sessions via recall

For each directory found above, run `recall` in list mode (no query = recency
list):

```bash
recall --project ~/.claude/projects/<dir> --days <N>
```

Underlying script (if `recall` is not on PATH):
```bash
python3 ~/.agents/skills/recall/scripts/recall.py \
  --project ~/.claude/projects/<dir> --days <N>
```

Skip dirs that `recall` reports as empty or non-existent.

### W4. Synthesize candidates

For each session returned, read the summary or opening exchange. Skip:
- Sessions with fewer than 3 substantive exchanges
- Session-start / onboarding noise with no concrete work
- Sessions that are entirely about planning (no shipped output)

For qualifying sessions, extract:
- One-line topic (what problem or task)
- The fix or insight (what was shipped or learned)
- Session id (for traceability)

### W5. Present candidate list

Format:

```
Found N candidate blogmentations from the past 7 days:

1. <slug-suggestion> — <one-line topic>
   Problem: <…>
   Fix / insight: <…>
   Session: <session-id>

2. <slug-suggestion> — <one-line topic>
   …
```

If no qualifying sessions are found, say so and exit.

### W6. Prompt for selection

> Which candidates would you like to draft as blogmentations? Enter numbers
> (e.g. "1 3") or "none" to skip.

For each selected number, run the **single-topic capture** flow (steps 2-7
above), pre-filled with the synthesised Problem / Fix / Insight. The user
confirms or edits before each draft lands.

**Do not auto-create drafts.** Always require explicit user selection.

---

## Common mistakes

- Setting `categories: [deep-dive]` — must be `categories: [blogmentation]`.
- Putting `blogmentation` in `tags` — it goes in `categories`, not `tags`.
- Over-explaining the problem — keep it under 800 words total.
- Omitting the actual error message or command output — readers need the exact
  error to confirm they have the same issue.
- Writing a vague "Why it works" section — be specific about the root cause.
- Using a banned vocabulary word (`delve`, `leverage`, `seamless`, etc.) —
  check against `kemal-voice` before writing.
- Skipping voice-gate step — re-read `kemal-voice` authoring checklist before
  drafting prose.
