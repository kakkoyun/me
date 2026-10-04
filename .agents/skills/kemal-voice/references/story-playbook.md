# Story playbook

How a Kemal post is built, not just how it sounds. `SKILL.md` covers words and
tone; this file covers structure, flow and the habits that make a long
technical post easy to follow.

It is distilled from five iterations of "Hooking into the Go Toolchain"
(October 2026, a guest post for Jesús Espino's *Internals for Interns*),
the host's review of the first draft, and patterns that recur across the
published posts in `content/posts/`.

The host's verdict on the first draft is the reason this file exists:
"excessively schematic", "too many distractions", "the references outside to
the complete output are more confusing than helpful". The second draft fixed
that by telling a story. Use this playbook so the first draft already does.

## The one rule

**Story beats completeness.** When a detail is true, verified and interesting
but does not move the reader to the next step, it goes to a backup document
(for example `docs/full-draft.md` in a companion repo), not into the post.
Length follows from the story; it is never the target.

## The shape of a deep-dive

This is the arc for `deep-dive` and `engineering` posts. Shorter categories
use a subset (see the table at the end).

1. **Open with prose, never a heading.** One or two sentences that say what
   *we* are going to do together, in plain words. Then the cheapest concrete
   experiment the reader could run, with its real output.
   > Today we're going to take a look at the Go toolchain, and more
   > specifically at how we can take part in the compilation process with our
   > own code.
2. **Explain what the reader just saw**, then give the history or the "why" in
   one or two short paragraphs. Credit people by name, quote them briefly and
   link the quote.
3. **Promise the journey** in three or four short sentences. Name the running
   thread.
   > We'll follow the stopwatch the whole way. First we'll build our own. Then
   > we'll teach it to rewrite code [...]. Along the way the build cache will
   > lie to us.
4. **Thanks and disclosure** in one sentence each, then one pointer to the code
   ("All the code we'll write lives in a companion repository").
5. **Climb a ladder.** Each section is one step harder than the last, ends
   with a connection sentence that leads into the next one, and opens by
   picking up from there, often with a question the reader is already asking.
   > We can get in front of every step of the build. Great! But what are those
   > steps?
6. **Hand the toy to the real tool.** When the post builds a toy, the real-world
   section starts by naming the gap: "Everything `toyhook` does, badly and for
   one package at a time, otelc does for a whole program."
7. **Come back to the running thread** near the end ("Back to the stopwatch").
8. **Close with "Try it yourself" and a crescendo**, not a summary: what the
   reader can now do, why it matters, and a nudge to go build something. End on
   a short, punchy line.

## Connection sentences

End every section with a sentence that leads into the next one, right before
the next heading. It looks back at what we now have and forward at what's
still missing, so the reader is pulled across the heading instead of starting
over. The host's examples: "Now that we have a clear vision about X, we can
start exploring Y." and "But all this is useless unless we have <whatever>,
let's take a look into that."

> Now that we can bring in any package we like, there's one kind of code we
> still can't reach: the code we didn't write. Let's go after it.

A short one works too, especially before the last section: "Enough watching
me do it. Your turn."

## A running thread

Pick one object, character or question and carry it through the whole post:
the stopwatch, a single request, one function. Introduce it in the first
section, use it in the middle, and pay it off at the end. The thread is what
makes a series of techniques read as one story.

## Foreshadow, then pay off

Plant things the reader will need later, and say so with a wink. Then cash
them in explicitly; never leave the callback implied.

| Plant | Payoff |
| --- | --- |
| "Keep the `importcfg` in mind, because it's going to bite us later. (Yes, that's foreshadowing. 👀)" | "Remember the `importcfg`? [...] Told you it would bite." |
| "A `-toolexec` wrapper only sees what the cache lets through. Hold on to that thought; it'll come back." | "There's the thought we held on to earlier [...]. And the `toyhook` we've been using all along has exactly this flaw." |

## Code blocks: introduce, show, explain

Every block gets a sentence before it and an explanation after it. The reader
should never meet a block cold or be left to decode it alone.

- **Before:** what we're about to run or read, and why. "Let's build it and
  point `go build` at it:", "Here's the difference between what we wrote and
  what the compiler actually gets:".
- **After:** what to notice, in plain words. Walk through the parts that matter
  ("`parser.ParseFile` reads the file into an `*ast.File`, and
  `ParseComments` asks it to keep the comments, which we need because our
  marker is one").
- **Show the command, then the output.** If a step changes the program's
  behaviour, show the run. Don't claim a result the reader can't see.
- **Show a sample before the summary.** Before a table of counts, totals or
  "the five slowest", show a few raw lines of the data it was computed from and
  name the columns. The host's note on the first stopwatch draft: it "jumps
  too quickly to the counting of lines in the log without even showing how the
  log would look like". Pick lines that show variety, and don't spoil a reveal
  that comes later.
- Trim long output and say so in the prose ("That's almost 800 lines for our
  little program, so I've kept just two of them. You're welcome.").
- Code and output are copied from a real run, byte for byte. Tabs stay tabs.

## Talk *with* the reader

- Use "we" and "let's" for the journey and "I" for opinions, confessions and
  jokes. Avoid commanding the reader ("Ask the `go` command to narrate"); do it
  together ("If we run `go build` with `-x`, it narrates every command it
  runs").
- Ask the question the reader is asking, then answer it ("What happened?",
  "Why ask the wrapper instead of just reading the compiler binary?").
- Prefer a sentence of context over a bare fact. The host's example: "So, the
  go build is actually running a lot of compilation commands [...], that makes
  sense, but how does it know what needs to be compiled and linked?"

## Sources

- **Inline links on the words they support**, not footnotes and not a
  References list. A reference list added six minutes to the estimated reading
  time and read as noise.
- Link primary sources: commits, CLs, issues and comments, tagged source lines,
  release notes, talk pages.
- Every quote is verbatim and links to where it was said. Paraphrase instead of
  stretching a quote to fit a new referent.
- Introduce every third-party package or tool at its first mention: say what
  it is ("dst, a third-party Go package") and link its repository. A bare name
  like "rewrite with dst" reads as jargon.
- No "see the full output" captions under blocks. Mention the companion repo
  once near the start and once in "Try it yourself".
- Footnotes are still fine for a long-form version on this blog, but they must
  start with plain text (see the gotchas below).

## What to cut

Move these to the backup document instead of the post:

- Captions pointing at capture files, and "complete output" links.
- Plumbing details that don't change what the reader does (single-append log
  writes, parallelism caveats, test-variant suffixes).
- Side quests: alternative flags, related issues, version trivia, history that
  doesn't feed the hook.
- A second example of a point the first example already made.
- Comparison tables and bullet lists where a sentence of prose tells it better.

## Signature moves

These recur across the published posts. Use each once or twice per post; a
cluster of them reads as a tic.

| Move | Example from published posts |
| --- | --- |
| Setup and subvert | "It sounds simple enough, right? Well, it's not." (*Fantastic Symbols*) |
| A bit of sorcery | "As with everything else about computers, it's a bit of sorcery." |
| Mixed feelings, said plainly | "People love this dark magic, which I find either reassuring or alarming depending on the day." |
| Italic scope aside with a smile | "*For the sake of simplicity, we will be focusing on Linux [...]. Otherwise, I could end up writing a small size book in here :)*" |
| Short punchy closer | "FOSDEM 2025 delivered. Again.", "just go. You won't regret it." |
| Honest disclosure | "I work at Datadog and help maintain otelc, so keep that in mind for the last part, and feel free to roll your eyes at the appropriate moment." |

## Whimsy budget

- **Asides:** about one short sarcastic or playful aside every 150–250 words.
  Aim them at the material, the tools or yourself, never at the reader or a
  named person. ("Best build ever, terrible demo.", "Two. Log. Statements.")
- **Emojis:** a handful, inline at the end of an aside or the crescendo,
  roughly ten in a 4,000-word post. Never in headings: Hugo builds anchor IDs
  from heading text, and in-post links depend on them.
- **The crescendo** can be loud. The rest of the post stays clear first and
  funny second.
- Whimsy never changes a claim. A joke next to a number must not make the
  number less precise.

## Facts stay facts

- Every number comes from a real, recorded run. Say "one run, one machine"
  when it matters.
- Verify claims against primary sources before writing them, and again after
  simplifying them; simplification is where accuracy leaks.
- Keep a claim ledger (claim, source URL pinned to a tag or commit, short
  quote) for anything non-obvious. It stays out of the post.

## Iterations are commits

- Every revision round is its own commit on the post branch: the first draft,
  each round of feedback, each polish pass. Never squash review history; it is
  the rollback path.
- Rewriting a pushed branch needs explicit approval and
  `git push --force-with-lease=<branch>:<expected-sha>`.
- Keep a backup ref before any history surgery.

## Guest posts

Ask about, and follow, the host's conventions before drafting. For
*Internals for Interns* (Jesús Espino) these were:

- start with text, not a heading;
- conversational, "we do it together" tone;
- inline links, no References section;
- no capture captions;
- diagrams in the site's hand-drawn style, wide rather than tall;
- the host writes the guest intro box.

Credit the host's related posts where they genuinely help the reader (his
parser post for `go/ast`, his SSA post for dead code elimination), not as
filler.

## Tooling gotchas

- **Vale:** rejects sentences that start with "So", the word "very", a
  paragraph starting with "But", and banned vocabulary such as "unleash". Run
  `vale <file>` after every edit pass.
- **Tabs in code blocks:** a markdownlint auto-fix (MD010) can turn tabs into
  spaces after edits. Restore tabs as the last step before staging, then check
  the staged blob: `git show :<path> | grep -c $'\t'`.
- **Footnotes:** a footnote definition that starts with a link
  (`[^x]: [text](url)`) breaks `layouts/partials/functions/link-index.html` and
  fails the site build. Start footnotes with a plain word.
- **Diagrams:** the site has no Mermaid support. Ship images in
  `static/uploads/` with explicit dimensions (`scripts/check-image-sizes.sh`
  enforces them) and alt text.
- **Link checks:** `lychee --config lychee.toml --root-dir "$PWD/static" <file>`.
  GitHub blob pages sometimes return 503; confirm those with
  `gh api repos/<owner>/<repo>/contents/<path>?ref=<tag>`.
- **Make:** macOS ships GNU Make 3.81, which can't parse this Makefile; use
  `gmake`.
- **Preview:** `hugo server -D -F` renders drafts and future-dated posts. The
  production build skips both.

## Shape by category

| Category | Use from this playbook |
| --- | --- |
| `deep-dive`, `engineering` | The full shape, a running thread, foreshadowing, crescendo |
| `technical-findings` | Hook experiment, introduce/show/explain, honest verdict as the close |
| `blogmentation` | Hook with the problem, introduce/show/explain, one aside, short punchy close |
| `reflection`, `journal` | Prose opening, signature moves, short punchy closer; no ladder needed |
