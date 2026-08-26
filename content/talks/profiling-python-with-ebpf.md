---
title: "talk: Profiling Python with eBPF: A New Frontier in Performance Analysis"
description: "Sampling Python stacks from the kernel with eBPF: why an interpreter is harder to unwind than a native binary, and how Parca learned to walk CPython's frames."
date: 2024-02-04T00:00:00Z
publishDate: 2024-02-04T00:00:00Z
categories:
  - talks
tags:
  - talks
  - profiling
  - ebpf
  - python
  - Parca
  - observability
cover:
  image: https://img.youtube.com/vi/nNbU26CoMWA/maxresdefault.jpg
  alt: "Profiling Python with eBPF: A New Frontier in Performance Analysis"
  caption: FOSDEM 2024 — Python Devroom
---

Most Python profilers ask you to decide in advance. You import something, or you wrap the process, or you restart it with a flag. That works on your laptop and helps little at 3 a.m., when the profile you want is of a process that has already been running for six hours.

eBPF changes the bargain. An agent samples from the kernel on a timer, and the application never knows it is there. For compiled code that is close to free: read the registers, walk the frames, resolve the addresses against DWARF. Python is where it stops being easy.

A CPython stack is not a machine stack. The interpreter keeps its own bookkeeping — interpreter state, a linked list of thread states, a chain of frame objects — and the function names you actually want live in there rather than in the native frames. Which leaves the agent to reverse-engineer those structures, work out the field offsets for the exact CPython build in front of it, then follow the thread state to whichever thread holds the GIL and walk the frames by hand, all within the kernel verifier's limits.

This talk walks through that work as it landed in Parca: what the structures look like, how the offsets get found, which Python versions are supported and why the list has holes, and what Python 3.13 changes for anyone attempting this. Including the unglamorous part, which is that a good deal of it is version-specific glue that has to be re-derived every release.

#### Recording

<iframe width="560" height="315" src="https://www.youtube.com/embed/nNbU26CoMWA" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

**Slides**

* [Profiling Python with eBPF: A New Frontier in Performance Analysis](https://kakkoyun.me/notes/presentations/FOSDEM24+-+Profiling+Python+with+eBPF+-+A+New+Frontier+in+Performance+Analysis)
  * [Slides - Markdown](https://github.com/kakkoyun/public-content/blob/main/presentations/2024/FOSDEM%202024%20-%20Profiling%20Python%20with%20eBPF%20-%20A%20New%20Frontier%20in%20Performance%20Analysis.md)

**Demo/Code**

* [Parca](https://github.com/parca-dev/parca) — the continuous profiler this work landed in
* [Parca Agent](https://github.com/parca-dev/parca-agent) — the eBPF agent that does the unwinding

**Events**

* [FOSDEM 2024 — Python Devroom](https://archive.fosdem.org/2024/schedule/track/python-devroom/)
  * [Recording](https://www.youtube.com/watch?v=nNbU26CoMWA)

**Related**

* [Profiling Python with eBPF: A New Frontier in Performance Analysis](/posts/profiling-python-with-ebpf/) — full technical blog post expanding on this talk
