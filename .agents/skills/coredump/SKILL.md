---
name: coredump
description: >
  Drafts the next issue of the CoreDump newsletter from coding-session logs — technical
  problem/solution write-ups, one per solve, with the literal error output and the fix that
  worked. Produces issue-NNN.md (draft: true) with a gitignored sidecar brief and Vale
  pre-check. Runs interactively, or unattended (defers interview questions into the draft). USE WHEN user says
  "draft coredump", "next coredump issue", "coredump newsletter", or "coredump NNN".
disable-model-invocation: false
argument-hint: "[--days N | --since YYYY-MM-DD] [--until YYYY-MM-DD] [--issue NNN] [--unattended]"
---

# CoreDump — newsletter drafting skill

Drafts the next issue of [CoreDump](https://kakkoyun.me/newsletter/coredump/) from coding-session
logs — the problems solved between issues, each written up blogmentation-style: a short problem
statement, the literal error or command output, and the fix that worked. Secondary material comes
from completed dev tasks; an optional Readwise pick supplies a "worth reading" note. The skill
writes a sidecar brief, interviews the author (or, when `--unattended`, defers the questions into
the issue), produces the issue file, and runs a local Vale pre-check. The author revises using the
humanizer skill, de-slop skill, and kemal-voice checklist before publishing.

## Arguments

`$ARGUMENTS` — optional overrides:
- `--days N` — search window in days (overrides automatic date calculation)
- `--since YYYY-MM-DD` — explicit window start date
- `--until YYYY-MM-DD` — window end date (default: today)
- `--issue NNN` — force a specific issue number (skip auto-detection)
- `--unattended` — skip the Step 3 interview and defer its questions into the draft instead
  (see Step 3), for a quick first pass without stopping to interview you.

---

## Step 0 — Resolve the window and issue number

1. List `content/newsletter/coredump/issue-*.md`. Find the highest `NNN` (zero-padded, e.g. `001`). Next issue = `NNN+1`. **Note:** the filename uses zero-padded NNN (`issue-003.md`); the issue title uses the unpadded number (`CoreDump #3: ...`).
2. Read the previous issue's `publishDate` from its YAML frontmatter. That is `WINDOW_START`. (If no prior issue exists, default to 7 days back or use `--since`.)
3. `WINDOW_END` = today's date (or `--until` override).
4. Compute `DAYS` = ceil((WINDOW_END − WINDOW_START).days). Use for `--days N` in recall.
5. **Guard:** if `--issue NNN` was passed and `issue-NNN.md` already exists without `draft: true`, refuse and report: "issue-NNN already published, nothing to do."

---

## Step 1 — Aggregate the sources (run in parallel where possible)

This newsletter is about **problems solved while working**, not general reading. Every retrieved
item must include its source session path or URL — the draft cites from this.

### Source 1 (PRIMARY): Coding-session logs (recall CLI)

The heart of every issue. List recent sessions across all three agents:

```bash
recall --days $DAYS --source claude --limit 30
recall --days $DAYS --source codex --limit 30
recall --days $DAYS --source pi --limit 30
```

`recall` and `read-session` are PATH wrappers over `~/.agents/skills/recall/scripts/{recall,read_session}.py`.
List mode (no query) returns session titles and file paths sorted by recency. For sessions that
look like a real *solve* based on their title (a bug fixed, an error chased down, a config wrestled
into shape — not trivial housekeeping), read the full session:

```bash
read-session <path> --pretty
```

For a sharper first pass, `ctx` (semantic + keyword search over the same session store) surfaces
solves that recall's title listing misses. Use whichever finds the real work:

```bash
ctx search "bug fixed | error resolved | root cause" --since ${DAYS}d
ctx show session <ctx-session-id>
```

Limit full-transcript reads to the 3–5 most substantive sessions per source to keep context bounded.

For each real **SOLVE**, extract three things — this is what the write-up is built from:
1. **The problem statement** — what was broken, in one line.
2. **The literal error message or command output** — copy it verbatim. Readers must be able to
   confirm they hit the *same* issue (blogmentation discipline; see `.agents/skills/blogmentation/SKILL.md`).
3. **The fix that worked** — the command, config change, or code that actually resolved it.

A session with no reproducible error and no concrete fix is not a core dump — skip it.

### Source 2 (SECONDARY): Things3 — completed dev tasks

```bash
bash ~/.agents/skills/things3-manager/scripts/things logbook --period ${DAYS}d --limit 100
```

The `--period` flag matches the computed `DAYS` from Step 0 — the default is 7d, which silently
drops tasks if the window spans more than a week. Filter the output client-side: keep only tasks
completed within the window. **Intersection filter:** retain only *dev* tasks whose project/area
also appears in the recall session titles from Source 1. A completed task that corroborates a
session is a strong signal that the solve was real and shippable; a task with no matching session
is noise here. Collapse the rest into a count line: "N other tasks closed (routine)."

### Source 3 (OPTIONAL): Readwise — one "worth reading" pick

At most one or two highlights, only if something genuinely fits the issue's technical bent.
Substitute the resolved `WINDOW_START` date before executing:

```
mcp__readwise__readwise_list_highlights(highlighted_at_gt="WINDOW_START", page_size=100)
```

Prioritise highlights with a `highlight_note`, then those with `highlight_tags`. Keep the single
best pick (two at most). Skip this source entirely if nothing lands — `## Worth reading` is optional.

### Sources deliberately NOT used

- **No Obsidian personal-vault scan** and **no qmd themed expansion** — CoreDump is sourced from
  session logs, not second-brain capture. (Those belong to The Unwind.)
- **Never read `~/Vaults/work/`.** The newsletter is public; internal work never appears in it.

---

## Step 2 — Write the sidecar brief

Path: `content/newsletter/coredump/.brief-NNN.md` (gitignored).

Before writing, verify the gitignore entry that covers the coredump brief is present:

```bash
grep -q 'content/newsletter/coredump/\.brief-' "$(git rev-parse --show-toplevel)/.gitignore" || \
  echo "WARNING: .gitignore entry for content/newsletter/coredump/.brief-*.md is missing — add it before writing the brief"
```

~~~markdown
# Brief for issue-NNN (window: WINDOW_START → WINDOW_END)

## Solves (from session logs)  ← Core dumps candidates
### <short problem title> — <source: claude|codex|pi> — <session path>
- Problem: <one line>
- Error / output:
  ```
  <literal error message or command output, verbatim>
  ```
- Fix: <the command / config / code that worked>
### ...

## Still stuck (unresolved in the sessions)
- <problem> — <session path> — <where it stalled>

## Things3 — completed dev tasks intersecting sessions
- <task title> — completed <date> — matches session <path> [— notes: ...]
- N other tasks closed (routine)

## Worth reading (Readwise, optional)
- "<highlight text>" — <Author>, *<Title>* — tags: [tag,...]
  - note: <highlight_note if present>

## Vale pre-check
<Populated in Step 5>

## Author notes
<Populated in Step 3 from interview answers — OR, in --unattended mode, the deferred questions>
~~~

---

## Step 3 — Author interview (or defer, when `--unattended`)

### Interactive mode (default — no `--unattended`)

After the brief is written, ask 3–5 targeted questions drawn from what the brief *actually
contains*. The solves drive the sharpest questions.

Question pool (pick what applies from the brief):

- "The *<error>* solve in *<project>* — is the fix in the brief the whole story, or was there a wrong turn worth showing?"
- "*<Task>* closed and there's a matching session — anything shareable beyond 'fixed it'?"
- "Recall shows *<problem>* still open. Include it under Still stuck, or is it resolved now?"
- "One Readwise pick fits the theme — worth a line under Worth reading, or drop it?"
- "Is there a through-line across these solves, or is this issue just a list of fixes?"

Write the author's answers to `## Author notes` in the brief before drafting.

**Wait for all answers before proceeding to Step 4.** Do not begin drafting until at least one
answer has been received.

### Unattended mode (`--unattended`)

**Skip the interview entirely — do not block on author input.** An unattended run drafts on its
own. Instead:

1. Draft directly to `draft: true` from the brief and the extracted solves (Step 4).
2. Compose the 3–5 questions you *would* have asked (same pool as above), and append them to the
   END of the issue as an `## Open questions for the author` block, and also record them under
   `## Author notes` in the brief. The author resolves them from the resulting PR.

This is the key difference from The Unwind: the issue ships as a draft with its open questions
attached, rather than stalling on a human answer.

---

## Step 4 — Draft the issue

Write `content/newsletter/coredump/issue-NNN.md`. Use this section shape (outer fence shown with
tildes so the inner code block reads cleanly):

~~~markdown
---
title: "CoreDump #N: <short subtitle — 2–5 words>"
description: "<one sentence, no slop>"
date: <WINDOW_END>T00:00:00Z
publishDate: <WINDOW_END>T00:00:00Z
draft: true
---

## Core dumps

<One block per solve. For each: a short problem statement in prose (1–2 sentences), then the
literal error or command output in a fenced code block, then the fix. This is the blogmentation
discipline applied to a newsletter — the reader should be able to confirm they hit the same issue
and apply the same fix. Cite the source session inline or in a trailing note.>

### <problem, as a short phrase>

<What was broken and where — one or two sentences.>

```
<literal error message / command output, verbatim from the session>
```

<The fix that worked — the command, config, or code. One or two sentences on why, no more.>

### <next solve...>

## Still stuck

<Open problems from the sessions that are NOT yet solved. Honest and brief. Optional — omit the
section if everything got fixed. Do not invent open problems to fill it.>

## Worth reading

<The optional Readwise pick: the quote or link, plus a one-line reason it's here. Optional — omit
if Source 3 produced nothing.>

## Loose ends

<Brief misc — half-thoughts, a config note, a thing that didn't fit above. Short prose, optional.>
~~~

In `--unattended` mode, also append at the very end of the issue:

~~~markdown
## Open questions for the author

<!-- Deferred from an unattended run — resolve these, then delete this block before publishing. -->

1. <question drawn from the brief>
2. <...>
~~~

Section rules:
- `## Core dumps` is required and carries the issue. Every other section is optional and is omitted
  (not left empty) when it has nothing real.
- Each core dump **must** include the literal error/output block. A solve with no verbatim output
  isn't a core dump — it belongs in Loose ends or gets cut.
- Cite the source session path or agent for each solve.

### Voice rules

Before writing any prose, load the full voice contract from `.claude/skills/kemal-voice/SKILL.md`
(symlinked; canonical at `.agents/skills/kemal-voice/SKILL.md`) — banned vocabulary, formulaic
openers, patterns to scrutinize, and tone-by-category guidance all apply. Do not reproduce the
list here; load the skill as context instead.

Newsletter-specific extensions (not in kemal-voice):
- **Opener:** drop straight into the first solve — the exact error, the broken command, the
  confusing output. Never a template phrase.
- **Tone:** technical, direct, honest about wrong turns. Permit dry humour. Take the bug seriously;
  don't take yourself seriously.
- **End** on a trade-off, an open question, or "what I'd try next" — not a summary paragraph.
- First person.

If a section has nothing real, omit it. "Nothing still stuck this week" is fine to say once; do not
pad with invented material.

---

## Step 5 — Local Vale pre-check (advisory)

```bash
cd "$(git rev-parse --show-toplevel)" && vale content/newsletter/coredump/issue-NNN.md
```

Capture the output. Append a compact summary to `## Vale pre-check` in the brief:

```
Vale pre-check: N suggestion(s), M warning(s), P error(s)
- Slop.Vocabulary: <count> hits — [list word(s)]
- Slop.Density: <count> hits
- Slop.Parallelism: <count> hits
```

If errors > 0 (hard-banned vocab in the draft): print a `⚠ Vale errors found — see brief` line in
the hand-off message. Advisory only — do not auto-fix or block hand-off.

---

## Step 6 — Hand off

Report to the user:

```
Drafted: content/newsletter/coredump/issue-NNN.md
Brief:   content/newsletter/coredump/.brief-NNN.md  (gitignored)

Vale pre-check: N suggestion(s), M warning(s), P error(s)
<If errors > 0: ⚠ Vale errors found — see brief § Vale pre-check>
<If --unattended: ⚠ Drafted unattended — see § Open questions for the author in the issue>

Next steps:
  1. Read the draft; answer any Open questions for the author; revise as needed.
  2. Run the humanizer skill (/humanizer) — removes AI-pattern cadence
  3. Run the de-slop skill (/de-slop) — detects remaining slop patterns
  4. Apply kemal-voice checklist (.agents/skills/kemal-voice/SKILL.md) — voice + tone final pass
  5. make prose  → Vale re-check after revisions
  6. make serve-draft → preview at /newsletter/coredump/issue-NNN/
  7. Set draft: false + update publishDate when ready to ship.
```

Do **not** run the humanizer, de-slop, or kemal-voice passes as part of this skill. Authoring and
review are separate passes (see `<execution_protocols>` in global CLAUDE.md).

---

## Common mistakes

- **Do not fabricate.** If a section has no material, omit it rather than inventing a solve or an
  open problem. Every core dump traces to a real session.
- **Do not drop the literal error output.** The verbatim error/command block is the point — it's
  how readers confirm they have the same issue. A core dump without it isn't one.
- **Do not pull from the work vault** (`~/Vaults/work/`). The newsletter is public.
- **Do not commit the brief.** It is gitignored. If `git status` shows it, stop and check `.gitignore`.
- **Do not run prose passes.** Hand off cleanly; the author (or PR) runs them.
- **Do not cite internal work** (Datadog codenames, internal repos, team names) in any solve.
- **Do not over-summarise sessions.** One prose sentence per session summary in the brief — the
  draft expands the ones that become core dumps.
- **Cite the source** session path or agent for every item that lands in the issue.
- **In `--unattended` mode, never block on the author.** Defer the questions into the issue and
  finish the draft.
