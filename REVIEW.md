# REVIEW.md

Prose review criteria for this blog. Used by:

- The author, as a self-edit checklist before opening a PR.
- The `prose-review.yml` GitHub Action, **label-triggered only** (apply the `prose-review` label to a PR to fire it). Loads this file plus [.claude/skills/kemal-voice/SKILL.md](.claude/skills/kemal-voice/SKILL.md) before reviewing.
- The local `vale` config, whose rules in [styles/Slop/](styles/Slop/) mirror the vocabulary lists below.

## Scope

Applies to every file under `content/posts/` and `content/talks/`. Skip `content/notes/` (mirrored from Obsidian via the daily cron). Skip code blocks, frontmatter, shortcode arguments, and URL targets.

## Tone

Aim for: **clear, explanatory, fun, whimsical, honest, open**. Take the technical material seriously; do not take yourself seriously.

What that means in practice:

- **Clear**: plain language. Define jargon the first time it shows up. Concrete examples over abstractions.
- **Explanatory**: walk the reader through the reasoning. Show your work. Conclusions without setup land flat.
- **Fun and whimsical**: humor is welcome. Casual phrasing, asides, the occasional pun. Word choice can be playful.
- **Not too serious about itself**: no self-importance. No marketing tone. No false gravity around routine engineering decisions.
- **Serious about the topic**: precision in technical details. Numbers, not vibes. Name actual systems, versions, error modes.
- **Honest**: acknowledge limits. Say "this is a proof of concept" or "I haven't tried this in production" when true. Show dead ends if they teach something.
- **Open**: comfortable with uncertainty. "I'm not sure", "I'd love to be told I'm wrong", and similar are fine and good.

## Patterns to scrutinize (not blanket-banned, but check yourself)

These read as AI-flavored when overused. A single instance is fine; a paragraph built from them is not.

- **Em-dash parenthetical asides** ("— X —" pairs). The most distinctive AI prose tell. Prefer commas or parens for asides. Vale: `Slop.Density`, suggestion.
- **Negative parallelism** ("It's not X, it's Y", "not just X, but Y", "not only X, but Y"). Classic AI rhetorical setup. Rewrite as a direct statement unless the contrast is load-bearing. Vale: `Slop.Parallelism`, suggestion.
- **Triadic rhythm**. Three parallel clauses in a row ("Static compilation. No LD_PRELOAD. Unique calling convention.") can be effective once. Twice in the same post feels like a tic. Not Vale-detected; review by eye.
- **Bolded-bullet structure**. Long stretches of `**Term**: explanation` bullets are an AI tell. Prose paragraphs with one or two bolded callouts read more naturally. Not Vale-detected.

## Hard-banned vocabulary (Vale: error)

Surface any occurrence as a high-priority finding. Mirrored in `styles/Slop/Vocabulary.yml`.

`delve`, `tapestry`, `rich tapestry`, `leverage`, `utilize`, `seamless`, `paradigm`, `ecosystem`, `unleash`, `unlock the power`, `navigate the landscape`, `the landscape of`, `in today's fast-paced/digital/world/ever-evolving`, `it's important to note`, `it's worth noting`, `dive deep`, `deep dive into`, `comprehensive guide`, `comprehensive overview`, `game-changer`, `game-changing`, `revolutionize`, `revolutionary`, `cutting-edge`, `state-of-the-art`, `bleeding-edge`, `harness` (as verb), `embark`, `embark on a journey`, `realm of`, `foster` (in the metaphorical sense), `the world of`, `nuanced`, `multifaceted`, `synergy`, `synergistic`, `holistic approach`, `meticulous`, `elevate` (as in "elevate your X"), `groundbreaking`, `testament to`, `vibrant`.

## Formulaic AI openers (Vale: warning)

Flag at paragraph start. Mirrored in `styles/Slop/Openers.yml`.

- "In this post/article/guide, we'll …"
- "Let's dive into …" / "Let's explore …"
- "It's worth/important noting/to note that …"
- "At its core, …"
- "In conclusion, …" / "In summary, …" / "To summarize, …"
- "As we (can see / have seen), …"
- "Without further ado, …"
- "Buckle up, …"
- "Imagine a world/scenario where …"
- "Picture this: …"

## Tone by category

Mirrors the table in `CLAUDE.md`. Use to calibrate review notes.

| Category | Expected tone |
|---|---|
| `journal` | Informal narrative, first-person, conference-recap energy, comfortable with "I felt", "I noticed" |
| `deep-dive` | Technical, explanatory, problem statement up front, code blocks and benchmarks welcome |
| `reflection` | Introspective, lessons-learned framing, self-aware ("Too cheesy? I know"), short paragraphs fine |
| `engineering` | Technical with a storytelling hook, benchmarks/experiments, conclusion grounded in trade-offs |
| `technical-findings` | Evaluative, setup → eval → pros/cons → recommendation, opinionated |
| `blogmentation` | Tutorial, problem → solution → result, code-heavy, numbered or imperative steps |

## Review output format

- Inline review comments: up to 5, prose-only, one sentence each.
- One summary comment with: category-fit assessment, list of any unflagged patterns worth a second look, and a verdict (`ship` / `minor edits` / `revise`).
- Advisory only. Never block.
