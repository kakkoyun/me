---
title: "To the Junior Engineers Who Keep Asking"
description: "Notes for the people on my team who are worried about their careers. The data is scarier than most posts admit. The answer is simpler."
publishDate: 2026-08-28T00:00:00Z
date: 2026-05-22T00:00:00Z
draft: true
categories:
  - "reflection"
tags:
  - "ai"
  - "career"
  - "junior-engineers"
  - "engineering"
  - "learning"
  - "blog"
  - "agentic-coding"
showToc: true
tocOpen: false
promote: false
---

The junior engineers around me have started asking the same question, in slightly different wrappings.

*Am I going to have a job in five years?*

*Should I keep learning the fundamentals if a model can already do it?*

*Is the apprenticeship over?*

The fear is honest, and most of the internet is unhelpful about it. Half the takes tell them they are already obsolete; the other half tell them to ignore the noise. Neither is honest. So I want to write down what I actually say to the people on my team — slowly, with sources — because the conversations are happening more often than I expected, and the canned answers I keep seeing online are not good enough.

## The data is real, and it does not say what you think

Start with the numbers, because the fear is grounded in something real.

Stanford's Digital Economy Lab published *Canaries in the Coal Mine* in August 2025, looking at ADP payroll data covering millions of U.S. workers. Headcount for software developers aged 22–25 — the people just entering the industry — has fallen roughly 20% since October 2022. Workers aged 22–25 in the most AI-exposed occupations are down about 16% relative to older peers in the same roles.[^stanford]

A separate working paper from two Harvard economics researchers found a similar pattern in firms that visibly adopted generative AI: junior employment fell about 9% within six quarters — roughly 10% in triple-difference estimates — while senior employment held steady or grew.[^harvard]

If you are a junior engineer reading those numbers and feeling sick, that reaction is correct. Something is happening, and it is happening to your part of the market in particular.

But the same papers are careful about what they show. The Stanford authors caveat only in the generic sense — their facts "may in part be influenced by factors other than generative AI." The stronger version of that caution is the standard counterargument: the post-ZIRP correction, the layoffs, and the hiring freezes all overlap with the AI story. It is the obvious rebuttal, and Stanford answers it head-on — their results survive robustness checks that isolate interest-rate exposure and exclude tech firms. The Harvard paper is a working paper, not peer-reviewed. And Matt Garman, the CEO of AWS, was asked about replacing juniors with AI in August 2025 and called it "one of the dumbest things I've ever heard," pointing out that the people you do not hire this year are the senior engineers you do not have ten years from now.[^garman]

The honest picture is this: the door has narrowed, the timing is brutal, and the people running large engineering organizations are starting to push back on the strategy that narrowed it. Not "you are doomed." Not "this is fine." Somewhere harder than either.

## What hasn't changed

I use AI assistants every day. I have seen them write code I would have been proud to write at thirty, in seconds. I have also seen them lie to me with the same confident cadence they use when they are right, and I have only caught the lies because I have been writing this kind of code for a long time and the seams looked wrong.

That last sentence is the whole job. Everything else in this post is why.

<!-- TODO: one concrete seam anecdote goes here before un-drafting — a specific diff that looked plausible, what tipped me off, why only a mental model of the system caught it. -->

The tools are remarkably capable. You still make the judgment calls.

The model can generate plausible code. It cannot tell you that the plausible code will deadlock under load, or that the dependency it is reaching for was deprecated last quarter, or that the abstraction it just confidently proposed will not survive the next feature. Those calls are made by someone with a working model of the system in their head. Right now, that someone has to be you.

This is not nostalgia. It is the structure of the work. A program is a set of decisions about what is true, what to handle, what to leave out, and how to compose those decisions into something that survives contact with reality. Models are exceptionally good at the *what to type* layer. They are not yet good at *what is true here, what should I leave out, and what will this look like in two years*. Those are judgment calls, and judgment is built from understanding.

## The failure mode has a name

Andrej Karpathy named the failure mode in February 2025. He called it *vibe coding* — "you fully give in to the vibes, embrace exponentials, and forget that the code even exists... I 'Accept All' always, I don't read the diffs anymore."[^karpathy] He was being half-joking about his own weekend projects. The term escaped containment.

Addy Osmani wrote the response I would have written if I had thought of it first: *vibe coding is not the same as AI-assisted engineering*.[^osmani] One is a fun, low-stakes way to throw together a side project. The other is a disciplined practice — design, review, testing, ownership — that happens to use AI as a tool. Conflating the two, he argues, "risks both devaluing the discipline of engineering and giving newcomers a dangerously incomplete picture of what it takes to build robust, production-ready software."

