---
description: Turn an idea into a draft blog post in Kemal's voice. Sets up a worktree, shapes the story (running thread, opening experiment), gathers verified evidence, drafts with kemal-voice and the story playbook, runs independent reviews and the quality chain, previews in Hugo and difit, then opens a draft PR. Argument is the topic or idea.
allowed-tools: Bash, Read, Write, Edit, WebFetch, WebSearch
argument-hint: "[topic or idea] [--guest <host blog>]"
---

# /write-blog: from an idea to a draft PR

End-to-end workflow from an idea to a draft PR on `~/Vaults/blog`. Every step
is mandatory. Skipping one, especially the story shaping, the evidence or the
quality chain, has been the source of repeated corrections.

Read these before Step 2 and keep them open:

- `.agents/skills/kemal-voice/SKILL.md`: words and tone.
- `.agents/skills/kemal-voice/references/story-playbook.md`: how a post is
  built. This is what turns a correct draft into a story.
- `REVIEW.md`: what reviewers will check.

## Arguments

- `$ARGUMENTS`: the topic, title or idea. Required; if empty, ask.
- `--guest <host>`: the post is for someone else's blog. Ask for the host's
  conventions in Step 2 and follow them over this repo's defaults.

## Step 1: worktree

The blog repo is `~/Vaults/blog` and its default branch is `master`. Never
write in another directory.

```bash
cd ~/Vaults/blog
git fetch origin
git worktree add .worktrees/<slug> -b post/<slug> origin/master
cd .worktrees/<slug>
gmake bootstrap
```

Use `gmake`: macOS ships GNU Make 3.81, which can't parse this Makefile.

## Step 2: shape the story (before any prose)

Ask the user, and wait for answers:

1. **Angle and reader.** What should the reader be able to do or understand at
   the end?
2. **Category.** One of the categories in `CLAUDE.md`; it picks the shape from
   the playbook's "Shape by category" table.
3. **Running thread.** One object, character or question carried through the
   whole post (the stopwatch in "Hooking into the Go Toolchain").
4. **Opening experiment.** The cheapest concrete thing the reader can run or
   see in the first screen.
5. **Guest conventions** (with `--guest`): headings, sources, captions,
   diagrams, length, intro box.

Then scaffold with `/blogpost $ARGUMENTS`, which outlines the story arc, or
write the frontmatter and outline directly if the topic is already well
scoped. Target path: `content/posts/<slug>.md`, `draft: true`.

## Step 3: evidence (non-negotiable)

1. **Research.** Use WebSearch and WebFetch, primary sources first: commits,
   CLs, issues and comments, tagged source lines, release notes, talk pages.
2. **Claim ledger.** For every non-obvious claim, record the claim, the source
   URL pinned to a tag or commit, and a short verbatim quote. Keep the ledger
   out of the post (for example in `~/.cache/<slug>/`).
3. **Real runs.** If the post shows commands or output, run them and record
   the output with versions. For anything bigger than a few commands, build a
   companion repository with a Makefile and `captures/`. Never write output by
   hand.
4. A post with unsourced factual claims does not leave this step.

## Step 4: draft

Write it yourself, following kemal-voice and the playbook:

- open with prose, never a heading; "we" for the journey, "I" for opinions;
- climb one step per section, each opening from the last;
- introduce every code block before it and explain it after it;
- link sources inline on the words they support; no References list, no
  capture captions;
- plant things early and pay them off out loud;
- a few whimsical asides and emojis, per the playbook's whimsy budget;
- end with "Try it yourself" and a short crescendo, not a summary.

When a verified detail doesn't move the story, put it in a backup document
(for example `docs/full-draft.md` in the companion repo) instead of the post.

Commit the first draft. **Every later round is its own commit**; never squash
the review history, because it's the rollback path.

## Step 5: independent review

Ask: "Run the independent reviews now?" If yes, run fresh-context, read-only
reviewers on the draft. They diagnose; they don't rewrite.

- **Story and voice:** schematic or imperative stretches, code blocks that
  aren't introduced or explained, distractions, missed callbacks, the ending.
- **Copy-edit:** grammar, clarity, terminology, long sentences, prose that
  contradicts the code or output.
- **Fact audit:** every claim and quote against its source, every number
  against the captures, factual drift introduced while simplifying.
- **Cross-check:** every block against its source file or capture; links
  pinned and consistent.

Classify each finding (valid, already handled, stale, invalid, out of scope)
and discuss the valid ones with the user before changing anything. Apply,
commit as a new iteration, and re-check only what changed.

## Step 6: quality chain (always, in this order)

1. `/de-slop`: detect and remove AI writing tropes.
2. `/humanizer`: strip remaining AI-flavored patterns without changing meaning.
3. A kemal-voice pass: banned vocabulary, formulaic openers, em-dash density,
   signature moves, story checks.
4. Mechanical gates, all of which must pass:

   ```bash
   vale content/posts/<slug>.md          # 0 errors
   hugo -D -F -d /tmp/<slug>-hugo         # builds
   PUBLIC_DIR=/tmp/<slug>-hugo bash scripts/check-image-sizes.sh
   lychee --config lychee.toml --root-dir "$PWD/static" content/posts/<slug>.md
   git show :content/posts/<slug>.md | grep -c $'\t'   # tabs survived in code blocks
   ```

   Known traps (details in the playbook): Vale rejects sentences that start
   with "So", the word "very" and banned words such as "unleash"; a markdownlint
   auto-fix can turn code-block tabs into spaces, so restore tabs last and check
   the staged blob; footnotes must not start with a link; the site has no
   Mermaid, so ship images with dimensions; GitHub blob links can return 503 to
   lychee, so confirm them with `gh api`.

Commit the quality-chain changes as their own iteration.

## Step 7: preview

Give the user both views and wait for sign-off:

```bash
hugo server -D -F --port 1319 --bind 127.0.0.1   # rendered post, with images
difit . origin/master --background                # the whole branch as a diff
difit HEAD --background                           # just the latest iteration
```

Reuse a running difit server for the same target instead of starting another.

## Step 8: draft PR

Follow the publication rules in `~/AGENTS.md`: draft the commit message and the
PR title and body, run them through de-slop and humanizer, show them with the
destination, and publish only after explicit approval of that exact text.

```bash
git push -u origin post/<slug>
gh pr create --draft --base master --title "<title>" --body-file <approved-body.md>
```

- Draft only, until the user explicitly says otherwise.
- Body: what the post is about, which files it adds, and the checks that ran.
- No `Co-Authored-By`, "Generated with" or any tool or agent provenance.
- Never comment on the PR on the user's behalf; feedback from a host or
  reviewer goes back to the user.
- Return the PR URL.

## Guardrails

- Never write outside the post's worktree.
- No story shape (thread and opening experiment), no draft.
- No sources and real runs, no claims.
- Every revision round is a commit. Rewriting pushed history needs explicit
  approval and `git push --force-with-lease=<branch>:<expected-sha>`.
- Credit people for what they actually did.
