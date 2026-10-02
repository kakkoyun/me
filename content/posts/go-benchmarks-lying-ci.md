---
title: "Benchmark CI That Doesn't Lie"
description: "Shared CI runners introduce variance that swamps real signals. This post covers why, and how to build a two-tier benchmark CI: a fast PR gate plus a nightly pinned suite, with GitHub Actions, golang.org/x/perf, and a concrete tool recommendation."
date: 2026-09-18T00:00:00Z
publishDate: 2026-09-18T00:00:00Z
draft: true
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

### The Machine That Changes Its Mind

Imagine deploying a benchmark gate on every PR: if performance regresses, the check fails. After a week, you notice something strange. A PR that clearly does nothing performance-sensitive fails the gate. Another PR — one that rewrites a hot path — sails through with a green check.

You are not imagining it. Both outcomes are correct given the data — the data is just wrong.

Shared CI runners are multi-tenant machines. Your benchmark job runs on a physical host that also runs other teams' compile jobs, Docker builds, and test suites. The effective CPU speed, available cache, and memory bandwidth change with every run. A real 10% regression can vanish into that noise. A phantom 10% regression can appear from nowhere. The gate is not measuring your code — it is measuring the lottery of what else happens to be running next door.

Better statistical tests cannot compensate for an unstable measurement environment. Changing the environment is the only fix that works.

This is post four in the [Why Your Go Benchmarks Are Lying](/series/why-your-go-benchmarks-are-lying/) series. [Post three](/posts/go-benchmarks-lying-local-reproduction/) covered local environment control — the discipline that makes individual runs trustworthy. This post covers how that discipline escalates to CI, and what infrastructure it requires to work there. [Post five](/posts/go-benchmarks-lying-three-questions/) closes the series with a synthesis.

The prerequisite for everything here is [the FOSDEM post](/posts/fosdem-2026-measuring-software-performance/), which covers environment control at a language-agnostic level and contains the original SMT and DFS measurement data. Rather than repeat those experiments, this post references their results and applies them to the CI context.

The series concludes with the talk this work was prepared for: **"Why Your Go Benchmarks Are Lying (And How to Stop Them)"**, GopherCon UK 2026.

---

### Why Shared Runners Lie

Three mechanisms compound on shared CI infrastructure.

**Competing workloads.** On a multi-tenant host, a neighboring tenant's CPU-bound job contends with yours for shared execution units, memory bandwidth, and last-level cache (LLC). LLC is physically partitioned across cores on the same die; a tenant running on a sibling core pollutes your cache. Your benchmark sees a different effective memory bandwidth each run.

**Variable CPU frequency.** Dynamic frequency scaling (DFS, or Turbo Boost on Intel) adjusts the CPU clock based on thermal load and power headroom. A shared VM cannot disable this at the hypervisor level. A benchmark that ran at 3.5 GHz in one CI run may run at 3.1 GHz the next, not because your code changed but because a neighboring workload raised the thermal floor.

**Hypervisor scheduling.** Even without tenant competition, VM scheduling introduces jitter. The hypervisor can pause your vCPU to serve another tenant's interrupt. From inside the guest, this looks like your benchmark stalled.

The FOSDEM experiments on a dedicated AWS `m5.metal` instance quantify what controlling these variables actually achieves. With {{< tooltip term="SMT" >}}Simultaneous Multithreading, also marketed as Hyper-Threading on Intel. Two hardware threads share one physical core's execution resources.{{< /tooltip >}} enabled, a CPU-bound benchmark showed a coefficient of variation around 23%:

| Configuration | Mean | CV |
|---|---|---|
| SMT enabled, task 1 | 1537.64 ± 367.29 ms | 23.887% |
| SMT enabled, task 2 | 1536.88 ± 366.84 ms | 23.869% |
| SMT disabled, task 1 | 737.37 ± 0.32 ms | 0.044% |
| SMT disabled, task 2 | 737.93 ± 1.74 ms | 0.235% |

Disabling SMT reduces CV by roughly a hundredfold. The tasks also run faster because they are no longer fighting over shared execution units on the same core.

The DFS data, collected on the same machine with SMT already disabled:

| Configuration | Mean | CV |
|---|---|---|
| DFS on, 1 task | 533.97 ± 2.046 ms | 0.383% |
| DFS off, 1 task | 738.18 ± 0.306 ms | 0.041% |

Disabling dynamic frequency scaling reduces CV by roughly tenfold. Absolute runtime increases — the CPU runs at base frequency rather than boosting — but the measurement is stable.

