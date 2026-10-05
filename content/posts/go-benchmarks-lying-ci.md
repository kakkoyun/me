---
title: "Benchmark CI That Doesn't Lie"
description: "Shared CI runners add noise that swamps real regressions. Build a two-tier benchmark CI: a fast PR gate plus a nightly suite on bare metal."
date: 2026-07-28T00:00:00Z
publishDate: 2026-07-28T00:00:00Z
promote: false
categories:
  - engineering
tags:
  - blog
  - go
  - performance
  - benchmarking
  - ci
series:
  - Why Your Go Benchmarks Are Lying
showToc: true
tocOpen: false
---

Say we put a benchmark gate on every pull request: if performance regresses, the check fails. After a week, something strange shows up. A PR that does nothing performance-sensitive fails the gate. Another PR, one that rewrites a hot path, sails through with a green check.

Nobody is imagining it. Both outcomes are correct given the data, and the data is just wrong. A shared CI runner is a multi-tenant machine, so our benchmark lands on a host that also runs other teams' compile jobs, Docker builds and test suites. A real 10% regression can vanish into that noise, and a phantom one can appear from nowhere. The gate isn't measuring our code. It's measuring the lottery of what happens to be running next door. 🎰

I'll call this the machine that changes its mind, and it will keep turning up as we go. Better statistics can't compensate for an unstable environment, so we'll change the environment.

This is part 4 of 5 in the [Why Your Go Benchmarks Are Lying](/series/why-your-go-benchmarks-are-lying/) series, the written companion to the [GopherCon UK 2026 talk](/talks/why-your-go-benchmarks-are-lying/). [Part 3](/posts/go-benchmarks-lying-local-reproduction/) kept one machine honest. Here we answer the series' third question, whether the difference is large relative to the noise, once the machine isn't ours. We'll start with a number from FOSDEM, two CPU-bound tasks sharing a core with a coefficient of variation around 23%, to see what shared runners do to a measurement. Then we'll split the gate into a fast PR check and a slow nightly suite, wire the nightly one into GitHub Actions on bare metal, and pick a tool for the history. [Part 5](/posts/go-benchmarks-lying-three-questions/) closes the series with a checklist.

