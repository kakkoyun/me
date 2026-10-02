---
name: blogpost
description: >
  Scaffolds a full blog post draft from an idea with Hugo frontmatter, outline, optional section fleshing, Obsidian integration, and Things 3 task creation.
  USE WHEN user says "write a blog post", "draft post", "blog idea", "scaffold blog", or "publish post".
disable-model-invocation: true
argument-hint: "[topic]"
---

# /capture:blogpost — Scaffold a full blog post draft from an idea

Captures a topic or idea and scaffolds a complete Hugo blog post draft with frontmatter, outline, and optional content. Optionally pulls related notes from Obsidian and creates a Things 3 task for editing and publishing.

## Arguments

- `$ARGUMENTS` — Topic, title, or idea for the blog post. If empty, prompt the user interactively.

## Instructions

1. **Determine the topic**
   Parse `$ARGUMENTS` for the blog post topic. If not provided, ask the user:
   > What topic or idea would you like to turn into a blog post?

   Clarify the angle, audience, and scope if the topic is broad. Then read
   `.agents/skills/kemal-voice/references/story-playbook.md` and agree on two
   things with the user before outlining: the **running thread** (one object,
   character or question carried through the whole post) and the **opening
   experiment** (the cheapest concrete thing a reader could run or see).
   For a guest post, ask for the host's conventions too.

2. **Search for related Obsidian notes** (optional)
   Check if the `obsidian-cli` skill is available. If so, use it to search the notes vault for content related to the topic:
   - Search by keywords extracted from the topic
   - Look for relevant notes, MOCs, or prior writing

   If related notes are found, summarize them and ask the user which ones to incorporate.

   **Fallback chain:** If the `obsidian-cli` skill is not available, fall back to searching `~/Vaults/personal/` and `~/Vaults/work/` using Grep/Glob. If neither approach yields results, skip this step and inform the user that no related notes could be found.

3. **Generate a slug and filename**
   Derive a URL-friendly slug from the title. The file path follows the pattern:
   ```
   ~/Vaults/blog/content/posts/<slug>.md
   ```
   Verify that `~/Vaults/blog/content/posts/` exists before proceeding. If it does not, inform the user and ask for the correct blog content path.

   Confirm the filename with the user before creating.

4. **Scaffold the Hugo blog post**
   Create the file with this frontmatter structure:

   ```markdown
   ---
   title: "Post Title"
   description: "One-sentence summary of the post."
   date: YYYY-MM-DDT00:00:00Z
   publishDate: YYYY-MM-DDT00:00:00Z
   draft: true
   categories:
     - deep-dive
   tags:
     - tag1
     - tag2
     - blog
   showToc: true
   tocOpen: false
   ---
   ```

   Use today's date. Suggest appropriate categories and tags based on the topic. Always include `blog` in tags. Set `draft: true`.

   Present a summary of the file to be created (path, title, tags, categories) and ask the user to confirm before writing the file.

5. **Generate a story outline**
   Based on the topic, the running thread and any gathered Obsidian context,
   outline the post as a story, not as a list of topics. For `deep-dive` and
   `engineering` posts use this arc (other categories use the subset in the
   playbook's "Shape by category" table):

   ```markdown
   <!-- No heading: open with prose. What we'll do together, then the opening experiment and its real output. -->
   <!-- Why it matters / short history, with inline links and named credits. -->
   <!-- Journey promise in 3-4 sentences, naming the running thread. -->
   <!-- Thanks / disclosure / one pointer to the code. -->

   ## <Step 1: the first thing we look at>
   <!-- Opens from the previous section. Plant something for later. -->

   ## <Step 2: one step harder>
   <!-- Each section is one rung up the ladder. -->

   ## <The real tool / the real-world version>
   <!-- "Everything our toy does, badly, X does for real." -->

   ## <Back to the running thread>
   <!-- Pay off what was planted. -->

   ## Try it yourself
   <!-- What to run, then a short crescendo. No summary. -->
   ```

   Section titles describe what happens in the story ("The cache will lie to
   you"), not the topic ("Caching"). Ask the user if they want to adjust the
   outline before proceeding.

6. **Flesh out sections** (optional)
   Ask the user if they want to flesh out sections now. If yes:
   - Use web search to gather current information if the topic requires it
   - Draft each section based on the outline and any Obsidian notes
   - Include code snippets where relevant
   - Follow `.agents/skills/kemal-voice/SKILL.md` and the story playbook: "we" for the journey, every code block introduced and explained, sources linked inline, a few whimsical asides

   If no, leave the outline with placeholder comments for each section.

7. **Create a Things 3 task**
   Check if the Things 3 MCP tools are available (`things/add_todo`). If available, present a summary before creating:
   > I'll create a Things 3 task: "Edit and publish: Post Title" with tags writing, blog. Proceed?

   On confirmation, use `things/add_todo` MCP tool to create the task:
   - Title: `Edit and publish: "Post Title"`
   - Notes: `Draft at ~/Vaults/blog/content/posts/<slug>.md`
   - Tags: `writing`, `blog`

   **Fallback:** If Things 3 MCP is not available, skip and print the suggested task in a copyable format instead.

8. **Present the result**
   Show the user:
   - The full path to the created draft
   - The outline or content summary
   - The Things 3 task (if created)
   - Remind them the post is set to `draft: true`

## Common Mistakes

- Starting to write without a clear thesis or angle — always nail down the angle in step 1
- Including too many topics in a single post — if the outline has more than 4-5 sections, suggest splitting into a series
- Skipping the outline step and jumping straight to prose — the outline is the skeleton that prevents rambling
- Outlining topics instead of a story — "Introduction / Section 1 / Conclusion" produces a schematic post; outline the steps of the journey and the running thread instead
- Starting the post with a heading — open with prose
- Using generic tags that do not aid discoverability — tags should be specific technologies or concepts
- Forgetting to set `draft: true` — never publish directly from this workflow