He is right, and I have watched it play out on my own team. The engineers who trust the model most are the ones who question its output least. The ones who know their material push back — they read the diff, they ask why the model made the choice it made, they treat the answer as a draft, not a verdict. How you use the tool matters more than whether you use it. If you let it generate for you, you learn less; if you let it explain, you learn more.

The people who get worse with AI let it do their thinking. The people who get better use it to sharpen theirs. The difference is a habit.

## What I tell the juniors on my team

Three things, mostly.

**Learn the fundamentals like the tool does not exist.** Data structures, systems, how networks fail, how memory behaves, how concurrency goes wrong. Read code that is not yours. Understand what a stack trace actually means before pasting it into a model. It is the foundation that lets you catch the model when it is confidently wrong. Without it, you are a transcriptionist with a fancier keyboard.

**Write the test before you write the prompt.** Decide what "correct" looks like, by yourself, before the model gets a turn. That forces you to actually think about the problem. Then the model is a coding assistant, not a thinking assistant. Try this on the next ticket you pick up. The difference in your own understanding will be immediate.

**Periodically work without AI as a calibration check.** Researchers at METR ran a randomized study of experienced open-source developers in mid-2025 and found something humbling: before the study started, the developers forecast a 24% speedup. In measured task completion, they were 19% slower. Handed that data, they still believed they had been 20% faster.[^metr] The perception did not budge. If experienced engineers cannot self-calibrate, neither can you.

Pick something you have built recently with AI help, and rebuild it from scratch. The gaps in your mental model will show up fast, because you will be confused by your own code. Fill the gaps. Then go back to using the tool.

None of this is glamorous. It is what works.

## To the worried juniors specifically

The market is harder than it was. Most of the people advising you online are selling something. You still have to pay attention.

But the thing you actually have to do is not negotiable, and it has not changed: become an engineer who can think clearly about systems. The tools have gotten dramatically better. So has the bar. The people who will do well are the ones who treat AI as the capable assistant it is, take the judgment calls themselves, and build the understanding that makes those calls trustworthy.

Do that, and the question of whether you will have a job in five years stops being existential. The work is still there. There is more of it than ever. It just demands more of you on the front end.

That is what I tell them. It is the same thing senior engineers told me when I was where they are, except the tools are different and the stakes feel louder. The advice still works.

[^stanford]: Erik Brynjolfsson, Bharat Chandar, and Ruyu Chen, *Canaries in the Coal Mine? Six Facts about the Recent Employment Effects of Artificial Intelligence*, Stanford Digital Economy Lab, August 2025, revised November 2025. Numbers here reflect the November revision. <https://digitaleconomy.stanford.edu/publication/canaries-in-the-coal-mine-six-facts-about-the-recent-employment-effects-of-artificial-intelligence/>

[^harvard]: Seyed Mahdi Hosseini Maasoum and Guy Lichtinger, *Generative AI as Seniority-Biased Technological Change: Evidence from U.S. Résumé and Job Posting Data*, SSRN working paper, August 2025, revised October 2025. Numbers here reflect the October revision. The paper is preliminary and not peer-reviewed; cited here as corroborating evidence, not as a settled finding. <https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5425555>

[^garman]: Matt Garman, AWS CEO, interview on Matthew Berman's YouTube channel, August 2025; coverage in Thomas Claburn, *AWS CEO calls the idea of AI replacing junior engineers "one of the dumbest things I've ever heard"*, *The Register*, August 21, 2025. <https://www.theregister.com/2025/08/21/aws_ceo_entry_level_jobs_opinion/>

[^karpathy]: Andrej Karpathy, post on X, February 2, 2025. <https://x.com/karpathy/status/1886192184808149383>

[^osmani]: Addy Osmani, *Vibe Coding is Not the Same as AI-Assisted Engineering*, August 30, 2025. <https://addyo.substack.com/p/vibe-coding-is-not-the-same-as-ai>

[^metr]: Joel Becker et al., *Measuring the Impact of Early-2025 AI on Experienced Open-Source Developer Productivity*, METR, July 2025; restatement, February 24, 2026. The 19% slowdown estimate has a confidence interval of +2% to +39% — the entire interval is slowdown, and the effect is statistically significant. The calibration point stands: developers forecast a 24% speedup before the study and, after being 19% slower, still believed they had been 20% faster. <https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/> and <https://metr.org/blog/2026-02-24-uplift-update/>
