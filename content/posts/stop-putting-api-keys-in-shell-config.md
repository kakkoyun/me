---
title: "Stop Putting API Keys in Your Shell Config"
description: "The agentic coding boom has developers pasting API keys into .zshrc in plaintext. Use the 1Password CLI to manage secrets properly in five minutes."
date: 2026-02-12T00:00:00Z
publishDate: 2026-02-12T00:00:00Z
categories:
  - deep-dive
tags:
  - security
  - secrets-management
  - api-keys
  - 1password
  - cli
  - tooling
  - developer-experience
  - ai
  - dotfiles
  - blog
showToc: true
tocOpen: false
---

We all know better. Don't hardcode secrets. Use a vault. Rotate your keys. We've been saying this for years.

And then the **agentic coding boom** happened.

Suddenly every tool wants an API key. OpenAI, Anthropic, Gemini, Groq, Mistral, Replicate—the list grows weekly. And where do those keys end up? Right there in `.zshrc`, in plain text, because you needed it working *right now* and you were going to fix it later.

```bash
# The "I'll fix this later" hall of shame
export OPENAI_API_KEY=sk-proj-abc123...
export ANTHROPIC_API_KEY=sk-ant-xyz789...
export GEMINI_API_KEY=AIzaSy...
```

I caught myself doing exactly this. Two API keys, sitting in my dotfiles, probably backed up to Time Machine, possibly in shell history, definitely in my terminal scrollback. Let's fix this properly.

## The Problem

Plain text API keys in shell configs are bad for reasons you already know:

1. **Shell history** — `~/.zsh_history` records commands, and sometimes you `echo $OPENAI_API_KEY` to debug something
2. **Backup snapshots** — Time Machine, cloud backups, dotfile repos all capture the file
3. **Shoulder surfing** — `cat ~/.zshrc` during a screen share or a pairing session
4. **Terminal scrollback** — the key is sitting in your terminal buffer right now

And this isn't just a theoretical risk. Attackers actively scan repos and backups for unprotected credentials — and when they find stolen API keys, they rack up thousands of dollars in charges. The platform bills the original owner.

The "I'll rotate it later" never comes. Meanwhile these keys have billing attached to them.

## The Fix: 1Password CLI

If you use 1Password, you already have a secret manager with biometric unlock, audit logging, and team sharing. The `op` CLI lets you pull secrets into your shell without ever writing them to disk.

### Step 1: Install the CLI

```bash
brew install --cask 1password-cli
```

Enable the CLI integration in 1Password desktop app: **Settings > Developer > Connect with 1Password CLI**. This lets the CLI authenticate via the desktop app (Touch ID on Mac) instead of requiring a separate login.

### Step 2: Store Your Keys

```bash
op item create \
  --category="API Credential" \
  --title="OpenAI API Key" \
  --vault="Private" \
  "credential=sk-proj-your-key-here"

op item create \
  --category="API Credential" \
  --title="Gemini API Key" \
  --vault="Private" \
  "credential=AIzaSy-your-key-here"
```

### Step 3: Replace Hardcoded Values

In your `.zshrc` (or `.bashrc`, `.profile`, whatever you use):

```diff
- export OPENAI_API_KEY=sk-proj-abc123...
- export GEMINI_API_KEY=AIzaSy...
+ export OPENAI_API_KEY=$(op read "op://Private/OpenAI API Key/credential" --no-newline 2>/dev/null)
+ export GEMINI_API_KEY=$(op read "op://Private/Gemini API Key/credential" --no-newline 2>/dev/null)
```

That's it. Three steps. The keys now live in 1Password, protected by your master password and biometric auth.

