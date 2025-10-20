# Hugo Website Content Management Rules

## Content Structure and Organization

When creating or modifying content for this Hugo website, follow these guidelines:

### Directory Structure

```
content/
├── posts/          # Blog posts (technical findings, tutorials, ramblings)
├── about.md        # About page
├── talks.md        # Talks and presentations
├── open_source.md  # Open source projects
├── now.md          # Now page
├── uses.md         # Uses page
└── keybase.txt     # Keybase verification
```

### File Naming

- Blog posts: `YYYY-MM-DD-title.md` (e.g., `2024-03-21-kubernetes-adventures.md`)
- Static pages: `page-name.md` (e.g., `about.md`, `talks.md`)
- Use kebab-case for all filenames

### Front Matter Template

```yaml
---
title: "Your Witty Title Here"
date: {{ .Date }}
draft: true
description: "A brief, engaging description that makes people want to read more"
tags: ["tag1", "tag2"]
categories: ["technical-findings", "tutorials", "ramblings"]
lastmod: {{ .Date }}
toc: true  # For longer technical posts
---
```

## Content Guidelines

### Markdown Standards

- Headers: Use ATX-style (`#` for H1, `##` for H2)
- Links: Use reference-style for better readability
- Images: Always include alt text and captions
- Code: Specify language in fenced blocks
- Emojis: Use strategically to add personality

### Hugo-Specific

- Use page bundles for posts with multiple resources
- Implement shortcodes appropriately:
  - `{{< figure >}}` for images
  - `{{< highlight >}}` for code
  - `{{< ref >}}` for internal links
  - `{{< tweet >}}` for embedding tweets
  - `{{< gist >}}` for GitHub gists

### SEO & Performance

- Write engaging meta descriptions
- Use descriptive URLs and titles
- Maintain proper heading hierarchy
- Include relevant tags and categories
- Optimize images before upload

### Quality Checklist

- [ ] Engaging title that hints at content
- [ ] Front matter complete and valid
- [ ] Grammar and spelling checked
- [ ] Technical accuracy verified
- [ ] Code blocks properly formatted
- [ ] Humor enhances rather than distracts
- [ ] Images optimized and accessible
- [ ] Links validated
- [ ] Mobile responsiveness verified

## Example Usage

### Blog Post Template

```markdown
---
title: "That Time I Broke Production (And Lived to Tell About It) 🔥"
date: 2024-03-21
draft: true
description: "A cautionary tale of confidence, chaos, and eventual redemption in the world of distributed systems"
tags: ["distributed-systems", "lessons-learned", "debugging"]
categories: ["technical-findings"]
toc: true
---

# That Time I Broke Production

> TL;DR: Don't deploy on Fridays. No, really. I mean it this time.

## The Setup (Or: How I Got Too Confident)

[Engaging introduction about what I was trying to achieve]

## What Could Possibly Go Wrong?

[Narrator: Everything went wrong]

## The Investigation

```go
// The code I thought would work
func whatCouldGoWrong() {
    // Surely this will be fine
}
```

## The Solution

[How I fixed it, and what I learned]

```

### Image Implementation
```markdown
{{< figure src="disaster.jpg"
    alt="A perfectly normal production deployment"
    caption="Everything is fine 🔥"
    loading="lazy"
>}}
```

### Code Block Example

```markdown
{{< highlight go "linenos=table,hl_lines=8 15-17" >}}
// The code that actually worked
func lessonsLearned() error {
    return errors.New("always check your assumptions")
}
{{< /highlight >}}
```
