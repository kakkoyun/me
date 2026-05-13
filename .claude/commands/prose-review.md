---
description: Prose-focused review of a pull request. Wraps the upstream code-review plugin with prose-specific priorities (banned vocab, formulaic openers, em-dash density) for blog post PRs under content/posts/ or content/talks/. Argument is a PR reference like owner/repo/pull/N.
allowed-tools: Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr comment:*), Bash(gh search:*), Bash(gh issue list:*), Read
---

# Prose review

/code-review:code-review $ARGUMENTS --comment

Apply the review above as a PROSE-ONLY review of a blog post under `content/posts/` or `content/talks/`.

Before commenting, read:

1. [REVIEW.md](../../REVIEW.md) — target tone, banned vocab, patterns to scrutinise.
2. [.claude/skills/kemal-voice/SKILL.md](../skills/kemal-voice/SKILL.md) — replacements for banned vocab, formulaic openers, editing checklist, tone-by-category notes.

Review only the prose changes on the PR diff. Skip code blocks, frontmatter, shortcode arguments, and link targets.

Target tone for the blog: clear, explanatory, fun, whimsical, honest, open. The author takes the technical material seriously but does not take themselves seriously. Use this as your calibration when judging "does this sound right".

## Findings to flag, in priority order

1. **Banned vocabulary** from the Vocabulary list (delve, tapestry, leverage, utilize, seamless, paradigm, ecosystem, etc.). High priority.
2. **Formulaic AI openers** (paragraph starts with "In this post, we'll", "Let's dive into", "It's worth noting that", "At its core", "In conclusion", etc.). High priority.
3. **Em-dash density**: 3+ em-dashes packed into one paragraph reads as AI-flavored. A single em-dash is fine.
4. **"It's not X, it's Y" negative parallelism**: classic AI rhetorical pattern. Flag if the contrast is not load-bearing. A genuine contrast is fine.
5. **Triadic rhythm** used more than once in a post. A single triad is fine; recurring triads feel like a tic.
6. **Marketing or self-important tone**. Anything that sounds like a press release.

## Do not flag

- First person, contractions, or casual phrasing — those are on-tone.
- Humor, asides, self-deprecation, or whimsy — those are on-tone.
- Passive voice in technical contexts where the actor is irrelevant.
- Honest hedging like "I'm not sure" or "this is a proof of concept" — those are on-tone.

## Output

- Up to 5 inline comments, one sentence each, prose-only.
- One summary comment with category-fit assessment, any unflagged patterns worth a second look, and a verdict (`ship` / `minor edits` / `revise`).
- Advisory only. Never request changes. Never block merge.
