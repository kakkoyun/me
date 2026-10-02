---
name: kemal-voice
description: Author voice and prose-quality guide for Kemal Akkoyun's blog. Triggers when editing or creating files under content/posts/, content/talks/, or content/notes/, and on any task involving writing, drafting, editing, reviewing, or rewriting blog posts on this repo. Encodes the target tone (clear, explanatory, fun, whimsical, honest, open), the story structure posts follow (references/story-playbook.md), signature moves from earlier posts, banned AI-slop vocabulary, formulaic openers, and patterns to scrutinize (em-dash density, negative parallelism, triadic rhythm).
---

# Kemal voice guide

Loaded when working on prose in `content/posts/`, `content/talks/`, or `content/notes/`. Use alongside [REVIEW.md](../../../REVIEW.md) and the Vale rules in `styles/Slop/`.

This file is about words and tone. **Before drafting or restructuring a post, read [references/story-playbook.md](references/story-playbook.md)**: it covers how a post is built (opening, running thread, foreshadowing, introducing and explaining code blocks, sources, what to cut, signature moves, whimsy budget, tooling gotchas).

## Story and flow in one paragraph

Tell it as something we do together, not as a list of facts. Open with prose and a concrete experiment, promise the journey, then climb one step per section, ending each with a connection sentence that leads into the next. Carry one running thread through the post, plant things early and pay them off out loud. Introduce every code block before it and explain it after. Link sources inline. Cut whatever is true but doesn't move the story, and keep it in a backup document instead. End with something to try and a crescendo, never a summary.

## Tone target

Aim for: **clear, explanatory, fun, whimsical, honest, open.** Take the technical material seriously; do not take yourself seriously.

| Trait | What it looks like in a draft | What it does not look like |
|---|---|---|
| Clear | plain words, jargon defined on first use, concrete examples | abstractions stacked on abstractions |
| Explanatory | walks through the reasoning, shows the work | conclusions without setup |
| Fun and whimsical | humor, asides, playful word choice, the occasional pun | dry, formal, marketing-grave |
| Not too serious | no self-importance, casual phrasing welcome | "transformative paradigm shift" energy |
| Serious about the topic | precise numbers, named systems, named error modes | vibes, "it just works", hand-waving |
| Honest | "this is a proof of concept", "I haven't tried this in prod" when true | overclaiming, hiding dead ends |
| Open | "I'm not sure", "tell me where I'm wrong" are welcome | false certainty, defensive framing |

## Patterns to scrutinize

These are not blanket-banned. A single instance is fine. Watch for clusters.

- **Em-dash parenthetical asides** ("— X —" pairs). Most distinctive AI tell. Prefer commas or parens. Vale: `Slop.Density`, suggestion.
- **Negative parallelism** ("It's not X, it's Y", "not just X, but Y", "not only X, but Y"). Classic AI setup. Rewrite as direct statement unless contrast is load-bearing. Vale: `Slop.Parallelism`, suggestion.
- **Triadic rhythm**. Three parallel clauses can be effective once. Twice in the same post is a tic. Not Vale-detected.
- **Bolded-bullet structure**. Long runs of `**Term**: explanation` bullets feel AI-shaped. Prose with one or two bolded callouts reads more naturally. Not Vale-detected.

## Banned vocabulary (must remove)

Hard-banned at `error` severity in `styles/Slop/Vocabulary.yml`. If a draft contains any of these, replace with concrete language:

