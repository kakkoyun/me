---
name: the-unwind
description: >
  Drafts the next issue of The Unwind newsletter from coding sessions, Readwise highlights,
  personal vault captures, and Things3 completed tasks. Writes issue-NNN.md (draft: true)
  with a gitignored sidecar brief and runs Vale.
  USE WHEN user says "draft the unwind", "next unwind issue", "draft newsletter issue",
  "the unwind draft", "weekly newsletter draft", or "draft unwind issue".
disable-model-invocation: false
---

# The Unwind — newsletter drafting skill

Drafts the next issue of [The Unwind](https://kakkoyun.me/newsletter/the-unwind/) from six data
sources, writes a sidecar brief, interviews the author, produces the issue file, and runs a
local Vale pre-check. The author revises, then runs `/humanize` → `/de-slop` → `/kemal-voice`.

## Arguments

`$ARGUMENTS` — optional overrides:
- `--days N` — search window in days (overrides automatic date calculation)
- `--since YYYY-MM-DD` — explicit window start date
- `--until YYYY-MM-DD` — window end date (default: today)
- `--issue NNN` — force a specific issue number (skip auto-detection)

---

## Step 0 — Resolve the window and issue number

1. List `content/newsletter/the-unwind/issue-*.md`. Find the highest `NNN` (zero-padded, e.g. `001`). Next issue = `NNN+1`.
2. Read the previous issue's `publishDate` from its YAML frontmatter. That is `WINDOW_START`.
3. `WINDOW_END` = today's date (or `--until` override).
4. Compute `DAYS` = ceil((WINDOW_END − WINDOW_START).days). Use for `--days N` in recall.
5. **Guard:** if `--issue NNN` was passed and `issue-NNN.md` already exists without `draft: true`, refuse and report: "issue-NNN already published, nothing to do."

---

## Step 1 — Aggregate from six sources (run in parallel where possible)

Every retrieved item must include its source path or URL — the draft cites from this.

### Source 1: Coding sessions (recall CLI)

```bash
python3 ~/.agents/skills/recall/scripts/recall.py --days DAYS --source claude --limit 30
python3 ~/.agents/skills/recall/scripts/recall.py --days DAYS --source codex --limit 30
python3 ~/.agents/skills/recall/scripts/recall.py --days DAYS --source pi --limit 30
```

List mode (no query) returns session titles and file paths sorted by recency. For sessions that
look substantive based on their title (not trivial housekeeping), follow up with:

```bash
python3 ~/.agents/skills/recall/scripts/read_session.py <path> --pretty
```

Limit `read_session` calls to the 3–5 most relevant sessions per source to keep context bounded.

### Source 2: Readwise highlights

```
mcp__readwise__readwise_list_highlights(highlighted_at_gt="WINDOW_START", page_size=100)
```

Pull: `document_title`, `document_author`, `highlight_plaintext`, `highlight_note`,
`highlight_tags`. **Cap:** prioritise highlights that have a `highlight_note`, then those with
`highlight_tags`, then by recency. Keep at most 30 highlights total.

### Source 3: Reader finished documents

```
mcp__readwise__reader_list_documents(location="archive", updated_after="WINDOW_START",
  response_fields=["title","author","word_count","reading_progress","updated_at"])
```

Surfaces what was finished reading in the window.

### Source 4: Personal vault — recent capture

Glob by modification time within the window across these paths:

```
~/Vaults/personal/curation/clippings/articles/**/*.md
~/Vaults/personal/curation/readwise/articles/**/*.md
~/Vaults/personal/curation/highlights/**/*.md
~/Vaults/personal/0inbox/**/*.md
```

Also pull the matching ISO-week and daily notes for the author's own framing:

```bash
find ~/Vaults/personal/periodic/weekly -name "*.md" -newer <WINDOW_START_FILE> 2>/dev/null
find ~/Vaults/personal/periodic/daily  -name "*.md" -newer <WINDOW_START_FILE> 2>/dev/null
```

For weekly/daily notes, include the first 300 characters as context in the brief.

### Source 5: Themed expansion (optional, qmd)

When Sources 1–4 produce results that cluster around a theme, run:

```
mcp__qmd__query(searches=[{"type":"vec","query":"<theme>"}], intent="newsletter context",
  collections=["personal"], limit=8)
```

Only when a genuine theme is apparent — don't run this speculatively on every issue.

### Source 6: Things3 — completed tasks

```bash
bash ~/.agents/skills/things3-manager/scripts/things logbook
```

Filter the output client-side: keep only tasks with completion date within the window. Group by
project/area. **Noise filter:** retain tasks whose project/area also appears in recall session
titles, plus any task with a notes payload. Collapse all others into a count line:
"N other tasks closed (routine)."

---

## Step 2 — Write the sidecar brief

Path: `content/newsletter/the-unwind/.brief-NNN.md` (gitignored — see `.gitignore`).

```markdown
# Brief for issue-NNN (window: WINDOW_START → WINDOW_END)

## Coding sessions
### Claude Code
- <session title> — <path> — <1-line summary>
### Codex
- ...
### pi
- ...

## Things3 — completed in window
### <Project / Area>
- <task title> — completed <date> [— notes: ...]
### Cross-reference with sessions  ← Building candidates
- <task that also appears in recall sessions>

## Readwise highlights
- "<highlight text>" — <Author>, *<Title>* — tags: [tag,...]
  - note: <highlight_note if present>

## Reader (finished)
- <Title> — <Author> — finished <date> — <word_count>w

## Personal vault capture
### Clippings
- <relative path> — <title>
### Readwise sync
- <relative path> — <title>
### Highlights
- <relative path> — <title>
### Inbox (unsorted)
- <relative path> — <title>
### Weekly/daily framing
- periodic/weekly/<ISO-week>.md — <first 300 chars>

## Theme clusters (qmd)
- <theme> → <vault paths>

## Vale pre-check
<Populated in Step 5>

## Author notes
<Populated in Step 3 from interview answers>
```

---

## Step 3 — Author interview

After the brief is written, ask 3–5 targeted questions drawn from what the brief *actually
contains*. The Things3/session intersection drives the sharpest Building question.

Question pool (pick what applies from the brief):

- "Things3 shows *<task>* closed and recall has sessions in *<project>*. One line for Building — what was that actually about?"
- "Three highlights from *<Book>* showed up. Which one (if any) belongs in Quoted?"
- "Reader shows you finished *<Title>*. Worth a mention in Reading?"
- "Recall surfaced N sessions in *<project>*. Anything shareable beyond 'worked on X'?"
- "Anything you read or built this week that's missing from the brief?"
- "What's the through-line, if any? Or is this issue just Loose ends?"

Write the author's answers to `## Author notes` in the brief before drafting.

---

## Step 4 — Draft the issue

Write `content/newsletter/the-unwind/issue-NNN.md`. Use the locked four-section shape:

```markdown
---
title: "The Unwind #N: <short hook — 2–5 words>"
description: "<one sentence, no slop>"
date: <WINDOW_END>T00:00:00Z
publishDate: <WINDOW_END>T00:00:00Z
draft: true
---

## Reading

<Prose paragraph weaving 2–3 articles with commentary and inline [title](url) citations.
No bullet lists. Introduce the author's angle, not just the link.>

## Building

<Prose on what was shipped or wrestled with, drawn from the Things3/session intersection
and the author's interview answers. No internal or work-confidential content.>

## Quoted

> <Highlight from a book or article — choose one that surprised or stuck>

<Short reaction — 1–3 sentences. First person. Honest.>

## Loose ends

<Misc links and half-thoughts as a short prose paragraph, not bullets.
Good for things that didn't fit elsewhere.>
```

### Voice rules (derived from `.claude/skills/kemal-voice/SKILL.md`)

- **Tone:** clear, explanatory, fun, whimsical, honest, open. Take the material seriously;
  not yourself.
- **Opener:** start with a concrete hook — an observation, number, anecdote, contradiction.
  Never a template phrase.
- **Banned vocabulary** (hard errors in Vale): delve, leverage, utilize, seamless, paradigm,
  ecosystem (metaphorical), unleash, game-changer, revolutionize, cutting-edge, harness,
  embark, realm of, nuanced, synergy, holistic, meticulous, elevate, groundbreaking,
  testament to, vibrant (metaphorical). Replace with concrete language.
- **Patterns to watch** (not banned, watch for clusters): em-dash parenthetical asides,
  negative parallelism ("it's not X, it's Y"), triadic rhythm.
- **End** on a trade-off, open question, or "what I'd try next" — not a summary paragraph.
- **No formulaic closers:** "In conclusion", "To summarize", "As we've seen".
- First person. Permit humor. Name influences directly (as issue-001 does with *Register Spill*).

If a section has nothing worth saying after the interview answers, leave it honest:
"Nothing this week" is fine. Do not pad.

---

## Step 5 — Local Vale pre-check (advisory)

```bash
cd <repo_root> && vale content/newsletter/the-unwind/issue-NNN.md
```

Capture the output. Append a compact summary to `## Vale pre-check` in the brief:

```
Vale pre-check: N suggestion(s), M warning(s), P error(s)
- Slop.Vocabulary: <count> hits — [list word(s)]
- Slop.Density: <count> hits
- Slop.Parallelism: <count> hits
```

If errors > 0 (hard-banned vocab in the draft): print a `⚠ Vale errors found — see brief` line
in the hand-off message. Advisory only — do not auto-fix or block hand-off.

---

## Step 6 — Hand off

Report to the user:

```
Drafted: content/newsletter/the-unwind/issue-NNN.md
Brief:   content/newsletter/the-unwind/.brief-NNN.md  (gitignored)

Vale pre-check: N suggestion(s), M warning(s), P error(s)
<If errors > 0: ⚠ Vale errors found — see brief § Vale pre-check>

Next steps:
  1. Read the draft; revise as needed.
  2. /humanize   → removes AI-pattern cadence
  3. /de-slop    → detects remaining slop patterns
  4. /kemal-voice → voice + tone final pass
  5. make prose  → Vale re-check after revisions
  6. make serve-draft → preview at /newsletter/the-unwind/issue-NNN/
  7. Set draft: false + update publishDate when ready to ship.
```

Do **not** run `/humanize`, `/de-slop`, or `/kemal-voice` as part of this skill. Authoring and
review are separate passes (see `<execution_protocols>` in global CLAUDE.md).

---

## Anti-patterns

- **Do not fabricate.** If a section has no material, say so in the draft rather than inventing.
- **Do not pull from the work vault** (`~/Vaults/work/`). The newsletter is public.
- **Do not commit the brief.** It is gitignored. If `git status` shows it, stop and check `.gitignore`.
- **Do not run prose passes.** Hand off cleanly; the author runs them.
- **Do not cite internal work** (Datadog codenames, internal repos, team names) in the Building section.
- **Do not over-summarise sessions.** One prose sentence per session max in Building — the author will expand.
