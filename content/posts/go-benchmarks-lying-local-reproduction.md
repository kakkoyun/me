---
title: "Before CI: Can You Trust a Benchmark on Your Own Laptop?"
description: "Same benchmark, three conditions — idle host, fully saturated host, and a container pinned to one core under the same load. The numbers show what container isolation actually buys you on macOS, and where the ceiling is."
date: 2026-09-15T00:00:00Z
publishDate: 2026-09-15T00:00:00Z
draft: true
categories:
  - engineering
tags:
  - blog
  - go
  - performance
  - benchmarking
  - docker
series:
  - Why Your Go Benchmarks Are Lying
showToc: true
tocOpen: false
---

### The Number Before CI

Most benchmark decisions start on a developer's machine. You write a function, benchmark it, look at the number. The number looks reasonable. You open a pull request.

That first number is also the least controlled measurement in the whole pipeline. It runs on hardware shared with a browser, an IDE, a Slack client, background sync daemons, and whatever your OS felt like doing while your benchmark was running. Before CI, a nightly suite, or a pinned runner — that number is the one you act on.

If it lies, everything downstream inherits the lie. Sending a noisy benchmark to CI doesn't fix the noise. It industrialises it.

This is the third post in the [Why Your Go Benchmarks Are Lying](/series/why-your-go-benchmarks-are-lying/) series. The statistics for interpreting benchmark results, including CV and how to use `benchstat`, are in the [previous post on statistical foundations](/posts/go-benchmarks-lying-statistics/). The deeper "why does measurement go wrong" context is in the [FOSDEM 2026 post on reliable measurement](/posts/fosdem-2026-measuring-software-performance/). This post is about the machine in front of you, and whether you can trust what it reports.

The short answer is: sometimes yes, if you know what you are doing. Here is how to find out which case you are in.

---

### An Experiment in Three Conditions

The question is answerable if you measure it, so we measured it.

Same benchmark, `BenchmarkMakeBuffer_Correct`, run with `-count=20 -benchtime=1s` on an Apple M4 Max, darwin/arm64, 16 logical CPUs, three conditions:

| Condition | Mean ns/op | Stddev | CV% |
|---|---|---|---|
| Idle host | 11.46 | 0.54 | 4.75 |
| Host with 16 background spinners | 34.97 | 6.60 | 18.88 |
| Container pinned to core 0, same 16 spinners | 16.28 | 0.85 | 5.25 |

The background spinners are pure busy-loops — no I/O, no allocation, just CPU contention. The "noisy" condition saturates every logical core on the host.

The container runs under `--cpuset-cpus=0 --cpus=1 --memory=512m` inside the same noisy host. The spinners never stop.

Two transitions stand out:

- Idle → Noisy: the benchmark slowed by 3× and CV jumped from 4.75% to 18.88%. Both effects share the same cause: the OS scheduler migrating the goroutine between cores, evicting warm cache lines on each migration, while the spinners contend for execution units.
- Noisy → Pinned: CV drops to 5.25%, nearly back to the idle noise floor. The absolute runtime stays elevated (16.28 ns/op against 11.46 idle), which is unsurprising for a single pinned vCPU inside a VM running a different OS and allocator, though this experiment does not isolate which of those accounts for it. The point here is the *variance*, and the variance collapses.

Container pinning, under fully saturated conditions, hands back roughly the idle noise floor. The technique is worth knowing about.