| Slop | Try instead |
|---|---|
| delve / delve into | look at, study, walk through, dig into (sparingly) |
| tapestry / rich tapestry | mix, range, set |
| leverage (as verb) | use |
| utilize | use |
| seamless / seamlessly | smooth, friction-free, "you don't notice the transition" |
| paradigm | model, approach, pattern |
| ecosystem (metaphorical) | name the actual set of tools |
| unleash / unleashing | release, run, ship |
| unlock the power of | use; or just delete |
| navigate the landscape | name the actual decision |
| in today's fast-paced/digital/ever-evolving world | delete |
| it's important to note / it's worth noting | delete; just state the thing |
| dive deep / deep dive into | look closely, study |
| comprehensive guide | guide, notes, walkthrough |
| game-changer / game-changing | name the actual change |
| revolutionize / revolutionary | name what changed |
| cutting-edge / state-of-the-art | new, recent, current |
| harness (as verb) | use |
| embark / embark on a journey | start, begin |
| realm of | name the actual area |
| foster (metaphorical) | encourage, help, build |
| the world of X | X (no "world of") |
| nuanced | name the nuance |
| multifaceted | name the facets |
| synergy / synergistic | overlap, fit, combine |
| holistic approach | full-stack approach (if technical); whole-system approach |
| meticulous | careful, exact |
| elevate (as in "elevate your X") | improve, raise |
| groundbreaking | new, first |
| testament to | shows, demonstrates |
| vibrant (metaphorical) | name what makes it lively |

## Formulaic openers to avoid

Flagged at `warning` in Vale. Start with a concrete observation, an anecdote, a number, or a question. Not a template.

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

| Category | Tone | Structure |
|---|---|---|
| `journal` | Informal narrative, first-person, conference-recap | Intro → days/topics → reflections |
| `deep-dive` | Technical, explanatory, conversational ("we") | Prose hook + experiment → why it matters → journey promise → one step per section → real tool → callback to the running thread → try it + crescendo |
| `reflection` | Introspective, self-aware, short paragraphs fine | Context → lessons → takeaways |
| `engineering` | Technical with storytelling hook | Story → technical sections → benchmarks → callback → crescendo |
| `technical-findings` | Evaluative, opinionated, practical | Setup → eval → pros/cons → recommendation |
| `blogmentation` | Tutorial, code-heavy, imperative steps | Problem → solution → result |

## Editing checklist

When asked to edit or review a draft, do these in order:

1. **Read the full post once.** No edits yet. Note category, claimed thesis, intended audience.
2. **Grep for banned vocabulary.** Every hit is a finding. Suggest a concrete replacement from the table above.
3. **Check the first paragraph for a formulaic opener.** If it starts with one, suggest a concrete-observation alternative.
4. **Scan for em-dash density.** 3+ em-dashes in one paragraph? Suggest a rewrite using commas, parens, or shorter sentences. A single em-dash on its own is fine.
5. **Scan for "it's not X, it's Y" parallelism.** Is the contrast actually load-bearing, or is it just rhetorical scaffolding? If the latter, rewrite as a direct statement.
6. **Check tone match against category.** Does a `deep-dive` start with a problem? Does a `reflection` admit uncertainty? Does the post sound like the author or like a marketing one-pager?
7. **Check the story.** Does it read as something we do together, or as a schematic list of facts? Is every code block introduced and explained? Is there a running thread, and is it paid off? Are there captions, reference lists or asides that distract from the story? (See [references/story-playbook.md](references/story-playbook.md).)
8. **Cap inline suggestions at 5.** Add one summary verdict (`ship` / `minor edits` / `revise`) with the top reason.

## Authoring checklist (when drafting, not just editing)

1. Read [references/story-playbook.md](references/story-playbook.md) and pick the running thread before writing a word.
2. Open with prose, not a heading: say what we'll do together, then a concrete hook (a number, an anecdote, a command and its real output, a contradiction). Not a template phrase.
3. Use plain words. Define jargon on first use. Say "we" for the journey and "I" for opinions and jokes.
4. Introduce every code block before it and explain it after it.
5. Be honest about what you tried and what you don't know. The reader can tell.
6. Permit humor. A pun, a wry aside, a self-deprecating one-liner, all welcome; use the signature moves and the whimsy budget in the playbook.
7. Link sources inline on the words they support. Every quote verbatim, every number from a real run.
8. End on something to try and a short crescendo, a trade-off, or an open question. Not on a summary paragraph.
9. Always include a `blog` tag. Categories is a single-value list.
10. Run `vale <file>` (or `make prose`) before opening a PR.
