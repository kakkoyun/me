---
name: the-unwind
description: >
  Drafts the next issue of The Unwind newsletter from coding sessions, Readwise highlights,
  personal vault notes, and Things3 tasks. Produces issue-NNN.md (draft: true) with a
  gitignored sidecar brief and Vale pre-check. USE WHEN user says "draft the unwind",
  "next unwind issue", "the unwind newsletter", "unwind issue draft", or "draft unwind NNN".
disable-model-invocation: false
argument-hint: "[--days N | --since YYYY-MM-DD] [--until YYYY-MM-DD] [--issue NNN]"
---

# The Unwind — newsletter drafting skill

Drafts the next issue of [The Unwind](https://kakkoyun.me/newsletter/the-unwind/) from six data
sources, writes a sidecar brief, interviews the author, produces the issue file, and runs a
local Vale pre-check. The author revises using the humanizer skill, de-slop skill, and kemal-voice checklist before publishing.

## Arguments

`$ARGUMENTS` — optional overrides:
- `--days N` — search window in days (overrides automatic date calculation)
- `--since YYYY-MM-DD` — explicit window start date
- `--until YYYY-MM-DD` — window end date (default: today)
- `--issue NNN` — force a specific issue number (skip auto-detection)

---

## Step 0 — Resolve the window and issue number

1. List `content/newsletter/the-unwind/issue-*.md`. Find the highest `NNN` (zero-padded, e.g. `001`). Next issue = `NNN+1`. **Note:** the filename uses zero-padded NNN (`issue-003.md`); the issue title uses the unpadded number (`The Unwind #3: ...`).
2. Read the previous issue's `publishDate` from its YAML frontmatter. That is `WINDOW_START`.
3. `WINDOW_END` = today's date (or `--until` override).
4. Compute `DAYS` = ceil((WINDOW_END − WINDOW_START).days). Use for `--days N` in recall.
5. **Guard:** if `--issue NNN` was passed and `issue-NNN.md` already exists without `draft: true`, refuse and report: "issue-NNN already published, nothing to do."

---

## Step 1 — Aggregate from six sources (run in parallel where possible)

Every retrieved item must include its source path or URL — the draft cites from this.

### Source 1: Coding sessions (recall CLI)

```bash
python3 ~/.agents/skills/recall/scripts/recall.py --days $DAYS --source claude --limit 30
python3 ~/.agents/skills/recall/scripts/recall.py --days $DAYS --source codex --limit 30
python3 ~/.agents/skills/recall/scripts/recall.py --days $DAYS --source pi --limit 30
```

List mode (no query) returns session titles and file paths sorted by recency. For sessions that
look substantive based on their title (not trivial housekeeping), follow up with:

```bash
python3 ~/.agents/skills/recall/scripts/read_session.py <path> --pretty
```

Limit `read_session` calls to the 3–5 most relevant sessions per source to keep context bounded.

### Source 2: Readwise highlights

Substitute the resolved `WINDOW_START` date (e.g. `"2026-05-13"`) before executing:

```
mcp__readwise__readwise_list_highlights(highlighted_at_gt="WINDOW_START", page_size=100)
```

Pull: `document_title`, `document_author`, `highlight_plaintext`, `highlight_note`,
`highlight_tags`. **Cap:** prioritise highlights that have a `highlight_note`, then those with
`highlight_tags`, then by recency. Keep at most 30 highlights total.

### Source 3: Reader finished documents

Substitute `WINDOW_START` with the resolved date before executing:

```
mcp__readwise__reader_list_documents(location="archive", updated_after="WINDOW_START",
  response_fields=["title","author","word_count","reading_progress","updated_at"])
```

Surfaces what was finished reading in the window.

### Source 4: Personal vault — recent capture

Find files modified in the window. macOS `find` does not support `-newermt`; create a
reference file at `WINDOW_START` using python3 (already a dependency via recall.py):

```bash
# Create sentinel file at WINDOW_START for -newer comparison
touch -t $(python3 -c "
from datetime import datetime
print(datetime.strptime('WINDOW_START', '%Y-%m-%d').strftime('%Y%m%d%H%M.00'))
") /tmp/unwind-window-ref 2>/dev/null

# Clippings and highlights
for vault_dir in \
  ~/Vaults/personal/curation/clippings/articles \
  ~/Vaults/personal/curation/readwise/articles \
  ~/Vaults/personal/curation/highlights \
  ~/Vaults/personal/0inbox; do
  find "$vault_dir" -name "*.md" -newer /tmp/unwind-window-ref 2>/dev/null
done

# Weekly/daily framing notes
find ~/Vaults/personal/periodic/weekly -name "*.md" -newer /tmp/unwind-window-ref 2>/dev/null
find ~/Vaults/personal/periodic/daily  -name "*.md" -newer /tmp/unwind-window-ref 2>/dev/null
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
bash ~/.agents/skills/things3-manager/scripts/things logbook --period ${DAYS}d --limit 100
```

The `--period` flag ensures the lookback matches the computed `DAYS` from Step 0 — the default
is 7d, which silently drops tasks if the window spans more than a week. Filter the output
client-side: keep only tasks with completion date within the window. Group by project/area.
**Noise filter:** retain tasks whose project/area also appears in recall session titles, plus
any task with a notes payload. Collapse all others into a count line:
"N other tasks closed (routine)."

---

## Step 2 — Write the sidecar brief

Path: `content/newsletter/the-unwind/.brief-NNN.md` (gitignored — see `.gitignore`).

Before writing, verify the gitignore entry is present:

```bash
grep -q '\.brief-' "$(git rev-parse --show-toplevel)/.gitignore" || \
  echo "WARNING: .gitignore entry for .brief-*.md is missing — add it before writing the brief"
```

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

**Wait for all answers before proceeding to Step 4.** Do not begin drafting until at
least one answer has been received.

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

### Voice rules

Apply the full voice contract from `.claude/skills/kemal-voice/SKILL.md` — banned vocabulary,
formulaic openers, patterns to scrutinize, and tone-by-category guidance all apply. Do not
reproduce the list here; load the skill as context instead.

Newsletter-specific extensions (not in kemal-voice):
- **Opener:** start with a concrete hook — an observation, number, anecdote, contradiction.
  Never a template phrase.
- **End** on a trade-off, open question, or "what I'd try next". Not a summary paragraph.
- First person. Permit humor. Name influences directly (as issue-001 does with *Register Spill*).

If a section has nothing worth saying after the interview answers, leave it honest:
"Nothing this week" is fine. Do not pad.

---

## Step 5 — Local Vale pre-check (advisory)

```bash
cd "$(git rev-parse --show-toplevel)" && vale content/newsletter/the-unwind/issue-NNN.md
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
  2. Run the humanizer skill (/humanizer) — removes AI-pattern cadence
  3. Run the de-slop skill (/de-slop) — detects remaining slop patterns
  4. Apply kemal-voice checklist (.agents/skills/kemal-voice/SKILL.md) — voice + tone final pass
  5. make prose  → Vale re-check after revisions
  6. make serve-draft → preview at /newsletter/the-unwind/issue-NNN/
  7. Set draft: false + update publishDate when ready to ship.
```

Do **not** run the humanizer, de-slop, or kemal-voice passes as part of this skill. Authoring and
review are separate passes (see `<execution_protocols>` in global CLAUDE.md).

---

## Common mistakes

- **Do not fabricate.** If a section has no material, say so in the draft rather than inventing.
- **Do not pull from the work vault** (`~/Vaults/work/`). The newsletter is public.
- **Do not commit the brief.** It is gitignored. If `git status` shows it, stop and check `.gitignore`.
- **Do not run prose passes.** Hand off cleanly; the author runs them.
- **Do not cite internal work** (Datadog codenames, internal repos, team names) in the Building section.
- **Do not over-summarise sessions.** One prose sentence per session max in Building — the author will expand.