To reproduce it: clone [github.com/kakkoyun/gopherconuk-26](https://github.com/kakkoyun/gopherconuk-26) and run `make bench-docker` from `talks/go-benchmarks-lying/demo/`. That re-runs all three conditions. `make cv` recomputes the summary table from the committed output files.

---

### What Containers on macOS Actually Buy You

**5.25% CV is not a triumph. It is a ceiling.**

On a bare-metal Linux runner with SMT disabled and CPU frequency pinned, the same class of benchmark reaches around 0.05% CV, as measured in the [FOSDEM 2026 SMT experiments](https://github.com/igoragoli/fosdem-2026-software-performance). That is a hundred times tighter than what Docker on a Mac can provide.

The reason is structural. Docker Desktop on macOS runs containers inside a Linux VM using Apple's Virtualization.framework. When you pass `--cpuset-cpus=0`, you are pinning to vCPU 0 inside that VM — not to a physical core on the host. The VM scheduler can migrate that vCPU between physical cores at will, and nothing inside the container can disable host SMT or pin the host CPU clock frequency.

What container pinning *does* buy you is isolation from other containers and co-running processes. The benchmark goroutine stops migrating across the VM's virtual CPU set. That is real, and the numbers above show it matters. But the underlying sources of hardware noise — SMT contention, dynamic frequency scaling, thermal variation — remain fully in play.

Docker CPU pinning on a Mac is a practical improvement for a working laptop — not a substitute for a controlled Linux environment. If your results need to hold up to scrutiny, run them on bare metal Linux with SMT and frequency scaling disabled, and say so in the writeup. The Mac numbers are good for catching obvious regressions during development. They are not publication quality.

---

### The Linux Toolbox

Here is what each control looks like in practice, and what it actually does.

#### CPU Affinity

The OS scheduler migrates processes between cores to balance load. Each migration evicts warm cache lines. `taskset` stops this at zero setup cost:

```bash
taskset -c 0 go test -bench=. -count=10 -benchtime=2s ./...
```

Use this on Linux whenever you run `-count ≥ 10`. It costs nothing and reduces jitter from scheduler decisions.

#### Core Isolation

If you need more control, `isolcpus` at boot time hands specific cores exclusively to your benchmark process by removing them from the general scheduler:

```
# Add to kernel command line
isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3
```

After reboot, pin benchmarks to those cores with `taskset -c 2`. Suitable for a dedicated CI runner — requires a reboot and root.

For a softer version that does not require a reboot, `cset shield` achieves similar isolation at runtime:

```bash
sudo cset shield --cpu=2,3 --kthread=on
sudo cset shield --exec -- go test -bench=. -count=10 ./...
sudo cset shield --reset
```

The `--kthread=on` flag is critical — without it, kernel threads still run on the shielded cores.

#### Process Priority

`nice` raises the scheduling priority of the benchmark process relative to other processes on the system:

```bash
nice -n -5 go test -bench=. -count=10 ./...
```

The effect is modest on a quiet machine but meaningful when the system is under moderate load. For dedicated benchmarking machines, `chrt -f` (SCHED_FIFO) provides real-time scheduling:

```bash
sudo chrt -f 50 go test -bench=. -count=10 ./...
```

SCHED_FIFO starves all normal processes, including the display server, if the benchmark misbehaves. Only use it on dedicated machines or inside a resource-capped container.

#### CPU Frequency Control

Dynamic frequency scaling is the biggest source of hidden variance on Linux. The CPU boosts when thermals allow, throttles when they do not. A benchmark that runs hot shows different numbers than one that runs cool — even on identical code.

[`perflock`](https://github.com/aclements/perflock), written by Austin Clements of the Go runtime team, locks the CPU to a stable frequency for the duration of the benchmark run:

```bash
go install github.com/aclements/perflock@latest
perflock go test -bench=. -count=10 -benchtime=2s ./...
```

On Linux, `perflock` pins the CPU frequency by writing `scaling_min_freq` and `scaling_max_freq` through the cpufreq sysfs interface — the single highest-value local tool after `benchstat` for Linux users.

{{< sidenote side="right" label="perflock-mac" >}}
`perflock` builds on macOS, but its frequency pinning relies on the Linux cpufreq sysfs interface. On a Mac, the governor step errors unless you pass `-governor=none`, which leaves you with the mutual-exclusion lock and nothing else. That prevents two benchmark runs from racing each other, but does nothing for CPU frequency noise.
{{< /sidenote >}}

If you prefer to apply the sysfs controls manually:

```bash
# Performance governor
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Disable Intel Turbo Boost
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo

# Disable AMD boost
echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost

# Disable SMT (caution: halves logical CPU count)
echo off | sudo tee /sys/devices/system/cpu/smt/control
# Re-enable when done
echo on | sudo tee /sys/devices/system/cpu/smt/control
```

The SMT table from the [FOSDEM 2026 experiments](https://github.com/igoragoli/fosdem-2026-software-performance) measured ~100× variance reduction when disabling SMT on an AWS m5.metal instance — that is the number that makes bare-metal Linux worth the effort for publication-quality results.

---

### Thermal Steady-State

CPUs boost when cool and throttle when hot. A benchmark that starts with a cold chip and ends with a warm one shows a performance *decrease* across the run — nothing to do with the code.

The symptom is visible in raw `go test` output: the first few runs of a `-count=20` sequence are faster than the last few. Three things help:

1. Run the benchmark once as a throwaway before capturing.
2. Wait 30-60 seconds between major test runs.
3. Use `perflock` or disable DFS to hold frequency steady regardless of thermals.

Laptops are worse for this than desktops. Ambient temperature, prior CPU workload, and fan behavior all affect how long it takes to reach steady state. Skip the warmup run and the early samples in your distribution are biased warm.

---

### The Go-Native A/B Loop

Environment controls reduce noise. But the local workflow also needs a structured way to compare two versions of code. Go's tooling handles this well.

The manual approach:

```bash
# Capture baseline
go test -bench=BenchmarkMyFunc -benchmem -count=10 -benchtime=2s . > old.txt

# Apply change, then capture
go test -bench=BenchmarkMyFunc -benchmem -count=10 -benchtime=2s . > new.txt

# Compare
benchstat old.txt new.txt
```

For the inner development loop, [`benchdiff`](https://github.com/willabides/benchdiff) automates the git stash/checkout/run/compare cycle:

```bash
go install github.com/willabides/benchdiff/cmd/benchdiff@latest
benchdiff --base=main --benchmem --count=10 --benchtime=2s ./...
```

`benchdiff` handles the git operations, runs both sides under the same conditions, and pipes results to `benchstat` — removing the friction from the comparison workflow.

Two `go test` flags worth knowing for reproducibility:

```bash
# Fixed-iteration mode: more reproducible than time-based calibration
go test -bench=. -benchtime=100x -count=20 .

# Skip PGO if default.pgo exists in the module root
go test -bench=. -pgo=off -count=10 .
```

Time-based `-benchtime` introduces inter-run variance from `b.N` calibration. Fixed-iteration mode (`-benchtime=100x`) gives the same number of iterations every run, which makes the distribution easier to reason about.

Toolchain version matters too. Since Go 1.21, the `go` directive in `go.mod` is the toolchain pin — different Go versions produce different benchmark numbers. Pin explicitly and mention the Go version in any result you share.

---

### Cheap Wins That Take Five Minutes

Before any serious benchmark session, a handful of low-effort changes compound:

- Close the browser, IDE, and Slack to cut CPU and memory contention from the most expensive background processes.
- On macOS, disable Spotlight indexing with `sudo mdutil -a -i off` to stop the indexer spiking mid-run — undo with `sudo mdutil -a -i on`.
- Enable airplane mode to eliminate NIC interrupt coalescing and background network traffic.
- For IO-sensitive benchmarks, run once as a throwaway to warm the page cache before capturing.
- For cold-start IO benchmarks, drop the page cache with `sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'` before each run (Linux only, requires root).

None of these require root on macOS — on a noisy machine, closing the browser alone can shift CV from 5% to 3% before you touch anything else.

---

### Decision Table

What to use, where:

| Technique | Platform | Setup cost | What it buys | Recommended |
|---|---|---|---|---|
| `-count=10+`, `benchstat` A/B | All | None | More data, meaningful comparison | Always |
| `benchdiff` | All | One-time install | Automates git A/B loop | Strongly |
| Close apps + airplane mode | All | None | Lower baseline contention | Always |
| Docker `--cpuset-cpus` | Linux: full isolation / macOS: VM ceiling | Low | Medium on Linux; marginal but real on Mac | Linux yes; Mac conditionally |
| `taskset -c` | Linux only | None | Stops scheduler migration | Yes (Linux) |
| `perflock` | Linux only (effective) | One-time install | Pins CPU frequency | Yes (Linux) |
| `nice -n -5` | Linux | None | Raises scheduling priority | Yes (Linux) |
| DFS / Turbo Boost disable | Linux sysfs | Low (root) | Eliminates frequency variance | Dedicated machine |
| `cset shield` | Linux | Medium (root) | Very high isolation | Dedicated machine / CI |
| SMT disable | Linux sysfs | Low (root) | ~100× variance reduction | CI / dedicated only |

The practical macOS workflow: run `-count=20 -benchtime=2s`, watch the `±` column in `benchstat`, and treat any CV above 5% as a signal to fix the environment before acting on the result. When results need to hold up, run them on Linux.

---

### Up Next

Once local measurements are honest, the question becomes whether CI can run them reliably enough to catch regressions automatically — without generating false positives on every commit. That is the subject of [the next post, on CI and continuous benchmarking](/posts/go-benchmarks-lying-ci/).

The full series comes out of [Why Your Go Benchmarks Are Lying (And How to Stop Them)](https://gophercon.co.uk/), a talk at GopherCon UK 2026.

---

### Resources

- [Experiment scripts and committed results](https://github.com/kakkoyun/gopherconuk-26/tree/main/talks/go-benchmarks-lying/demo) — `make bench-docker` reruns all three conditions; `make cv` recomputes the table
- [FOSDEM 2026: Measuring Software Performance](/posts/fosdem-2026-measuring-software-performance/) — the prerequisite "why" post, including SMT and DFS experiments with raw tables
- [Why Your Go Benchmarks Are Lying, post 2: Statistics](/posts/go-benchmarks-lying-statistics/) — CV defined, `benchstat` explained
- [FOSDEM 2026 experiment repository](https://github.com/igoragoli/fosdem-2026-software-performance) — source for the 0.05% bare-metal CV figure and SMT/DFS tables
- [`perflock`](https://github.com/aclements/perflock) — CPU frequency locking for Go benchmarks, by Austin Clements (Go runtime team)
- [`benchdiff`](https://github.com/willabides/benchdiff) — automated git-ref A/B benchmarking piped to `benchstat`
- [Docker resource constraints documentation](https://docs.docker.com/engine/containers/resource_constraints/) — `--cpuset-cpus`, `--cpus`, `--memory` flags
- Bakhvalov, D. — [Performance Analysis and Tuning on Modern CPUs](https://github.com/dendibakh/perf-book)
