---
title: "Profiling Python with eBPF: A New Frontier in Performance Analysis"
author: Kemal Akkoyun
date: 2024-02-12
categories:
  - deep-dive
tags:
  - Profiling
  - Observability
  - Parca
  - eBPF
  - Performance
  - Analysis
  - blog
description: Discover how eBPF and Parca are transforming Python profiling, enabling continuous, efficient, and non-intrusive performance analysis directly in production.
---

# Profiling Python with eBPF: A New Frontier in Performance Analysis

Profiling Python applications can be challenging, especially in scenarios involving high-performance requirements or complex workloads. Existing tools often require code instrumentation, making them impractical for certain use cases. Enter [eBPF](https://ebpf.io/) (Extended Berkeley Packet Filter)—a revolutionary Linux technology—and the open-source project [Parca](https://parca.dev), which together are reshaping the landscape of Python profiling.

In this post, I’ll explore how eBPF enables continuous profiling, discuss challenges like stack unwinding in Python, and demonstrate the power of modern profiling tools.

You can also watch my [full talk here](https://youtu.be/nNbU26CoMWA?si=t3Mh1z6XfNwa5r7M) or refer to the [slides from the presentation](https://kakkoyun.me/notes/presentations/FOSDEM24+-+Profiling+Python+with+eBPF+-+A+New+Frontier+in+Performance+Analysis).

---

## Why Do We Need Profiling?

Profiling helps optimize performance and troubleshoot issues, such as CPU spikes, memory leaks, or out-of-memory (OOM) events. For instance:

- **Performance optimization:** Identifying bottlenecks in code.
- **Incident resolution:** Determining which function or component caused a memory spike or CPU overload.

Traditional Python profiling tools, like [`cProfile`](https://docs.python.org/3/library/profile.html) or [`py-spy`](https://github.com/benfred/py-spy), require application instrumentation, which isn't always feasible—especially in production environments where code access might be restricted. This is where eBPF shines, offering non-intrusive, external profiling.

---

## Existing Profiling Solutions in Python

The Python ecosystem offers several profiling tools, each with unique strengths:

- [`cProfile`](https://docs.python.org/3/library/profile.html): A built-in module for deterministic profiling.
- [`pyinstrument`](https://github.com/joerick/pyinstrument): A call stack profiler for Python.
- [`py-spy`](https://github.com/benfred/py-spy): A sampling profiler for Python programs.
- [`yappi`](https://github.com/sumerc/yappi): Yet Another Python Profiler, supports multithreaded programs.
- [`Pyflame`](https://pyflame.readthedocs.io/en/latest/): A ptracing profiler for Python.
- [`Scalene`](https://github.com/plasma-umass/scalene): A high-performance CPU and memory profiler.

While these tools are valuable, many require code instrumentation or introduce significant overhead, making them less suitable for continuous profiling in production environments.

---

## What Is eBPF?

Originally designed for network packet filtering, [eBPF](https://ebpf.io/) has evolved into a versatile event-driven system. It enables safe execution of custom programs inside the Linux kernel, using:

- **[Performance Monitoring Units (PMUs)](https://en.wikipedia.org/wiki/Performance_monitoring_unit):** Efficient hardware units that track CPU cycles and other metrics.
- **[Perf subsystem](https://perf.wiki.kernel.org/index.php/Main_Page):** A Linux facility for hooking into kernel and user-space events, such as CPU activity, memory allocation, or I/O.

By leveraging eBPF with PMUs, profiling becomes faster and more efficient than traditional approaches.

---

## Continuous Profiling with Parca

[Parca](https://parca.dev) is an open-source project enabling continuous profiling. Its eBPF agent hooks into [perf events](https://perf.wiki.kernel.org/index.php/Tutorial), collects stack traces, and aggregates data for visualization. The process involves:

1. **Hooking into CPU events** to monitor active functions.
2. **Stack unwinding** to trace function calls.
3. **Data aggregation and visualization** in a web-based UI.

Unlike traditional profilers, Parca introduces minimal runtime overhead, making it ideal for production workloads.

---

## Stack Unwinding: A Key Challenge

### Native Code

Profiling native code is straightforward: we unwind the stack by reading memory addresses from the CPU and resolving them into human-readable symbols using debug information (e.g., [DWARF](https://dwarfstd.org/)).

### Python Code

For Python, stack unwinding is complex due to its interpreter-based execution. Python maintains execution state in custom data structures, such as:

- **Interpreter state:** Tracks threads and their execution context.
- **Thread state:** A linked list of threads running in the interpreter.
- **Frame state:** Represents the current execution frame.

To unwind Python stacks, we must traverse these structures, extract relevant information, and map them to human-readable symbols.

---

## How Parca Profiles Python

Here’s how Parca handles Python profiling:

1. **Reverse Engineering the Python Runtime:**
   - Analyze Python’s internal structures (e.g., thread and frame states).
   - Identify offsets and symbols using tools like [GDB](https://www.gnu.org/software/gdb/) or DWARF debuggers.

2. **Unwinding Python Stacks:**
   - Traverse thread states to locate the active [Global Interpreter Lock (GIL)](https://wiki.python.org/moin/GlobalInterpreterLock) holder.
   - Walk through execution frames to collect function call data.

3. **Mapping Symbols:**
   - Resolve function addresses to readable symbols.
   - Encode line numbers and function names for better traceability.

4. **Efficient Data Handling:**
   - Use eBPF maps for kernel-to-user space communication.
   - Optimize symbol resolution by caching frequently seen traces.

---

## Python 3.13: A Game-Changer for Profiling

The upcoming Python 3.13 release introduces a debug offset structure that simplifies stack unwinding. It provides precomputed offsets for key runtime fields, eliminating much of the manual reverse engineering required for earlier versions. This improvement marks a significant leap forward for tools like Parca.

---

## Visualizing Profiles with Parca

Parca’s UI provides a comprehensive view of application performance:

- **Flame graphs**: Visualize stack traces over time, highlighting bottlenecks.
- **Filtering and Metadata**: Focus on specific languages (e.g., Python) or layers (e.g., C libraries).
- **Continuous Insights**: Compare profiles across deployments to monitor performance regressions.

For example, a flame graph might reveal inefficient recursion in a Python function, enabling developers to pinpoint and optimize the problematic code.

---

## Supported Python Versions

Parca supports profiling for Python versions from 2.7 to 3.11, with ongoing work for 3.12 and full support anticipated for 3.13. The project’s modular design allows quick adaptation to new Python runtime changes.

---

## Conclusion

Profiling Python applications with eBPF and Parca represents a new frontier in performance analysis. By leveraging eBPF and continuous profiling, we can gain invaluable insights into our applications, enabling effective performance optimization. I encourage you to explore Parca, provide feedback, and contribute to the project—it’s a collaborative effort that can benefit us all as we tackle the challenges of modern software development.

### Get Started

Watch my [full talk](https://youtu.be/nNbU26CoMWA?si=t3Mh1z6XfNwa5r7M) or check out the [presentation slides](https://kakkoyun.me/notes/presentations/FOSDEM24+-+Profiling+Python+with+eBPF+-+A+New+Frontier+in+Performance+Analysis). Explore Parca on [GitHub](https://github.com/parca-dev/parca) and join the community. Your feedback helps improve the tooling and shape the future of observability.