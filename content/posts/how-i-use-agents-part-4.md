---
title: "How I Use Agents, Part 4: Desktop and Remote"
description: "What changes when Claude Code leaves the terminal: cloud VM sessions, SSH to a real workspace, a diff panel you can comment on, and PRs that fix themselves."
date: 2026-07-08T00:00:00Z
publishDate: 2026-09-25T00:00:00Z
categories:
  - blogmentation
tags:
  - blog
  - claude-code
  - ai
  - productivity
  - tools
  - developer-experience
  - agentic-coding
series: "How I Use Agents"
showToc: true
tocOpen: false
draft: true
promote: false
---

I had three small bugs to fix on `af` before lunch, the laptop was about to be in a meeting, and I did not want to context-switch.

So I opened the desktop app, pointed a cloud session at the repo, gave it the three bugs from `TODO.md`, and put the lid down. By the time I got out of the meeting, there was a PR open with green CI and a note from past-me saying "drop the dependency, don't pin it." I read the diff, queued two comments in the review panel, and went to make coffee. The PR came back fixed.

This is Part 4 of *How I Use Agents*. Parts 1–3 are about working inside terminal harnesses: plan mode[^1], fresh sessions, and the on-disk canon (Part 1); one workstream per task (Part 2); one memory shared across Claude Code and [pi](https://pi.dev) (Part 3). Part 4 is what changes when the agent (here, Claude Code) runs on a machine that isn't mine.

---

The setup transfers. `CLAUDE.md`, `.claude/rules/`, the allowlist in `settings.json`, the skills under `.claude/skills/` — all of it loads in cloud sessions and SSH sessions the same way it loads when I run `claude` in my terminal.[^2] If I have already done the work of writing a `.claude/` directory at the repo root, the desktop app carries all of it forward. Same agent, different chrome, different hardware behind it.{{< sidenote side="alternate" >}}The cloud-sessions docs publish an explicit table of what is and is not available; CLAUDE.md, skills, agents, commands, and rules all carry, and so do MCP servers declared in the repo's `.mcp.json`. User-config MCP servers (`claude mcp add`, `~/.claude/*`) do not.{{< /sidenote >}}

---

## 1. Run the session on a machine that isn't mine

Cloud VM sessions run in a roughly 4 vCPU / 16 GB / 30 GB box that Anthropic spins up per session; the docs call the ceilings approximate and reserve the right to change them.[^2] The box is ephemeral. The repo is cloned fresh when the session starts and the container is reclaimed when the session ends; anything worth keeping has to be committed and pushed first.

The useful thing is that I can close the lid.

The habit is this. When a task is well-defined enough to write in three lines (fix these bugs, rerun the migration, bump this dependency and update the call sites), I push it to a cloud session instead of running it on the laptop. The cloud session does not care that I closed the lid. It does not stall when my battery dies on the train, and it isn't squatting in the terminal I'm using for something else. When it needs me, to answer a question or approve a permission prompt, the mobile app pokes me.

The friction this removes is not "I can do more work in parallel." It is that I stop being the rate-limiting hardware. Past me queued tasks behind whatever the laptop was already doing. Present me does not.

I do not push everything to the cloud. Tasks that need my local tooling, my local secrets, or my local model server stay on the laptop or move to the workspace I cover next.

---

## 2. SSH the session into the workspace

The desktop app also speaks SSH.[^3] Point it at a remote machine, and the session runs there instead of in an Anthropic-managed VM.

I have a dev workspace that is not the laptop: a small machine that holds the build caches, the model weights, and the toolchains that take half an hour to install fresh. Cloud VM sessions cannot use any of that. SSH sessions can.

The shape I keep falling back to: tasks that need a real environment get an SSH session, tasks that need clean isolation get a cloud session. Bug fixes and small refactors go to the cloud. Anything that touches the build cache, talks to a local model server, or expects `pyenv` to already have Python 3.11.7 installed goes to the workspace.

A small detail I did not expect to like: the SSH session shows up in the same desktop UI as the cloud one. Diff panel, review queue, permissions prompts, all the same chrome over a session that happens to be running fifty miles away.

---

## 3. Diff view and inline comments as the review loop

The desktop app puts the agent's pending diff in a panel.[^3] You can click any line in a hunk and leave a comment, the same way you would on a pull request. The comments queue. The next time you send a message, the queued comments go with it.

The diff panel is the closest I've come to pair-reviewing with a colleague who I wasn't interrupting.

Concretely: I let the agent finish a hunk, scrolled the diff, and found three things to push back on. "Move this guard into the existing `validate()` function." "Stop renaming the variable, the old name is referenced from `docs/`." "This loop should early-exit on the first match." I left those as comments, sent one short message ("apply the comments, ask if anything is ambiguous"), and the agent worked through them.

Why this matters. I was reading the diff anyway. The cost of leaving a comment on hunk three while looking at hunk five was lower than holding three things in my head until the end. The agent also got the comments grouped with the spatial context, which is the form they make most sense in.

The single rule I have for myself here: do not leave a comment I am not willing to defend. The agent will do what the comment says. If the comment was lazy, the change will be too.

---

## 4. Let the PR fix itself

This is the one that changed the day.

When the desktop app opens a pull request, it can subscribe to the PR's GitHub events.[^4] CI runs and fails; the agent picks up the failure, reads the logs, tries a fix, pushes a new commit. A reviewer leaves a comment; the agent reads the comment, tries an interpretation, replies with the diff. Both of those used to be context-switches that landed on me.

The setup is one prompt at the end of the session: "open a PR for this branch and watch it." The agent posts the PR, subscribes to the events, and the session keeps running in the background. The status I come back to reads like this: "the PR is open, CI was red, here is the fix, CI is green, the reviewer left two comments, here are the responses."

I do not let it merge. The agent watches the PR; I still press the button. The autonomy I want is the loop closing on the obvious things: lint failure, test flake, a reviewer asking for a one-line rename. Deciding whether the change is the right change stays with me.

One rule of thumb on top of this. If the agent has tried three pushes on the same failure and CI is still red, the loop has stalled and the next move is mine. The auto-fix is a labor-saver, not an oracle.

---

## What I'd skip

Voice works. I cannot find official docs for it, but the desktop app accepts spoken prompts and they land as text on the prompt line.

The caveat is that the prompt is one-shot. No "wait, also" mid-sentence, no back-and-forth while you frame what you actually meant. You have to know the whole prompt before you start saying it. For me that flips voice from useful to annoying. Half of my prompts get written in two passes, the first of which is "what do I actually want to ask." I reach for voice on short prompts ("run the tests" while my hands are wet from washing dishes) and not for anything that needs structure.

The other rough edge worth naming: cloud sessions cost something. The docs are clear about resource limits, quieter about how to budget them across a day. I have not bumped a quota, but I also do not know where the line is. I treat cloud sessions as the more expensive option and pick them when they earn it (lid closed, ephemeral environment, easy task), not by default.

---

## What this changes about the other habits

Plan mode still applies, and it matters more here. On my laptop I can catch a bad plan quickly, because I am standing over its shoulder. In a cloud session the machine keeps working through the bad plan until I check on it, which turns a bad plan into as much time as I leave it running.

Fresh sessions still apply. The cloud VM is literally a fresh machine each time. The `.claude/` directory I committed to the repo is what re-establishes context, exactly as it does at the start of every local session.

The on-disk canon from Part 1 (`PROGRESS.md`, `TODO.md`, `CLAUDE.md`) matters more, not less. When the session can fork onto a remote box I cannot see, the only state I trust is the state that survives the session ending. Disk is still the canon; chat is scratch.

---

## What's next

Part 5 is probably the one about subagents: the Explore, Plan, and general-purpose agents that run inside a session in their own worktrees, in parallel.[^5] I have been running three or four at once on bigger refactors and have opinions about which ones earn their isolation.

If you have read this far and have a habit I should steal, I would like to know.

---

## References

[^1]: [Permission modes — plan mode](https://code.claude.com/docs/en/permission-modes).
[^2]: [Claude Code on the web — cloud sessions and auto-fix pull requests](https://code.claude.com/docs/en/claude-code-on-the-web/).
[^3]: [Claude Code Desktop app](https://code.claude.com/docs/en/desktop).
[^4]: [Claude Code on the web — Auto-fix pull requests](https://code.claude.com/docs/en/claude-code-on-the-web/#auto-fix-pull-requests).
[^5]: [Subagents](https://code.claude.com/docs/en/sub-agents) and [Worktrees](https://code.claude.com/docs/en/worktrees).