One catch: this triggers a 1Password biometric prompt every time you open a terminal. If that bothers you (it bothered me), see [Shell Startup Speed](#what-about-shell-startup-speed) for the lazy-loading version that only prompts when you actually run a command.

### Step 4: Rotate the Old Keys

This is the step people skip. **Do it now.** The old keys have been in plaintext. Assume they're compromised.

- OpenAI: [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
- Google AI: [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
- Anthropic: [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)

Generate new keys, update the 1Password items with `op item edit`, and you're done.

## The Details Worth Knowing

### Why `--no-newline`?

`op read` appends a trailing newline by default. API keys with a stray newline cause cryptic authentication failures—the kind where the key "looks right" but every request returns 401. The `--no-newline` flag strips it.

### Why `2>/dev/null`?

If 1Password is locked or the CLI isn't authenticated, `op read` writes an error to stderr. The redirect silences that so you don't get a wall of errors every time you open a terminal without 1Password unlocked. The variable simply becomes empty.

The tradeoff: a misconfigured vault path also fails silently. Test it once after setup, and you're fine.

### What About Shell Startup Speed?

The eager approach above runs `op read` at shell init, which means every new terminal triggers a 1Password biometric prompt. If you open terminals frequently, this gets old fast.

The fix is lazy loading with command-specific triggers. In zsh, the `preexec` hook fires right before a command executes and receives the command string — perfect for deciding *which* secrets to load *when*:

```bash
# Map: env var → 1Password secret reference
typeset -A _op_refs=(
  OPENAI_API_KEY  "op://Private/OpenAI API Key/credential"
  GEMINI_API_KEY  "op://Private/Gemini API Key/credential"
)

# Map: command → which keys it needs
typeset -A _op_cmd_keys=(
  codex   "OPENAI_API_KEY"
  aider   "OPENAI_API_KEY GEMINI_API_KEY"
  gemini  "GEMINI_API_KEY"
)

_maybe_load_op_secrets() {
  local cmd="${1%% *}"     # extract first word
  cmd="${cmd##*/}"         # strip path prefix
  local keys="${_op_cmd_keys[$cmd]}"
  [[ -z "$keys" ]] && return
  for key in ${=keys}; do
    [[ -n "${(P)key}" ]] && continue   # already loaded
    export "$key=$(op read "${_op_refs[$key]}" --no-newline 2>/dev/null)"
  done
}
preexec_functions+=(_maybe_load_op_secrets)

# Manual fallback: load everything
load-secrets() {
  for key ref in "${(@kv)_op_refs}"; do
    export "$key=$(op read "$ref" --no-newline 2>/dev/null)"
  done
}
```

This gives you three properties:

- **No startup cost** — terminal opens instantly, no biometric prompt
- **Least privilege** — `codex` only loads `OPENAI_API_KEY`, not every secret you have
- **Load once** — each key is fetched at most once per session (the `${(P)key}` guard skips keys that are already set)

Adding a new tool is one line in `_op_cmd_keys`. Adding a new key is one line in `_op_refs`.

If you have multiple 1Password accounts (personal + work), add `--account=my.1password.com` to the `op read` calls to avoid vault name collisions.

For even more granularity:

1. **`op run`** — inject secrets into a specific command rather than the global environment:

```bash
# Only injects the key for this one command
op run --env-file=.env.1password -- python train.py
```

2. **`op inject`** — when you have a dozen keys, individual `op read` calls add up. With `op inject`, you define all your secrets in a single template and load them in one shot:

```bash
# ~/.env.op (template — safe to commit, contains no secrets)
export OPENAI_API_KEY={{ op://Private/OpenAI API Key/credential }}
export GEMINI_API_KEY={{ op://Private/Gemini API Key/credential }}
export ANTHROPIC_API_KEY={{ op://Private/Anthropic API Key/credential }}
```

```bash
# In .zshrc — one CLI call loads everything
eval "$(op inject --in-file ~/.env.op)"
```

This is substantially faster than N individual `op read` calls — the CLI resolves all references in a single authentication round-trip.

3. **Scoped injection** — skip the global environment entirely and inject a key for exactly one command's lifetime:

```bash
OPENAI_API_KEY=$(op read "op://Private/OpenAI API Key/credential" --no-newline) python train.py
```

The key exists only in that command's process environment. Nothing touches your shell, nothing lingers after the process exits. This is the most paranoid option, and it's great for CI scripts or one-off runs.

### What About macOS Keychain?

macOS Keychain (`security find-generic-password`) works too and has zero startup overhead since it's always unlocked when you're logged in. I use it for some tokens:

```bash
export GITLAB_TOKEN=$(security find-generic-password -a ${USER} -s gitlab_token -w)
```

The advantage of 1Password over Keychain: cross-device sync, team sharing, audit logs, and a UI that doesn't make you question your life choices. Use whichever fits your workflow. The point is to stop storing secrets in plain text.

## The Agentic Boom Made This Worse

A year ago, most developers had maybe one or two API keys. Now? I know people with **six or more** AI service keys in their shell config. Coding agents need them. MCP servers need them. Every new tool in the ecosystem asks you to "just export your API key" and the docs always show the hardcoded version because it's simpler to explain.

MCP servers are the newest vector here. Tools like Claude Code, Cursor, and Windsurf use configuration files (`claude_desktop_config.json`, `mcp.json`) that store API keys for tool servers. The LLM itself never sees the secret values — the MCP server process does — but only if you inject them properly. Hardcoding keys in MCP configs is the same mistake as hardcoding them in `.zshrc`, just in a newer file. The `op` CLI works here too: use `op run` or environment variable references in your MCP server configs instead of raw keys.

This is a tooling culture problem. The default getting-started experience for almost every AI API is:

```bash
export MAGIC_AI_KEY=your-key-here  # don't do this
```

We should normalize showing the secure version in documentation. Until that happens, take five minutes and move your keys to a vault. Your future self (and your billing page) will thank you.

## TL;DR

```bash
# Before: plain text keys in .zshrc
export OPENAI_API_KEY=sk-proj-...

# After: lazy-loaded from 1Password, per-command per-key
typeset -A _op_refs=(
  OPENAI_API_KEY  "op://Private/OpenAI API Key/credential"
  GEMINI_API_KEY  "op://Private/Gemini API Key/credential"
)
typeset -A _op_cmd_keys=(
  codex  "OPENAI_API_KEY"
  aider  "OPENAI_API_KEY GEMINI_API_KEY"
)
_maybe_load_op_secrets() {
  local cmd="${1%% *}"; cmd="${cmd##*/}"
  local keys="${_op_cmd_keys[$cmd]}"
  [[ -z "$keys" ]] && return
  for key in ${=keys}; do
    [[ -n "${(P)key}" ]] && continue
    export "$key=$(op read "${_op_refs[$key]}" --no-newline 2>/dev/null)"
  done
}
preexec_functions+=(_maybe_load_op_secrets)
```

Install `op`, store your keys, replace the exports, rotate the old keys. Five minutes. Zero excuses.

## Further Reading

- [Securing MCP Servers with 1Password](https://1password.com/blog/securing-mcp-servers-with-1password-stop-credential-exposure-in-your-agent) — 1Password's take on stopping credential exposure in agent configurations
- [Secure Environment Variables for LLMs, MCPs, and AI Tools](https://williamcallahan.com/blog/secure-environment-variables-1password-doppler-llms-mcps-ai-tools) — William Callahan's walkthrough of using 1Password CLI and Doppler for AI tool secrets
- [Where MCP Fits and Where It Doesn't](https://1password.com/blog/where-mcp-fits-and-where-it-doesnt) — 1Password on the security model of MCP and credential boundaries
- [1Password CLI: Secret References](https://developer.1password.com/docs/cli/secret-references/) — official docs on the `op://` URI scheme
- [1Password CLI: `op inject`](https://developer.1password.com/docs/cli/reference/commands/inject/) — batch-load secrets from template files
- [1Password Shell Plugins](https://developer.1password.com/docs/cli/shell-plugins/) — native integrations for CLI tools like `gh`, `aws`, and `stripe`
