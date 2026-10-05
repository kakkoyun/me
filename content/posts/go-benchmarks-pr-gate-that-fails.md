---
title: "A PR gate that actually fails"
description: "One slow commit, one workflow, two real GitHub Actions runs: how a Go PR gate turns a benchstat table into a red check, and what it can't promise."
date: 2026-07-31T00:00:00Z
publishDate: 2026-07-31T00:00:00Z
promote: false
categories:
  - engineering
tags:
  - blog
  - go
  - performance
  - benchmarking
  - ci
showToc: true
tocOpen: false
---

Part 4 ended with a promise: the PR gate blocks only when `benchstat` says the delta is real and bigger than a floor we chose. A fair reader question is how. `benchstat` prints a table, and I checked that it exits 0 even when the table says `+199.00%` (two made-up result files, the pinned version, Go 1.27.1). Who, then, turns that table into a red check?

We'll build that job together. We'll write one deliberately slow commit, let the job judge it, revert the commit, and let the job judge the revert. Two runs, two verdicts, both on a GitHub-hosted runner:

```text
Ints-4   2.579µ ± 1%   7.700µ ± 1%  +198.57% (p=0.000 n=10)
Ints-4   2.579µ ± 2%   2.576µ ± 1%  ~ (p=0.782 n=10)
```

