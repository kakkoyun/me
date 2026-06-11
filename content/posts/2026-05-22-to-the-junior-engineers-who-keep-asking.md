---
title: "To the Junior Engineers Who Keep Asking"
description: "Notes for the people on my team who are worried about their careers. The data is scarier than most posts admit. The answer is simpler."
publishDate: 2026-06-24T00:00:00Z
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
---

The junior engineers around me have started asking the same question, in slightly different wrappings.

*Am I going to have a job in five years?*

*Should I keep learning the fundamentals if a model can already do it?*

*Is the apprenticeship over?*

The fear is honest, and most of the internet is unhelpful about it. Half the takes tell them they are already obsolete; the other half tell them to ignore the noise. Neither is honest. So I want to write down what I actually say to the people on my team — slowly, with sources — because the conversations are happening more often than I expected, and the canned answers I keep seeing online are not good enough.

## The data is real, and it does not say what you think

Start with the numbers, because the fear is grounded in something real.

Stanford's Digital Economy Lab published *Canaries in the Coal Mine* in late 2025, looking at ADP payroll data covering millions of U.S. workers. Headcount for software developers aged 22–25 — the people just entering the industry — has fallen roughly 20% since October 2022. Workers aged 22–25 in the most AI-exposed occupations are down about 13% relative to older peers in the same roles.[^stanford]

A separate working paper from two Harvard economics researchers found a similar pattern in firms that visibly adopted generative AI: junior employment fell about 7.7% within six quarters, while senior employment held steady or grew.[^harvard]

If you are a junior engineer reading those numbers and feeling sick, that reaction is correct. Something is happening, and it is happening to your part of the market in particular.

But the same papers are careful about what they do not show. The Stanford authors flag that the decline began so quickly after late 2022 that AI alone cannot explain it — the post-ZIRP correction, the layoffs, the hiring freezes all overlap with the AI story. The Harvard paper is a student working paper, not peer-reviewed. And Matt Garman, the CEO of AWS, was asked about replacing juniors with AI in a December 2025 interview and called it "one of the dumbest things I've ever heard," pointing out that the people you do not hire this year are the senior engineers you do not have ten years from now.[^garman]

The honest picture is this: the door has narrowed, the timing is brutal, and the people running large engineering organizations are starting to push back on the strategy that narrowed it. Not "you are doomed." Not "this is fine." Somewhere harder than either.

## What hasn't changed

Here is the thing nobody seems to want to say plainly: the tools are remarkably capable, and you still make the judgment calls.

I use AI assistants every day. I have seen them write code I would have been proud to write at thirty, in seconds. I have also seen them lie to me with the same confident cadence they use when they are right, and I have only caught the lies because I have been writing this kind of code for a long time and the seams looked wrong.

That last sentence is the whole job.

The model can generate plausible code. It cannot tell you that the plausible code will deadlock under load, or that the dependency it is reaching for was deprecated last quarter, or that the abstraction it just confidently proposed will not survive the next feature. Those calls are made by someone with a working model of the system in their head. Right now, that someone has to be you.

This is not nostalgia. It is the structure of the work. A program is a set of decisions about what is true, what to handle, what to leave out, and how to compose those decisions into something that survives contact with reality. Models are exceptionally good at the *what to type* layer. They are not yet good at *what is true here, what should I leave out, and what will this look like in two years*. Those are judgment calls, and judgment is built from understanding.

## The failure mode has a name

Andrej Karpathy named the failure mode in February 2025. He called it *vibe coding* — "you fully give in to the vibes, embrace exponentials, and forget that the code even exists... I 'Accept All' always, I don't read the diffs anymore."[^karpathy] He was being half-joking about his own weekend projects. The term escaped containment.

Addy Osmani wrote the response I would have written if I had thought of it first: *vibe coding is not the same as AI-assisted engineering*.[^osmani] One is a fun, low-stakes way to throw together a side project. The other is a disciplined practice — design, review, testing, ownership — that happens to use AI as a tool. Conflating the two, he argues, "risks devaluing the discipline of engineering and giving newcomers a dangerously incomplete picture."

He is right, and the research is starting to back it up.

A Microsoft and Carnegie Mellon study at CHI 2025 surveyed 319 knowledge workers about their use of generative AI at work. The pattern: the more confident people were in the AI, the less critical thinking they reported doing. The more confident they were in their own expertise, the more they pushed back on AI output.[^msr_cmu] Expertise is what lets you treat AI as a draft instead of a verdict.

