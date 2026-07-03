---
title: Start Here
description: "A curated map of the blog: reading paths through profiling and symbolization, eBPF and instrumentation, Go performance, and AI-assisted engineering."
date: 2026-07-03T00:00:00Z
showToc: false
comments: false
disableShare: true
showWordCount: false
showReadingTime: false
---

This blog goes back to 2019, and the archive won't tell you which posts are worth your time. This page will.

I work on Go instrumentation at Datadog APM. Before that I built continuous profiling at Polar Signals (Parca), and I maintain Prometheus. Most of what follows comes out of that work: making production systems legible, then measuring them honestly. Pick the path that matches whatever dragged you here.

## Profiling and symbolization

How profilers turn a running program into something a human can read. Start with the pictures, then work down to the symbol tables underneath.

- [Ice and Fire: How to read icicle and flame graphs](/posts/ice-and-fire/). If a flame graph has ever stared back at you, start here. What the widths mean, why icicles hang upside down, and when to reach for each.
- [Fantastic Symbols and Where to Find Them - Part 1](/posts/fantastic-symbols-and-where-to-find-them/). How debuggers and profilers translate raw memory addresses into function names using ELF, DWARF, and symbol tables. The compiled-language half of the story.
- [Fantastic Symbols and Where to Find Them - Part 2](/posts/fantastic-symbols-and-where-to-find-them-part-2/). The messy half: finding symbols in Python, Ruby, JavaScript, the JVM, and other runtimes that generate code on the fly.
- [Profiling Python with eBPF](/posts/profiling-python-with-ebpf/). What it takes to profile Python continuously in production without touching the code, using Parca.

## eBPF and instrumentation

Getting telemetry out of programs that were never asked politely. I spent years building eBPF-based profilers; these days I instrument Go for a living.

- [Profiling Python and Ruby using eBPF](/posts/profiling-python-and-ruby-using-ebpf/). Interpreter internals from the kernel's point of view: how an eBPF profiler walks a Python or Ruby stack.
- [Auto-Instrumenting Go: From eBPF to USDT Probes](/posts/fosdem-2026-auto-instrumenting-go/). Four ways to instrument Go without changing source code (eBPF, compile-time, runtime injection, USDT), with benchmarks. My day job, measured.
- [OTel Unplugged EU 2026: Field Notes](/posts/otel-unplugged-eu-2026/). Where OpenTelemetry auto-instrumentation is heading, straight from the hallway track in Brussels.

## Go and performance

Making Go fast, and proving it with numbers instead of vibes.

- [Measuring Software Performance: Why Your Benchmarks Are Probably Lying](/posts/fosdem-2026-measuring-software-performance/). Opens with a loose cable that briefly broke physics, ends with practical advice on hardware noise and statistics.
- [Fix Go Module Downloads Behind a Corporate VPN](/posts/goproxy-fallback-behind-vpn/). A small GOPROXY trick (the pipe separator) for when the corporate module proxy is unreachable.
- [Making Drone Builds 10 Times Faster!](/posts/making-drone-builds-10-times-faster/). The post that started this blog: building and open-sourcing drone-cache to cut CI times.

If the Go toolchain itself is your thing, the talk [Unleashing the Go Toolchain](/talks/unleashing-the-go-toolchain/) covers what `-toolexec` makes possible at compile time.

## AI-assisted engineering

The newest thread. I'm figuring this out in public, same as everyone else.

- [Vibe Coding with Cursor: My R&D Week Adventure](/posts/2024-03-21-vibe-coding-with-cursor/). A week of using an AI-powered IDE for everything, code and notes alike. Where it shines and where it face-plants.
- [Stop Putting API Keys in Your Shell Config](/posts/stop-putting-api-keys-in-shell-config/). Every agent wants an API key, and your `.zshrc` is not a vault. A five-minute fix with the 1Password CLI.
- [When Hustle Culture and Personal Values Collide](/posts/hustle-culture-startup-lessons/). What a short stint at an AI/ML startup taught me about pace, values, and knowing when to leave.

## Keep going

I speak at conferences more often than I blog; the [talks page](/talks/) has recordings on Thanos, Parca, Prometheus, and eBPF going back to 2020. For new posts by email, there's the [newsletter](/newsletter/). And if you want to know who's behind all this, the [about page](/about/) has the full story, PGP key included.
