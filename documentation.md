# Hugo PaperMod Theme Documentation

## Overview

This documentation provides a reference for using the [Hugo](https://gohugo.io/) static site generator with the [PaperMod](https://github.com/adityatelange/hugo-PaperMod) theme. PaperMod is a fast, clean, and responsive Hugo theme suitable for blogs, personal websites, and portfolios.

## Quick Start

### Installation

There are several ways to install the PaperMod theme:

1. **As Git Submodule (recommended)**:

   ```bash
   git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
   git submodule update --init --recursive
   ```

2. **To update the theme**:

   ```bash
   git submodule update --remote --merge
   ```

### Basic Configuration

Add to your `config.yaml`:

```yaml
theme: "PaperMod"
```

## Theme Modes

PaperMod offers three primary modes for your homepage:

### 1. Regular Mode (Default)

Shows regular posts list on homepage.

### 2. Home-Info Mode

Shows custom info on homepage instead of latest posts.

To enable Home-Info mode, add to your `config.yaml`:

```yaml
params:
  homeInfoParams:
    Title: "Hi there 👋"
    Content: >
      Welcome to my blog

      - I write about technology and programming

      - I'm a software engineer specializing in web development

    # Optionally, add buttons
    buttons:
      - name: Blog
        url: posts
      - name: Projects
        url: projects
```

Example profile content:

```yaml
homeInfoParams:
  Title: "Your Name"
  Content: >
    Cloud Infrastructure Engineer

    Observability | Performance | Reliability

    System Programming
    Go | C | Zig

    Linux | eBPF | Instrumentation
    Profiling | Tracing | Monitoring
```

### 3. Profile Mode

Shows your profile information with image on homepage.

To enable Profile mode, add to your `config.yaml`:

```yaml
params:
  profileMode:
    enabled: true
    title: "Your Name"
    subtitle: "Your Role or Tagline"
    imageUrl: "img/profile.jpg"
    imageWidth: 120
    imageHeight: 120
    imageTitle: "My Profile Image"

    # Optional buttons
    buttons:
      - name: Archive
        url: /archive
      - name: GitHub
        url: https://github.com/yourusername
```

## Key Features

PaperMod includes many features that enhance your Hugo site:

- Light/Dark mode with automatic switching
- Table of Contents generation
- Multiple author support
- Social icons and share buttons
- SEO-friendly structure
- Archive page
- Search functionality
- Multilingual support
- Cover images for posts
- Code syntax highlighting
- Responsive design

## Common Configuration Variables

Here are some of the most commonly used configuration variables:

### Site Variables (in `params:`)

| Variable | Type | Description |
|----------|------|-------------|
| `title` | string | Site title |
| `description` | string | Site description |
| `author` | string/list | Site author(s) |
| `defaultTheme` | string | Default theme (light/dark/auto) |
| `ShowReadingTime` | boolean | Show reading time for posts |
| `ShowShareButtons` | boolean | Show share buttons on posts |
| `ShowBreadCrumbs` | boolean | Show breadcrumb navigation |
| `ShowPostNavLinks` | boolean | Show previous/next post links |
| `ShowCodeCopyButtons` | boolean | Show copy buttons for code blocks |
| `showtoc` | boolean | Show table of contents |
| `disableThemeToggle` | boolean | Disable theme toggle icon |
| `disableSpecial1stPost` | boolean | Disable special appearance of 1st post |
| `disableScrollToTop` | boolean | Disable scroll-to-top button |
| `hideMeta` | boolean | Hide meta elements on pages |
| `hideSummary` | boolean | Hide summary in list pages |
| `tocopen` | boolean | Keep ToC open by default |
| `ShowWordCount` | boolean | Show word count in metadata |
| `displayFullLangName` | boolean | Show full language name in language menu |

### Social Icons Configuration

Add social icons to your site with:

```yaml
params:
  socialIcons:
    - name: github
      url: "https://github.com/yourusername"
    - name: twitter
      url: "https://twitter.com/yourusername"
    - name: linkedin
      url: "https://linkedin.com/in/yourusername"
    - name: email
      url: "mailto:you@example.com"
```

### Schema Configuration

Customize schema data for better SEO:

```yaml
params:
  schema:
    publisherType: "Organization" # or "Person"
    sameAs:
      - "https://github.com/yourusername"
      - "https://linkedin.com/in/yourusername"
```

### Search Configuration

Enable search functionality:

```yaml
outputs:
  home:
    - HTML
    - RSS
    - JSON # Required for search

params:
  fuseOpts:
    isCaseSensitive: false
    shouldSort: true
    location: 0
    distance: 1000
    threshold: 0.4
    minMatchCharLength: 0
    keys: ["title", "permalink", "summary", "content"]
```

### Page Variables (in front matter)

| Variable | Type | Description |
|----------|------|-------------|
| `title` | string | Page title |
| `description` | string | Page description |
| `cover.image` | string | Cover image path |
| `cover.alt` | string | Alt text for cover image |
| `cover.caption` | string | Caption for cover image |
| `cover.relative` | boolean | Use relative path for cover image |
| `showtoc` | boolean | Show/hide table of contents |
| `hidemeta` | boolean | Hide metadata (date, read time, etc.) |
| `comments` | boolean | Enable/disable comments |
| `weight` | integer | Set page order or pin post to top |
| `searchHidden` | boolean | Hide page from search |
| `canonicalURL` | string | Canonical URL for the page |
| `ShowCanonicalLink` | boolean | Show canonical URL's hostname |
| `disableShare` | boolean | Hide share icons for the page |
| `robotsNoIndex` | boolean | Hide from search engine indexing |

## Cover Images

Configure cover images with:

```yaml
params:
  cover:
    linkFullImages: true # Open full-size cover images on click
    responsiveImages: true # Generate responsive cover images
    hidden: false # Hide everywhere except structured data
    hiddenInList: false # Hide on list pages and home
    hiddenInSingle: false # Hide on single pages
```

## Assets and Customization

To customize CSS or other assets:

1. Create a folder structure: `assets/css/extended/`
2. Add your custom CSS file, e.g., `custom.css`

PaperMod will automatically load this CSS.

Customize favicon and colors:

```yaml
params:
  assets:
    favicon: "favicon.ico"
    disableFingerprinting: true # Disable SRI
    theme_color: "#1d1e20"
    msapplication_TileColor: "#1d1e20"
```

## Label Customization

Customize the site label:

```yaml
params:
  label:
    text: "Home"
    icon: "/apple-touch-icon.png"
    iconHeight: 35
```

## Edit Post Button

Add "Edit Post" buttons to pages:

```yaml
params:
  editPost:
    URL: "https://github.com/username/repo/content"
    Text: "Suggest Changes"
    appendFilePath: true  # Append file path to edit link
```

## Deployment with Netlify

For Netlify deployment, use the following build commands:

```
hugo --minify --gc
```

This can be automated using the Makefile in this project with:

```
make netlify-deploy
```

## Creating Archive Page

Create an archive page that lists all posts:

1. Create `content/archives.md`
2. Add this content:

```markdown
---
title: "Archive"
layout: "archives"
url: "/archives/"
summary: "archives"
---
```

## Multilingual Setup

PaperMod supports multilingual sites. Configure in `config.yaml`:

```yaml
languages:
  en:
    languageName: "English"
    weight: 1
    menu:
      main:
        - name: Archive
          url: archives
          weight: 5
  fr:
    languageName: "Français"
    weight: 2
    menu:
      main:
        - name: Archives
          url: archives
          weight: 5
```

## Common Templates and Overrides

Common files to override for customization:

- `layouts/partials/header.html` - Modify site header
- `layouts/partials/footer.html` - Modify site footer
- `layouts/_default/single.html` - Modify single post layout
- `layouts/_default/list.html` - Modify list page layout
- `layouts/partials/extend_head.html` - Add custom elements to the head

## Tips for Future Development

1. **Keep theme updated**: Regularly update the theme to get new features and bug fixes

   ```bash
   git submodule update --remote --merge
   ```

2. **Use theme overrides instead of modifying theme files**:
   - Create files in `layouts/partials/` with the same name as the theme's files
   - Add custom CSS in `assets/css/extended/`

3. **Check theme documentation**: The PaperMod wiki is regularly updated with new features and variables.

## Resources

- [Hugo Documentation](https://gohugo.io/documentation/)
- [PaperMod GitHub Repository](https://github.com/adityatelange/hugo-PaperMod)
- [PaperMod Wiki: Variables](https://github.com/adityatelange/hugo-PaperMod/wiki/Variables)
- [PaperMod Wiki: Features](https://github.com/adityatelange/hugo-PaperMod/wiki/Features)
- [PaperMod Wiki: Installation](https://github.com/adityatelange/hugo-PaperMod/wiki/Installation)
- [PaperMod Wiki: FAQs](https://github.com/adityatelange/hugo-PaperMod/wiki/FAQs)

---

## Custom Shortcodes: Sidenotes & Tooltips

These project-specific shortcodes enhance readability and annotation without adding JavaScript. Implemented in `layouts/shortcodes/` with styles in `assets/css/extended/sidenotes-tooltips.css`.

### Sidenotes (Update: side support)
You can control margin placement:
```markdown
{{< sidenote >}}Defaults to right margin.{{< /sidenote >}}
{{< sidenote side="left" >}}Force left margin placement.{{< /sidenote >}}
{{< sidenote side="alternate" >}}First alternates left/right automatically.{{< /sidenote >}}
```
Class applied: `sidenote--left` or `sidenote--right`. `alternate` cycles per page instance.

Auto‑numbered per page using `Page.Scratch`.

Basic usage:
```markdown
This is a sentence with a sidenote. {{< sidenote >}}Supporting thought or citation here.{{< /sidenote >}}
```

Custom label & id:
```markdown
{{< sidenote id="sn-star" label="★" >}}A highlighted annotation.{{< /sidenote >}}
```

Output structure (simplified):
```html
<span class="sidenote-ref"><sup><a href="#sn-1">1</a></sup></span>
<aside class="sidenote" id="sn-1" role="note">
  <span class="sidenote-label">1</span>
  <span class="sidenote-content">…</span>
  <a class="sidenote-back" href="#ref-sn-1">↩</a>
</aside>
```

Behavior:
- Inline block on mobile / narrow viewports.
- On wide screens (≥1100px) positioned in right gutter.
- Prints inline (no loss of context).

### Tooltips
Contextual inline definitions; pure CSS hover + focus (keyboard accessible).

Basic positional usage:
```markdown
Understanding {{< tooltip "eBPF" >}}Extended Berkeley Packet Filter: in-kernel programmable instrumentation.{{< /tooltip >}} changes everything.
```

Named params with placement (top|right|bottom|left):
```markdown
{{< tooltip term="L3 Cache" placement="right" >}}Last-level CPU cache shared by cores in a package.{{< /tooltip >}}
```

Generated markup (simplified):
```html
<span class="tooltip" data-placement="top">
  <span class="tooltip-term" tabindex="0">eBPF</span>
  <span role="tooltip" class="tooltip-bubble">Extended Berkeley …</span>
</span>
```

### Accessibility Notes
- Sidenotes use `role="note"` and provide a return link (↩) to reference.
- Tooltip trigger gets `tabindex="0"`; bubble has `role="tooltip"` for assistive tech.
- Dark mode styles adjust automatically.
- Print media: tooltips render inline text; sidenote layout becomes linear.

### Performance & Theming
- No JavaScript; minimal additional CSS.
- Styles isolated in a single extended stylesheet; safe to adjust color variables via custom properties if needed.

### Customization Ideas
- Change breakpoint or width in `.sidenote` media query.
- Add ARIA `describedby` linking (assign id to bubble) if stricter accessibility needed.
- Provide alternate left-margin layout by adjusting `right: -26ch;` to `left: -26ch;`.

### Quick Reference
| Feature | Shortcode | Key Params | Notes |
|---------|-----------|------------|-------|
| Sidenote | `sidenote` | `id`, `label` | Auto-numbering; margin on wide screens |
| Tooltip | `tooltip` | positional term OR `term`, `placement` | Pure CSS; accessible focus |

If adding new semantic annotation types, follow this pattern: shortcode template + minimal CSS in `assets/css/extended/` + accessible roles.
