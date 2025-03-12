---
title: "Vibe Coding with Cursor: My R&D Week Adventure 🚀"
publishDate: "2025-03-12T00:00:00Z"
date: "2025-03-12T00:00:00Z"
draft: false
type: "posts"
categories: ["technical-findings"]
tags: ["tools", "productivity", "cursor", "second-brain", "blog"]
description: "Discovering the joy of AI-powered development and note-taking with Cursor during R&D week"
toc: true
---

# Vibe Coding with Cursor: My R&D Week Adventure 🚀

> TL;DR: Spent a week building cool stuff with [Cursor](https://cursor.com), an AI-powered IDE. Found it surprisingly effective for both coding and managing my [second brain](https://www.buildingasecondbrain.com/). When your requirements are clear, it's almost magical! ✨

## The Setup: R&D Week Vibes

You know that feeling when R&D week rolls around, and you're caught between "I should learn something useful" and "I want to have fun"? Well, this time I decided to combine both by diving deep into [Cursor](https://cursor.com), an AI-powered code editor that's been making waves in the developer community.

The mission was simple: Use Cursor for **everything** - from managing my notes to building small task-specific projects. And by everything, I mean *everything*.

## What Makes Cursor Different?

Unlike traditional IDEs that just help you write code, Cursor feels more like having a pair programmer who actually gets your context. It's built on top of VSCode (so you get all the good stuff you're used to) but adds a layer of AI-powered features that make development feel more... vibey? 😎

### The Good Parts

1. **Context-Aware AI**: The AI understands your project structure and can help with everything from code completion to refactoring. For example, when working on a React component, it automatically suggested appropriate hooks and state management patterns based on my component's purpose. When your requirements are clear, it's almost magical how it can scaffold projects and implement patterns!

2. **[Rules Feature](https://docs.cursor.com/context/rules-for-ai)**: This is where things get interesting. You can create custom rules and context for different types of work, both at the project and global level. Think project-specific coding standards, documentation patterns, and even architecture guidelines.

3. **[Notepads](https://docs.cursor.com/beta/notepads)**: Quick thoughts? Code snippets? The notepad feature is like having a smart scratchpad that understands code and can share context between different parts of your development workflow.

## Second Brain Management: A Pleasant Surprise

One of my unexpected discoveries was how well Cursor handles note-taking and [second brain](https://www.buildingasecondbrain.com/) management. Here's what made it click for me:

```markdown
- Markdown support is top-notch
- AI understands context across files
- Easy to maintain structure with rules
- Quick navigation between related notes
- File attachments for enhanced documentation
- Dynamic references using @ mentions
```

### The Rules Feature: A Game Changer

The rules feature deserves its own spotlight. Cursor offers two powerful ways to customize AI behavior (note that the older `.cursorrules` file is being deprecated in favor of this new system):

1. **Project Rules** (`.cursor/rules` directory):
   - Semantic descriptions for specific use cases
   - File pattern matching with glob patterns
   - Automatic attachment when matching files are referenced
   - Chain multiple rules using @file references
   - Version controlled with your project
   - Create new rules via command palette (`Cmd + Shift + P` > `New Cursor Rule`)

2. **Global Rules** (Cursor Settings):
   - Applied across all projects
   - Perfect for consistent preferences
   - Control output language and response style
   - Set universal development guidelines

Pro tip: Use project rules whenever possible - they're more flexible, can be version controlled, and provide better granular control over different parts of your project.

I've set up different contexts for various types of work:

- Technical blog posts (with specific writing guidelines)
- Project documentation (with architecture patterns)
- Personal notes (with custom templates)
- Code standards (with framework-specific rules)

Each context comes with its own set of rules and AI behavior. It's like having multiple specialized assistants at your disposal.

### Notepads: Beyond Simple Notes

The Notepads feature (currently in beta) has been a revelation. Think of them as enhanced reference documents that go beyond regular `.cursorrules`. I use them for:

1. **Dynamic Boilerplate Generation**:
   - Templates for common code patterns
   - Project-specific scaffolding rules
   - Consistent code structure templates

2. **Architecture Documentation**:
   - Frontend specifications
   - Backend design patterns
   - Data model documentation

3. **Development Guidelines**:
   - Team conventions
   - Best practices
   - Project-specific rules

The ability to share context between composers and chat interactions makes them incredibly powerful. Plus, you can attach files and use @ mentions to create a web of connected knowledge.

## Small Projects, Big Impact

During the week, I worked on several small, task-specific projects. The workflow typically went like this:

1. Create a new project with clear requirements
2. Set up project-specific rules and templates
3. Let the AI handle boilerplate and routine coding
4. Focus on architecture and edge cases

The AI handled a lot of the repetitive work, letting me focus on the creative aspects of each project. The clearer my requirements were, the more magical the results became. ✨

## Lessons Learned

1. **AI-Powered Doesn't Mean AI-Dependent**: Cursor enhances your workflow without taking over.

2. **Rules Are Your Friend**: Taking time to set up proper rules pays off immensely.

3. **Context is King**: The more context you provide, the better the AI assistance becomes.

4. **Second Brain Benefits**: It's not just for coding; it's a genuine knowledge management tool.

5. **Clear Requirements = Magic**: The more precise your task definition, the better the results.

## What's Next?

I'm planning to:
- Expand my rule sets for different types of work
- Create more structured templates for common architectural patterns
- Explore advanced AI features like multi-file refactoring
- Share my rules and templates with the community

## Conclusion

R&D weeks are about trying new things and finding better ways to work. This experiment with Cursor turned out to be more than just playing with a new tool - it's changed how I think about IDE capabilities and knowledge management.

The combination of familiar VSCode features with AI assistance, especially the rules system, makes it a powerful tool for both coding and knowledge work. It's not perfect (what is?), but it's definitely earned its place in my daily toolkit.

> Remember: The best tools are the ones that enhance your natural workflow rather than forcing you to adapt to them. Cursor does this surprisingly well. 👍