A 2026 study on AI and skill formation in early-career developers found something sharper. When juniors used AI to *generate* code for them, comprehension scores dropped measurably. When they used AI to *explain* concepts and answer questions, learning was preserved or improved.[^skills] *How* you use the tool matters more than *whether* you use it.

The message under all the noise: the people who get worse with AI are the ones who let it do their thinking. The people who get better with AI use it to sharpen their thinking. The difference is not technological. It is a habit.

## What I tell the juniors on my team

Three things, mostly.

**Learn the fundamentals like the tool does not exist.** Data structures, systems, how networks fail, how memory behaves, how concurrency goes wrong. Read code that is not yours. Understand what a stack trace actually means before pasting it into a model. This is not retro nostalgia. It is the foundation that lets you catch the model when it is confidently wrong. Without it, you are a transcriptionist with a fancier keyboard.

**Write the test before you write the prompt.** Decide what "correct" looks like, by yourself, before the model gets a turn. Forces you to actually think about the problem. Then the model is a coding assistant, not a thinking assistant. Try this on the next ticket you pick up. The difference in your own understanding will be immediate.

**Periodically work without AI as a calibration check.** Not as a discipline contest — as a calibration check. Researchers at METR ran a randomized study of experienced open-source developers in mid-2025 and found something humbling: the developers thought AI assistance made them 20% faster on their own projects. In measured task completion, they were actually 19% slower.[^metr] Their perception was off by nearly 40 points. If experienced engineers cannot self-calibrate, neither can you. Pick something you have built recently with AI help, and rebuild it from scratch. The gaps in your mental model will show up fast, because you will be confused by your own code. Fill the gaps. Then go back to using the tool.

That is the whole workflow. It is unglamorous. It works.

## To the worried juniors specifically

Yes, the market is harder than it was. Yes, the people advising you on the internet are mostly selling something. Yes, you should be paying attention.

But the thing you actually have to do is not negotiable, and it has not changed: become an engineer who can think clearly about systems. The tools have gotten dramatically better. So has the bar. The people who will do well are the ones who treat AI as the capable assistant it is, take the judgment calls themselves, and build the understanding that makes those calls trustworthy.

Do that, and the question of whether you will have a job in five years stops being existential. The work is still there. There is more of it than ever. It just demands more of you on the front end.

That is what I tell them. It is the same thing senior engineers told me when I was where they are, except the tools are different and the stakes feel louder. The advice still works.

[^stanford]: Erik Brynjolfsson, Bharat Chandar, and Ruyu Chen, *Canaries in the Coal Mine? Six Facts about the Recent Employment Effects of Artificial Intelligence*, Stanford Digital Economy Lab, November 2025. <https://digitaleconomy.stanford.edu/publication/canaries-in-the-coal-mine-six-facts-about-the-recent-employment-effects-of-artificial-intelligence/>

[^harvard]: Seyed Mahdi Hosseini Maasoum and Guy Lichtinger, *Generative AI as Seniority-Biased Technological Change: Evidence from U.S. Résumé and Job Posting Data*, SSRN working paper, August 2025. The paper is preliminary and not peer-reviewed; cited here as corroborating evidence, not as a settled finding. <https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5425555>

[^garman]: Matt Garman, AWS CEO, interview on WIRED's *The Big Interview* podcast, December 16, 2025. <https://www.wired.com/story/the-big-interview-podcast-matt-garman-ceo-aws/>

[^karpathy]: Andrej Karpathy, post on X, February 2, 2025. <https://x.com/karpathy/status/1886192184808149383>

[^osmani]: Addy Osmani, *Vibe Coding is Not the Same as AI-Assisted Engineering*, August 30, 2025. <https://addyo.substack.com/p/vibe-coding-is-not-the-same-as-ai>

[^msr_cmu]: Hao-Ping (Hank) Lee et al., *The Impact of Generative AI on Critical Thinking: Self-Reported Reductions in Cognitive Effort and Confidence Effects From a Survey of Knowledge Workers*, CHI 2025. <https://dl.acm.org/doi/full/10.1145/3706598.3713778>

[^skills]: Wendy Shen and Alex Tamkin, *How AI Impacts Skill Formation*, arXiv preprint 2601.20245, 2026. <https://arxiv.org/abs/2601.20245>

[^metr]: Joel Becker et al., *Measuring the Impact of Early-2025 AI on Experienced Open-Source Developer Productivity*, METR, July 2025. The headline finding is a perception gap, not a definitive slowdown — the confidence interval includes a small speedup. The point is calibration: developers were systematically off about their own productivity. <https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/>