For comparison, post three showed that a pinned container on a macOS developer machine bottoms out near 5.25% CV. That is the gap between "isolated from my other processes" and "actually controlled hardware." A 5% CV means a 5% real regression sits inside the noise floor. You cannot detect it. On a bare-metal machine with SMT and DFS disabled, the noise floor drops below 0.25% — well below any regression worth caring about.

---

### Two Patterns That Actually Work

No single benchmark job serves both the developer feedback loop and the historical trend record — they have opposing requirements. A PR gate needs to finish in minutes; thorough statistics require many samples over a stable environment. A nightly suite can run for an hour on controlled hardware; requiring that infrastructure on every PR is impractical for most teams.

Two distinct jobs serve these requirements without compromising either.

#### Pattern A: PR Gate

Runs on every pull request. Goal: catch unambiguous regressions before they merge.

- Target five minutes or less on a pinned runner
- Run a curated subset: benchmarks that have regressed before, or benchmarks directly exercised by the PR
- Use `-count=6 -benchtime=2s` as a floor — enough for `benchstat` to compute a meaningful confidence interval
- Compare against a stored baseline from `main`, maintained as a GitHub Actions cache (not an artifact — artifacts don't carry over between separate workflow runs)
- Block only when `benchstat` shows a delta whose confidence interval excludes zero with p < 0.05

{{< sidenote side="alternate" label="threshold" >}}A raw percentage threshold ("block if >5% slower") is dangerous in both directions. It blocks a 5.1% improvement and passes a 4.9% regression. Pairing the threshold with `benchstat`'s confidence interval avoids both: a result of "+8% ±12%" at p=0.3 should not block; "+8% ±2%" at p=0.001 should.{{< /sidenote >}}

#### Pattern B: Nightly Full Suite

Runs on a schedule against dedicated bare-metal hardware. Goal: historical trend tracking and catching slow regressions that accumulate across many PRs.

- `-count=20 -benchtime=5s` — enough samples for robust statistics
- Full environment controls applied at the runner level (below)
- Results stored with `benchsave`; compared against a rolling 30-day window
- Change-point detection to flag regressions automatically (see tool recommendations)
- Alert on Slack or email; do not block PRs from nightly data

The nightly suite is where gradual regressions become visible. A change that costs 1% per PR, landing five times over a sprint, won't trip a per-PR gate. Change-point detection on the time series will.

---

### Environment Controls at the Runner Level

These controls require bare-metal access. They cannot be applied from inside a shared VM: writing to sysfs in a VM guest may succeed without error but be silently ignored by the hypervisor.

**Disable SMT:**

```bash
echo off > /sys/devices/system/cpu/smt/control
```

**Pin CPU frequency and disable Turbo Boost:**

```bash
echo performance > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
# AMD:
echo 0 > /sys/devices/system/cpu/cpufreq/boost
```

**Pin to a single core:**

```bash
taskset -c 0 go test -bench=. -count=20 -benchtime=5s ./...
```

These three steps eliminate the three major sources of benchmark variance on a controlled machine.

---

### Bare Metal vs VM

The controls above are only meaningful on a machine where they are physically real. In a VM:

- The hypervisor manages SMT scheduling; the guest cannot disable it
- `cpufreq` sysfs in a guest writes to a virtual interface that has no effect on the physical CPU clock
- `echo off > /sys/devices/system/cpu/smt/control` may return success and do nothing

Options for dedicated bare-metal CI:

- **AWS EC2 bare-metal instances** (`m5.metal`, `m7i.metal`) — dedicated physical host with no hypervisor layer. On-demand pricing runs roughly $4-5/hour.
- **Hetzner dedicated servers** — cost-effective self-hosted bare metal, full root access.
- **On-premise physical machines** — zero cloud cost per run; the typical choice for teams running nightly benchmarks over years.

For most teams, a single persistent bare-metal machine beats cloud instances on cost when the nightly suite runs for more than an hour. An `m5.metal` running two hours nightly costs around $300/month. A used server covers itself in the first few months.

---

### GitHub Actions Wiring

The nightly workflow below registers a self-hosted bare-metal runner and applies the environment controls before running the benchmarks. The critical detail is `runs-on: [self-hosted, bare-metal, linux, x86_64]` — this label combination routes only to registered bare-metal runners. Using `ubuntu-latest` here would silently route to shared VMs and defeat the entire exercise.

```yaml
# .github/workflows/benchmark-nightly.yml
name: Nightly Benchmarks
on:
  schedule:
    - cron: '0 2 * * *'  # 2am UTC

jobs:
  benchmark:
    runs-on: [self-hosted, bare-metal, linux, x86_64]
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod

      - name: Restore baseline cache
        uses: actions/cache/restore@v4
        with:
          path: bench-baseline.txt
          key: bench-baseline-${{ github.run_id }}
          restore-keys: |
            bench-baseline-

      - name: Apply environment controls
        run: |
          sudo sh -c 'echo off > /sys/devices/system/cpu/smt/control'
          sudo sh -c 'echo performance > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
          sudo sh -c 'echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo'

      - name: Run benchmarks
        run: |
          taskset -c 0 go test \
            -bench=. -benchmem \
            -count=20 -benchtime=5s \
            ./... | tee bench-new.txt

      - name: Compare with baseline
        run: |
          if [ -f bench-baseline.txt ]; then
            go run golang.org/x/perf/cmd/benchstat@latest \
              bench-baseline.txt bench-new.txt
          else
            echo "No cached baseline yet — this run establishes one."
          fi

      - name: Promote new baseline
        run: cp bench-new.txt bench-baseline.txt

      - name: Save baseline cache
        if: always()
        uses: actions/cache/save@v4
        with:
          path: bench-baseline.txt
          key: bench-baseline-${{ github.run_id }}
```

For the PR gate, the same structure applies with two changes: swap `runs-on` to a dedicated (but lighter) pinned runner, drop the count and benchtime to fit the time budget, and run only the curated benchmark subset.

---

### The golang.org/x/perf Toolchain

The Go team's official performance measurement toolchain. All tools work with the standard `go test -bench` output format, without adapters or code changes.

**`benchstat`** computes median, bootstrap confidence intervals, and a statistical significance test across two result sets. It is the primary tool for A/B comparisons — local during development and in CI to interpret results:

```bash
go install golang.org/x/perf/cmd/benchstat@latest
benchstat bench-baseline.txt bench-new.txt
```

**`benchsave`** uploads results to a `perfdata` server for historical storage — the Go team uses this internally at `perf.golang.org`. For teams running their own storage, it provides a consistent format for time-series tracking:

```bash
go install golang.org/x/perf/cmd/benchsave@latest
benchsave -header "key=value" bench-new.txt
```

**`benchfmt`** and **`benchfilter`** handle parsing and filtering benchmark output, useful for extracting subsets for the curated PR gate.

`benchstat` is a point-in-time comparison tool. It tells you whether `bench-new.txt` differs from `bench-baseline.txt`, but it does not maintain a time series or alert on drift. For continuous monitoring, you need a tool that builds on `benchstat`'s output — covered in the next section.

---

### What Carries Over from Local

The local discipline from post three and the CI discipline here share more than they differ:

| Technique | Local | CI |
|---|---|---|
| `go test -bench -benchmem -count=N` | identical | identical |
| `benchstat` for A/B comparison | yes | yes |
| `benchdiff` for git-ref comparison | yes | yes (with checkout) |
| `perflock` for CPU frequency | Linux | bare-metal CI |
| SMT disable | Linux (sysfs) | bare-metal CI only |
| DFS/Turbo disable | Linux (sysfs) | bare-metal CI only |
| CPU affinity (`taskset`) | Linux | bare-metal CI |
| Historical trend tracking | no | yes (benchsave + storage) |
| PR gate enforcement | no | yes (GitHub Actions) |
| Cross-PR comparison | no | yes |

The local workflow establishes confidence in a single change. CI provides the historical baseline, the automated gate, and the cross-PR comparison that no human maintains manually. The tools are the same — only the runner environment and the storage layer differ.

---

### Tool Survey and a Recommendation

Several tools tackle continuous Go benchmarking — they differ in statistical model, hosting model, and how much infrastructure they require.

| Tool | Go native | Hosting | Statistics | PR gate | Maintained |
|---|---|---|---|---|---|
| **bencher.dev** | Yes | Both | t-test, z-score, IQR, log-normal, percentage | First-class | Yes |
| **github-action-benchmark** | Yes | GitHub Pages | Percentage threshold | Yes | Yes (v1.22.1, May 2026) |
| **gobenchdata** | Yes | GitHub Pages | User-defined expression | Yes | Maintenance-mode (Jan 2023) |
| **cob** | Yes | None (ephemeral) | Percentage threshold | Via exit code | Borderline (Oct 2023) |
| **chronologer** | No — uses hyperfine, not `go test` | None (local HTML) | None | No | Minimal |
| **Nyrkiö / Apache Otava** | Yes | Both | E-divisive change-point detection | Yes | Yes (Nyrkiö 2.0.0, Feb 2026) |
| **codespeed** | No — custom uploader required | Self-hosted (Django) | Visualization only | No | Unmaintained (Feb 2019) |
| **golang.org/x/perf benchstat** | Yes (official) | perf.golang.org (Go team only) | Median + bootstrap CI, significance test | None built-in | Yes |

A few entries deserve explicit warning labels.

**codespeed** has been unmaintained since 2019. Do not adopt it for a new project.

**chronologer** is not a Go benchmark tool. It uses [hyperfine](https://github.com/sharkdp/hyperfine) to time arbitrary shell commands across git history. It does not parse `go test -bench` output. The name is plausible but the tool is unrelated to Go benchmarking.

**cob** has a subtle footgun: it internally runs `git reset`. All changes must be committed before running it. This makes it unsuitable for pre-commit hooks or any CI step where the working tree might be dirty.

**The recommendation:**

*Small OSS project on GitHub:* use `benchmark-action/github-action-benchmark`. It requires no external accounts, stores results on GitHub Pages, and is actively maintained. The default 200% threshold is too loose to be useful — tighten it to 10-20% and add a manual `benchstat` comparison step alongside it for statistical honesty. Accept that the threshold test has no concept of significance; compensate by running with `-count=10` to reduce per-run variance.

*Team with a dedicated CI runner:* use **bencher.dev self-hosted**. The self-hosted binary is free — equivalent to the cloud Free tier — and running it on a noise-controlled machine removes the biggest source of CI benchmark noise. Configure the `t_test` threshold model — it handles small sample sizes correctly and gives a principled false-positive rate. Wire `--error-on-alert` to block PRs. The `go_bench` adapter requires no changes to your benchmark code.

*Large org wanting change-point detection:* use **Nyrkiö with Apache Otava** as the detection backend. The [e-divisive algorithm](https://arxiv.org/abs/2003.00584) finds persistent shifts in a full time series rather than comparing each run against a rolling window — it adapts to each benchmark's individual noise floor automatically. The Apache Otava incubation (November 2024) provides long-term governance. Nyrkiö 2.0.0 (February 2026) added GitHub Runners for reproducible benchmarking. For teams requiring fully on-premises operation, Apache Otava can run directly against a self-hosted time-series store; Nyrkiö is the hosted integration layer on top.

In every scenario: use `golang.org/x/perf/cmd/benchstat` for local development comparisons and in PR descriptions. It is the only tool in this list that gives you a confidence interval and a p-value on the comparison — the ground truth for whether a change is real.

---

### What Comes Next

Once CI is in place and producing honest signals, the remaining question is interpretive: given a regression alert, how do you decide whether it matters enough to address? That framing — three questions to ask before acting on a benchmark result — is what [post five](/posts/go-benchmarks-lying-three-questions/) covers.

---

### Resources

- [FOSDEM 2026: Measuring Software Performance](/posts/fosdem-2026-measuring-software-performance/): the environment control experiments this post references
- [Post 3: Local Reproduction](/posts/go-benchmarks-lying-local-reproduction/): the local discipline that CI builds on
- [FOSDEM 2026 experiments and slides](https://github.com/igoragoli/fosdem-2026-software-performance): raw data and methodology
- [golang.org/x/perf](https://pkg.go.dev/golang.org/x/perf): benchstat, benchsave, benchfmt
- [benchmark-action/github-action-benchmark](https://github.com/benchmark-action/github-action-benchmark): GitHub Actions integration
- [bencher.dev](https://bencher.dev): continuous benchmarking with statistical models
- [Nyrkiö change-detection action](https://github.com/nyrkio/change-detection): e-divisive change-point detection for CI
- [Apache Otava](https://otava.apache.org/): the algorithm library behind Nyrkiö
- [MongoDB: Reducing Variability in EC2 Performance Tests](https://www.mongodb.com/company/blog/engineering/reducing-variability-performance-tests-ec2-setup-key-results): practical documentation of bare-metal vs VM variance
- Bakhvalov, D., [Performance Analysis and Tuning on Modern CPUs](https://github.com/dendibakh/perf-book): CPU-level tuning reference