The first line is the slow commit, and the second is its revert. This is a companion to the [Why Your Go Benchmarks Are Lying](/series/why-your-go-benchmarks-are-lying/) series, between [part 4](/posts/go-benchmarks-lying-ci/) and [part 5](/posts/go-benchmarks-lying-three-questions/), the written companion of my [GopherCon UK talk](/talks/why-your-go-benchmarks-are-lying/). GitHub deletes Actions logs after a retention period, so this post carries the key log lines itself. The `benchgate` tool is [`kakkoyun/benchlab` at v0.1.0](https://github.com/kakkoyun/benchlab/tree/v0.1.0), and the workflow and both runs live on [PR #5](https://github.com/kakkoyun/benchlab/pull/5), a closed demo.

## The slow commit

The patient is a small benchmark, `BenchmarkInts`, which sums a slice of integers. The slow commit routes every addition through a helper marked `//go:noinline`, so each `total = add(total, x)` becomes a real function call. I made it slow on purpose, and by a lot: roughly three times.

A PR against `main` has no benchmark on its base side, so the base binary couldn't even build. The demo PR targets a branch that already holds the workflow and the benchmark, and the diff under test is the slow commit alone. First run, slow commit. Second run, I push the revert to the same PR.

Now the judge. Where should it run, and against what?

## Why base and head share a job

Part 4 keeps the baseline from `main` in a cache, which suits a pinned runner. On a hosted runner, a cached baseline was measured on whatever VM ran the earlier job, and nothing promises that VM is the one judging your PR. This gate builds both binaries in one job and runs them on the same VM, taking turns: base, head, base, head. That interleaving (ABAB) spreads slow drift evenly over both sides. It does not remove noisy neighbours, and we'll come back to that.

Here is the whole workflow. Read the comments, then we'll walk through it step by step.

```yaml
# A PR gate that actually fails: companion to part 4 of the Go benchmarks series.
#
# One job builds the base and head benchmark binaries, runs them interleaved
# (ABAB), and fails on a regression that benchstat calls real. benchgate rules
# out an unstable sample first.
name: bench-gate

on:
  pull_request:

permissions:
  contents: read

env:
  BENCHSTAT_VERSION: v0.0.0-20260929162123-406019bb8b68
  BENCHGATE_VERSION: v0.1.0
  BENCH_PKG: ./internal/sum
  # ROUNDS is both the number of ABAB rounds and the sample count per side (n).
  ROUNDS: "10"
  BENCHTIME: 200ms
  # Block only when benchstat says the delta is real (p < 0.05) AND at least this large.
  MIN_DELTA_PCT: "5"
  # benchgate fails the sample when any benchmark's coefficient of variation is above this.
  CV_THRESHOLD: "10"

jobs:
  bench-gate:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      # pull_request checks out the merge commit, so HEAD^1 is the base tip and
      # HEAD is what would land. Depth 2 is enough to reach both.
      - uses: actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803 # v6
        with:
          fetch-depth: 2
          persist-credentials: false

      - uses: actions/setup-go@924ae3a1cded613372ab5595356fb5720e22ba16 # v6
        with:
          go-version: "1.27.1"
          cache: false

      - name: Install benchstat and benchgate
        run: |
          export GOBIN="$RUNNER_TEMP/bin"
          go install "golang.org/x/perf/cmd/benchstat@${BENCHSTAT_VERSION}"
          go install "github.com/kakkoyun/benchlab/cmd/benchgate@${BENCHGATE_VERSION}"

      - name: Build base and head benchmark binaries
        run: |
          if [ "$(git rev-list --parents -n 1 HEAD | wc -w)" -ne 3 ]; then
            echo "::error::HEAD is not a merge commit; expected the pull_request merge ref"
            exit 2
          fi
          mkdir -p "$RUNNER_TEMP/bench"
          git worktree add --detach "$RUNNER_TEMP/base" HEAD^1
          echo "base: $(git rev-parse --short HEAD^1)  head: $(git rev-parse --short HEAD)"
          go test -c -o "$RUNNER_TEMP/bench/head.test" "$BENCH_PKG"
          (cd "$RUNNER_TEMP/base" && go test -c -o "$RUNNER_TEMP/bench/base.test" "$BENCH_PKG")

      - name: Run base and head interleaved (ABAB)
        run: |
          pkgdir="${BENCH_PKG#./}"
          : > "$RUNNER_TEMP/bench/base.txt"
          : > "$RUNNER_TEMP/bench/head.txt"
          for round in $(seq 1 "$ROUNDS"); do
            for side in base head; do
              root="$RUNNER_TEMP/base"
              if [ "$side" = head ]; then root="$GITHUB_WORKSPACE"; fi
              echo "round $round: $side"
              (cd "$root/$pkgdir" && "$RUNNER_TEMP/bench/$side.test" \
                -test.run='^$' -test.bench=. -test.benchtime="$BENCHTIME" -test.count=1) \
                >> "$RUNNER_TEMP/bench/$side.txt"
            done
          done

      - name: Compare with benchstat
        run: |
          cd "$RUNNER_TEMP/bench"
          benchstat="$RUNNER_TEMP/bin/benchstat"
          "$benchstat" base.txt head.txt
          "$benchstat" -format csv base.txt head.txt > compare.csv
          # Rows are "name,base,CI,head,CI,delta,P". Gate on the sec/op table only; the delta
          # column holds "~" when benchstat sees noise, so only a signed percentage can match.
          awk -F, -v floor="$MIN_DELTA_PCT" '
            $1 == "" && NF > 1 { gate = ($2 == "sec/op"); next }
            gate && $1 != "geomean" && $4 != "" { compared++ }
            gate && $1 != "geomean" && $6 ~ /^\+[0-9.]+%$/ && substr($6, 2) + 0 >= floor {
              printf "%s %s (%s)\n", $1, $6, $7 > "regressions.txt"
            }
            END { print compared + 0 > "compared.count" }
          ' compare.csv
          touch regressions.txt

      - name: Check sample stability with benchgate
        run: |
          cd "$RUNNER_TEMP/bench"
          # Exit codes: 0 stable, 1 unstable (CV over threshold), 2 error. Record it
          # instead of failing here, so the verdict step can report everything at once.
          rc=0
          (cd "$GITHUB_WORKSPACE" && "$RUNNER_TEMP/bin/benchgate" \
            -pkg "$BENCH_PKG" -count "$ROUNDS" -benchtime "$BENCHTIME" \
            -cv-threshold "$CV_THRESHOLD") || rc=$?
          echo "$rc" > benchgate.rc

      - name: Gate verdict
        run: |
          cd "$RUNNER_TEMP/bench"
          compared="$(cat compared.count)"
          benchgate_rc="$(cat benchgate.rc)"
          # Exit codes: 0 pass, 1 regression, 2 tool error, 3 unstable sample.
          if [ "$compared" -eq 0 ]; then
            echo "::error title=Nothing compared::benchstat found no benchmark present in both base and head"
            exit 2
          fi
          status=0
          case "$benchgate_rc" in
            0) ;;
            1)
              echo "::error title=Unstable sample::benchgate exit 1: a benchmark's CV is above ${CV_THRESHOLD}%; the run cannot support a verdict"
              status=3
              ;;
            *)
              echo "::error title=benchgate failed::benchgate exit ${benchgate_rc}"
              exit 2
              ;;
          esac
          if [ -s regressions.txt ]; then
            while read -r line; do
              echo "::error title=Benchmark regression::${line}"
            done < regressions.txt
            status=1
          fi
          echo "verdict: exit ${status}"
          exit "$status"
```

## Walking through it

The `env` block holds every number we might argue about later. `ROUNDS` is both the number of ABAB rounds and the sample count per side, so `n=10`. `MIN_DELTA_PCT` and `CV_THRESHOLD` are the two thresholds: a regression floor and a noise ceiling.

The checkout step uses `fetch-depth: 2`. On `pull_request`, GitHub checks out a merge commit, so `HEAD^1` is the tip of the base branch and `HEAD` is what would land. Depth 2 reaches both. The build step refuses to continue if `HEAD` doesn't have two parents, and it prints both short hashes, which is how the logs told me the comparison was the right one (`base: 021b688  head: fb2ae9c` in run 1). It then runs `go test -c` once per side, so we have two frozen test binaries and no rebuild between rounds.

The ABAB loop runs each binary ten times with `-test.count=1`, appending to `base.txt` and `head.txt`. The flags are a budget. Ten samples per side is the floor the `benchstat` docs recommend, and 200 ms is plenty for a benchmark that takes a few microseconds, so the whole job took about 35 seconds. Part 4's nightly suite can afford `-count=20 -benchtime=5s` on controlled hardware, and this gate cannot afford that on every push.

The compare step is where the exit code gets made. It runs `benchstat` twice, once for the human-readable table and once with `-format csv`. The `awk` script reads rows shaped like `name,base,CI,head,CI,delta,P`, looks only at the `sec/op` table, and keeps a row only if its delta is a signed `+N%` with N at or above the floor. When `benchstat` sees noise, the delta column holds `~`, so noise can never match. A faster result starts with a minus and is ignored too. The gate counts compared rows and writes the survivors to `regressions.txt`.

Then `benchgate`. At tag v0.1.0, `-baseline` only [prints the `benchstat` output](https://github.com/kakkoyun/benchlab/blob/v0.1.0/cmd/benchgate/main.go#L146-L167) and the exit code never looks at it. The exit code answers a different question: is the sample stable enough to trust? It exits 1 when any benchmark's coefficient of variation is above the threshold. That makes `benchgate` the noise gate and `benchstat` the regression gate. Also, `benchgate` runs its own `go test` on the head tree, one after another, so it measures how noisy the runner was, not the interleaved samples. The `±` column in the `benchstat` table is the better noise indicator for the comparison itself.

Last, the verdict step folds everything into one exit code: 0 pass, 1 regression, 2 tool or setup error (nothing compared, `benchgate` failed, not a merge commit), 3 unstable sample. A regression wins over "unstable", and each finding becomes an `::error` annotation on the PR. Enough reading. Let's watch it judge.

## Run 1: the slow commit

[Run 1](https://github.com/kakkoyun/benchlab/actions/runs/37187167739) failed, and it failed in the right step. The `benchstat` step printed this (the log also names the CPU, an AMD EPYC 7763):

```text
       │  base.txt   │               head.txt               │
       │   sec/op    │   sec/op     vs base                 │
Ints-4   2.579µ ± 1%   7.700µ ± 1%  +198.57% (p=0.000 n=10)
```

Ints went from 2.579 µs to 7.700 µs, and the `±` columns are small. Then the stability check:

```text
benchgate: go test -bench=. -count=10 -benchtime=200ms ./internal/sum

  BenchmarkInts                                 mean=  7816.3 ns/op  cv=  3.1%  ✓

VERDICT: PASS — all 1 benchmarks within CV threshold 10.0%
```

A CV of 3.1% is under the 10% ceiling, so the sample was trusted. The verdict step did the rest:

```text
##[error]Ints-4 +198.57% (p=0.000 n=10)
verdict: exit 1
##[error]Process completed with exit code 1.
```

The `##[error]` line is the annotation from the awk output, and the last line is the red check. Was it a fluke? Let's judge the revert.

## Run 2: the revert

The revert makes the head tree identical to the base, so [run 2](https://github.com/kakkoyun/benchlab/actions/runs/37187216023) is a null test: there is nothing to find, and the gate should find nothing.

```text
       │  base.txt   │           head.txt            │
       │   sec/op    │   sec/op     vs base          │
Ints-4   2.579µ ± 2%   2.576µ ± 1%  ~ (p=0.782 n=10)
```

`~` means `benchstat` could not tell the sides apart, and `benchgate` reported `cv=  3.4%  ✓`. The verdict step closed with:

```text
verdict: exit 0
```

The gate went red for the slow commit and green for the revert, on the same kind of hosted runner, a minute apart.

## What this does not prove

Part 4's argument stands: `ubuntu-latest` is a shared machine, and I can't turn off SMT or frequency scaling from inside it. These runs don't show that the runner is quiet. They show that a 3x change is far outside whatever noise was there. I'd call a hosted gate weaker than one on bare metal, not worthless. It catches the obvious regressions, and it can't promise to catch a 5–10% one. With `n=10` on a shared runner, a change that small can flap: pass once, fail the next time. [A/B is the wrong model for CI](/posts/go-benchmarks-ab-is-the-wrong-model/) looks at what one pair per PR misses.

The CV numbers give a partial answer to a question readers asked, whether `-cv-threshold 5` always fails on hosted runners. In these two runs it would not have (3.1% and 3.4%). I set 10, and two runs are a sample of two. If a noisy run does trip the ceiling, the job fails closed with exit 3, a red check that is not a regression. I saw that path only on my laptop, where noise tripped it. I never saw exit 2 on GitHub.

The runs are also a single benchmark on one machine type, captured on 4 October 2026. If you adopt this, calibrate `BENCHTIME`, `ROUNDS` and the two thresholds on your own benchmarks first. The gate is only worth what that calibration says.

Versions, links and commands checked on 2 October 2026; the CI runs shown were captured on 4 October 2026.

## Try it

Copy the workflow into a repository with a benchmark package, point `BENCH_PKG` at it, and push a branch holding the workflow and the benchmark. Open a PR against that branch with a deliberately slow commit, watch the check go red, then push a revert and watch it go green. That is exactly what I did in the demo, and `actionlint` had no complaints about the file.

A red check only means something if we trust what it compares. The slow commit was easy to catch: at about 3x, nothing about the hardware could hide it. The dangerous deltas are small ones that look real, and a green or red check that is really measuring code layout. [Part 5](/posts/go-benchmarks-lying-three-questions/) opens with a CI regression that turned out to be a speedup. 🎟️