The prerequisite is [the FOSDEM post](/posts/fosdem-2026-measuring-software-performance/), which covers environment control in language-agnostic terms. Its experiments ran on a dedicated AWS `m5.metal` instance, with slides and results in [`igoragoli/fosdem-2026-software-performance`](https://github.com/igoragoli/fosdem-2026-software-performance/tree/2cea1c2a854119f48d124daf2a8157480cd4450a), and we reuse those numbers here. What exactly makes a shared machine change its mind?

## Why shared runners lie

Three mechanisms compound. Another tenant's CPU-bound job contends with ours for memory bandwidth and last-level cache (LLC), which is shared across the cores of a die, and for execution units if it lands on a sibling hardware thread. Dynamic frequency scaling (DFS, or Turbo Boost on Intel) adjusts the CPU clock based on thermal load and power headroom, and a shared VM cannot disable it from inside the guest, so a benchmark that ran at 3.5 GHz in one CI run may run at 3.1 GHz the next because a neighbouring workload raised the thermal floor.

Then there's the hypervisor. Even without tenant competition, it can pause our vCPU to serve another tenant's interrupt, and from inside the guest that looks like our benchmark stalled.

The FOSDEM experiments put numbers on what controlling these variables buys. Start with {{< tooltip term="SMT" >}}Simultaneous Multithreading, also marketed as Hyper-Threading on Intel. Two hardware threads share one physical core's execution resources.{{< /tooltip >}}. With it enabled, two CPU-bound tasks sharing a core (DFS off) showed a coefficient of variation (CV, the standard deviation as a share of the mean) around 23%. With it disabled, the same two tasks ran on separate cores:

| Configuration | Mean | CV |
|---|---|---|
| SMT enabled, task 1 | 1537.64 ± 367.29 ms | 23.887% |
| SMT enabled, task 2 | 1536.88 ± 366.84 ms | 23.869% |
| SMT disabled, task 1 | 737.37 ± 0.32 ms | 0.044% |
| SMT disabled, task 2 | 737.93 ± 1.74 ms | 0.235% |

Turning SMT off cut CV by roughly a hundredfold, and the tasks ran faster too, because they stopped fighting over one core's execution units. Next the clock. With SMT already disabled on the same machine, the [slides](https://github.com/igoragoli/fosdem-2026-software-performance/blob/2cea1c2a854119f48d124daf2a8157480cd4450a/presentation.md) show DFS on and off for a single task:

| Configuration | Mean | CV |
|---|---|---|
| DFS on, 1 task | 533.97 ± 2.046 ms | 0.383% |
| DFS off, 1 task | 738.18 ± 0.306 ms | 0.041% |

The DFS-off row is the SMT-disabled configuration again (SMT and DFS off), hence the same ~738 ms. Turning DFS off cut CV roughly tenfold. Absolute runtime goes up, because the CPU runs at base frequency instead of boosting, but the measurement is stable: slow and steady beats fast and moody.

How do those numbers compare with a setup we might already have? [Part 3](/posts/go-benchmarks-lying-local-reproduction/) showed that a pinned container on a macOS developer machine bottoms out near 5.25% CV. A 5% CV puts a 5% real regression inside the noise floor of any single run, and resolving it takes more samples than a PR gate can afford. On bare metal with SMT and DFS disabled, the FOSDEM runs drop below 0.25%, well below any regression worth caring about.

The machine can be tamed, then, but only if we own the whole box. What we run on it comes next, because a PR gate and a nightly history want opposite things.

## Two patterns that actually work

A PR gate needs to finish in minutes, while thorough statistics need many samples over a stable environment. A nightly suite can run for an hour on controlled hardware, but most teams can't require that hardware on every PR. No single job serves both, so we build two.

### Pattern A: PR gate

The gate runs on every pull request and catches unambiguous regressions before they merge. It targets five minutes or less on a pinned runner, running a curated subset: benchmarks that have regressed before, or that the PR directly exercises. I'd start with `-count=6 -benchtime=2s`, the lowest count that works, because [`benchstat`](https://pkg.go.dev/golang.org/x/perf@v0.0.0-20260929162123-406019bb8b68/cmd/benchstat) needs six samples to print a 95% confidence interval at all, and its docs recommend at least ten. The baseline comes from `main`, kept in a GitHub Actions cache rather than an artifact, which by default is only visible to the run that produced it. The gate blocks only when `benchstat` reports a delta instead of `~` (p < 0.05) and that delta is larger than a floor we choose.

Two caveats. `benchstat` exits 0 whatever it finds, so a step must read its `vs base` column and fail the job on a significant delta. A cached baseline was also measured earlier, maybe elsewhere: [data taken far apart in time, even on the same hardware, can result in a lot of noise](https://go.dev/wiki/PerformanceMonitoring), says the Go wiki, so building base and head in one job and interleaving them is stronger; [A PR gate that actually fails](/posts/go-benchmarks-pr-gate-that-fails/) shows that job catching a slow commit. On GitHub-hosted runners the gate is weaker, not worthless: a smoke alarm, as [part 5](/posts/go-benchmarks-lying-three-questions/) says, not the judge.

{{< sidenote side="alternate" label="threshold" >}}A raw percentage threshold ("block on a >5% change") is dangerous in both directions: it blocks a 5.1% improvement and passes a 4.9% regression. With `benchstat`'s significance test alongside it, `~ (p=0.3)` should not block and `+8.00% (p=0.001 n=6)` should.{{< /sidenote >}}

### Pattern B: nightly full suite

The nightly suite runs on a schedule against dedicated bare-metal hardware, and it watches for the slow regressions that accumulate across many PRs. It can afford `-count=20 -benchtime=5s`, with the full environment controls applied at the runner level. Results go into our own time-series store (Bencher or Nyrkiö, for example, from the survey below), compared against a rolling 30-day window, with change-point detection flagging regressions. Alerts go to Slack or email, and nightly data never blocks a PR.

A change that costs 1% per PR, landing five times over a sprint, won't trip a per-PR gate, but change-point detection on the time series can; [A/B is the wrong model for CI](/posts/go-benchmarks-ab-is-the-wrong-model/) builds a small detector to show it. The nightly suite is only as trustworthy as the box under it, though, so let's see what that box needs.

## Bare metal versus VM

The controls are the ones from [part 3](/posts/go-benchmarks-lying-local-reproduction/#the-linux-toolbox): SMT off, the performance governor with turbo off, and `taskset`. Together they remove the three largest sources of benchmark variance, but only where they are physically real. Inside a shared VM the hypervisor manages SMT, so the guest cannot disable it, and frequency controls in a guest, where they exist at all, do not change the physical CPU clock. And `echo off > /sys/devices/system/cpu/smt/control` may succeed (it offlines the guest's own sibling vCPUs) without changing how the hypervisor schedules them. A control that succeeds and changes nothing is the worst kind: it makes us feel better and measures the same.

Where do we find a machine with real controls? AWS EC2 bare-metal instances (`m5.metal`, `m7i.metal-24xl`) are dedicated physical hosts with no hypervisor layer, at roughly $4-5/hour on demand for Linux in us-east-1. Hetzner rents dedicated servers with full root access. Past an hour or so of nightly runtime, one persistent bare-metal machine is likely to beat cloud instances on cost: an `m5.metal` running two hours nightly costs around $280/month, so a dedicated server, rented or owned, can pay for itself within months.

Suppose we have the box. How do we point a workflow at it, and only at it?

## GitHub Actions wiring

The nightly workflow below runs on a self-hosted bare-metal runner and applies the controls before the benchmarks. The critical detail is `runs-on: [self-hosted, linux, x64, bare-metal]`. GitHub adds `self-hosted`, `linux` and `x64` when we register the runner; `bare-metal` is a custom label we add, and the combination routes only to those runners. Writing `ubuntu-latest` here would silently route to shared VMs and defeat the entire exercise, which is a lot of YAML to end up exactly where we started.

```yaml
# .github/workflows/benchmark-nightly.yml
name: Nightly Benchmarks
on:
  schedule:
    - cron: '0 2 * * *'  # 2am UTC

jobs:
  benchmark:
    runs-on: [self-hosted, linux, x64, bare-metal]
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0

      - uses: actions/setup-go@v7
        with:
          go-version-file: go.mod

      - name: Restore baseline cache
        uses: actions/cache/restore@v6
        with:
          path: bench-baseline.txt
          key: bench-baseline-${{ github.run_id }}
          restore-keys: |
            bench-baseline-

      - name: Apply environment controls
        run: |
          echo off | sudo tee /sys/devices/system/cpu/smt/control >/dev/null
          echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
          echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null

      - name: Run benchmarks
        shell: bash  # runs with pipefail, so a failing go test fails the step
        run: |
          taskset -c 0 go test \
            -bench=. -benchmem \
            -count=20 -benchtime=5s \
            ./... | tee bench-new.txt

      - name: Compare with baseline
        run: |
          if [ -f bench-baseline.txt ]; then
            go run golang.org/x/perf/cmd/benchstat@v0.0.0-20260929162123-406019bb8b68 \
              bench-baseline.txt bench-new.txt
          else
            echo "No cached baseline yet. This run establishes one."
          fi

      - name: Promote new baseline
        run: cp bench-new.txt bench-baseline.txt

      - name: Save baseline cache
        if: always()
        uses: actions/cache/save@v6
        with:
          path: bench-baseline.txt
          key: bench-baseline-${{ github.run_id }}
```

Top to bottom, it restores last night's baseline, applies the sysfs controls, pins the run to CPU 0, compares with `benchstat`, then promotes tonight's results as the new baseline. `taskset -c 0` makes `GOMAXPROCS` 1, so it suits single-threaded benchmarks; parallel ones need a wider CPU set. It never undoes the controls, fine for a box that only runs benchmarks; on a shared machine, add an `if: always()` step that writes `on` to the SMT control. It only prints the comparison. The time-series store and the alerting come from the tools in the survey below.

The PR gate uses the same structure with a dedicated (but lighter) pinned runner in `runs-on`, a lower count and benchtime to fit the time budget, and only the curated benchmark subset. One warning before copying any of this: GitHub advises that [self-hosted runners should almost never be used for public repositories](https://docs.github.com/en/actions/reference/security/secure-use), because anyone who can open a pull request can run code on them, and this workflow uses `sudo`. On a private repository, put the gate behind an environment with required reviewers.

The workflow leans on `benchstat` and promises a time series it doesn't keep. Where do those come from? The Go team ships the first one.

## The golang.org/x/perf toolchain

[`golang.org/x/perf`](https://pkg.go.dev/golang.org/x/perf@v0.0.0-20260929162123-406019bb8b68) is the Go team's official performance measurement toolchain, and its tools read the standard `go test -bench` output with no adapters or code changes. `benchstat` is the one we've been leaning on. It computes the median, a non-parametric confidence interval for the median, and a Mann-Whitney U-test across two result sets. It prints `~` when the difference is indistinguishable from noise, and otherwise a delta with its p-value and sample count. That makes it the primary tool for A/B comparisons, locally and in CI:

```bash
go install golang.org/x/perf/cmd/benchstat@v0.0.0-20260929162123-406019bb8b68
benchstat bench-baseline.txt bench-new.txt
```

The version pin matches the one in the workflow, and the old results go first, so the delta reads as the new run against the baseline. The `benchsave` sibling uploads results to a `perfdata` server, but its default one is the Go project's, behind an interactive Google sign-in that publicly records your email address. Unattended CI needs its own store.

`benchstat` is a point-in-time comparison. It keeps no time series and alerts on no drift. The tools from part 3 carry over; the controls need bare metal. What CI adds is the historical baseline, the automated gate and the cross-PR comparison that no human maintains by hand. The storage layer is what's left to choose, and the field is crowded.

## Tool survey and a recommendation

The tools that tackle continuous Go benchmarking differ in statistical model, hosting model, and how much infrastructure they need. Here is the field as of the talk (12 August 2026):

| Tool | Go native | Hosting | Statistics | PR gate | Maintained |
|---|---|---|---|---|---|
| **[bencher.dev](https://bencher.dev)** | Yes | Both | t-test, z-score, IQR, log-normal, percentage | First-class | Yes |
| **[`github-action-benchmark`](https://github.com/benchmark-action/github-action-benchmark/tree/v1.22.1)** | Yes | GitHub Pages | Percentage threshold | Yes | Yes (v1.22.1, May 2026) |
| **gobenchdata** | Yes | GitHub Pages | User-defined expression | Yes | Maintenance-mode (last release Jan 2023) |
| **cob** | Yes | None (ephemeral) | Percentage threshold | Via exit code | Borderline (Oct 2023) |
| **chronologer** | No, uses [hyperfine](https://github.com/sharkdp/hyperfine), not `go test` | None (local HTML) | None | No | Minimal |
| **[Nyrkiö](https://github.com/nyrkio/change-detection/tree/v2.0.2) / [Apache Otava](https://otava.apache.org/)** | Yes | Both | E-divisive change-point detection | Yes | Yes (Nyrkiö 2.0.0, Feb 2026) |
| **codespeed** (Django; not CodSpeed) | No, custom uploader required | Self-hosted (Django) | Visualization only | No | Unmaintained (last release Feb 2019) |
| **golang.org/x/perf benchstat** | Yes (official) | perf.golang.org (Go team only) | Median + CI, significance test | None built-in | Yes |

[CodSpeed](https://codspeed.io/docs/benchmarks/go) is not in the table: its Go integration is in early development and supports only wall-time measurement, not the CPU simulation it offers elsewhere. One of these deserves a warning label. **cob** has a subtle footgun: it internally runs `git reset`, so all changes must be committed before running it, which rules it out for pre-commit hooks or any CI step with a dirty working tree.

Which would I pick? That depends on who "we" are.

**Small OSS project on GitHub.** Use `benchmark-action/github-action-benchmark`. It needs no external accounts and stores results on GitHub Pages. The default 200% threshold is too loose to be useful. The `alert-threshold` input is a ratio of current to previous, so tighten it to `110%`-`120%` (a 10-20% slowdown) and add a `benchstat` step alongside it, because the action has no concept of significance. With `-count=10` the `benchstat` step gives honest numbers in the log, but the action treats each sample line as a separate result and does not average them.

**Team with a dedicated CI runner.** Use **bencher.dev self-hosted**, on a noise-controlled machine. Bencher's [pricing page](https://bencher.dev/pricing/) says you can run the self-hosted binary without a Bencher Plus license, at the feature level of the Cloud Free plan, so check it against your private-project needs. Configure the `t_test` threshold model; unlike `z_score`, its docs do not ask for 30 historical samples. Wire `--error-on-alert` to block PRs. The `go_bench` adapter needs no changes to your benchmark code, though it reports only the mean.

**Large org wanting change-point detection.** Use **Nyrkiö with Apache Otava** as the detection backend. The [e-divisive approach, as applied at MongoDB](https://arxiv.org/abs/2003.00584) finds persistent shifts across the series instead of comparing each run with a fixed baseline, and adapts to each benchmark's noise through its significance test. Apache Otava entered incubation in November 2024. Nyrkiö 2.0.0 (February 2026) added Nyrkiö Runners for GitHub, which its release notes describe as configured for stable, repeatable benchmark results. For fully on-premises operation, Apache Otava can run against a self-hosted time-series store.

In every scenario, keep `benchstat` for local comparisons and PR descriptions. Of the tools here, only `benchstat` gives a confidence interval and a p-value for a direct comparison of two sets of samples, so trust it when the question is whether a change is real. Which brings us back to the gate we started with.

## Back to the machine that changes its mind

Remember the gate that failed a harmless PR and waved a hot-path rewrite through? It faithfully reported a machine that kept changing its mind. With the setup we just built, the nightly suite runs on bare metal with SMT off, the performance governor set and turbo off, and the PR gate blocks only when `benchstat` says the delta is real and larger than a floor we chose. The lottery next door is out of the draw. 🎟️

Versions, links and commands checked on 2 October 2026.

## Up next

[Part 5, Three Questions Before You Trust a Benchmark](/posts/go-benchmarks-lying-three-questions/), closes the series: a CI regression that turned out to be a speedup, and a three-question checklist backed by three small CLIs. Even on perfect hardware, a benchmark can still lie to us. Part 5 shows how.
