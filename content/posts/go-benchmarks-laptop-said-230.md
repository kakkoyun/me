---
title: "The laptop said 230%"
description: "One otelc change, two overhead numbers: 230% on my loaded machine and 81% in CI. The scenario that could not have moved is what gave the laptop away."
date: 2026-07-24T00:00:00Z
publishDate: 2026-07-24T00:00:00Z
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

Here is a pull request with two numbers for the same change. My machine said the `multi` scenario cost 230% over a plain build. CI said 81%. Both numbers were honest readings of a stopwatch. I think only one of them was measuring the pull request. We'll work out which, and find the one question that would have told me before CI did.

This is a companion to the [Why Your Go Benchmarks Are Lying](/series/why-your-go-benchmarks-are-lying/) series, between [Part 3](/posts/go-benchmarks-lying-local-reproduction/) (the laptop) and [Part 4](/posts/go-benchmarks-lying-ci/) (CI). Those parts use microbenchmarks. This story is about a macrobenchmark, a whole build timed end to end, and it didn't fit my [GopherCon UK talk](/talks/why-your-go-benchmarks-are-lying/). Disclosure: I work at Datadog and I'm one of otelc's maintainers.

A caveat on sourcing. The CI numbers and the PR discussion are public. The two laptop numbers are first-hand: they aren't recorded in the PR, so you have my word for them and nothing else. As of 2 October the CI job logs have also expired (GitHub answers HTTP 410), so everything from CI below comes from comments on the PR.

## What the check measures

[otelc](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation) instruments Go programs at compile time, through `go build -toolexec`. Every package in a build spawns an otelc process, even when no rule matches it. The [benchmarking doc at v1.1.0](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/v1.1.0/docs/benchmarking.md) calls that overhead "the primary UX metric to track", and the check times three scenarios:

| Scenario | What it builds |
|---|---|
| `baseline` | stdlib only (`fmt`), no rule matches |
| `multi` | `net/http`, gRPC, `database/sql`, Redis and client-go, with 6–8 instrumented packages |
| `largeidle` | heavy stdlib plus many third-party libraries, zero instrumented packages |

The overhead is `(otelc − plain) / plain`, so 230% means the instrumented build took about 3.3 times as long. The ceiling is 150% for every scenario except `baseline`, which gets 500%. Here is the heart of the [test as it stood when #643 merged](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/5911ac776cd58d0ba98d57eb3084e522bb0ddb44/test/bench/overhead_test.go):

```go
plain := minBuildTime(t, dir, plainArgs, name)
otelcTime := minBuildTime(t, dir, otelcArgs, name)
pct := (otelcTime - plain) / plain * 100
```

`minBuildTime` runs a full rebuild (`go build -a`) three times and keeps the fastest, a common way to cut noise. Look at the order, though. All three plain builds run first, then all three otelc builds. If the machine changes its mood between the two halves, the percentage absorbs the whole difference. That detail will matter in a minute.

## Two numbers for one change

The pull request, [#643](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/pull/643), consolidated a pile of dependency bumps, among them `go.opentelemetry.io/otel` core to v1.44.0. On 3 July I ran the overhead check on my own machine. I'll keep calling it "the laptop", since the title is already committed. I'd been running parallel builds and integration tests on it all session. CI ran the same check that day.

| Scenario | Laptop | CI | Ceiling |
|---|---|---|---|
| `multi` | ~230% | +81% | 150% |
| `largeidle` | ~212% | +105% | 150% |
| `baseline` | not recorded | +514.9%, then +521.9% on a rerun | 500% |

That's one run on each side, from different machines, and I can't promise both ran the identical commit. The laptop column is my recollection of the terminal, hence the tildes.

Read cold, the laptop column says the bump broke two scenarios. The CI column says only `baseline` fails. Which one do we believe?

## The scope tell

Ask what the change could have touched. The PR edited `multi`'s own `go.mod` and `go.sum`, and nothing in `largeidle`'s module. Yet `largeidle` came out at 212%, about as far over its ceiling as `multi`. When a scenario the change didn't touch moves by the same amount as one it did, suspect the machine before the diff.

I should be fair to the scenario, though. It wasn't a perfectly clean control. The description of the later fix, [#650](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/pull/650), says otelc always injects the OpenTelemetry SDK initialization package, so an SDK bump can reach every scenario, `largeidle` included. CI settles it. On CI `largeidle` sat at +105%, a hundred points under the laptop's reading, with the SDK bump already in. Whatever the bump cost, it doesn't explain 212%.

I waited for CI instead of hunting for a regression in code that hadn't changed. I never reran the check on a quiet machine and I didn't log CPU pressure, so "load did it" is my attribution. It fits every number above. I can't prove it.

Now the detail from a few paragraphs ago. [In the rerun on the PR](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/pull/643#issuecomment-4875740809), `baseline` went from 2.146s plain and 13.197s with otelc to 3.432s and 21.344s. Both times grew by about 60%, and the overhead moved from +514.9% to +521.9%. A machine that is uniformly slower cancels out of a ratio, which is why CI's failure repeated so steadily. What doesn't cancel is load that arrives between the plain half and the otelc half, or that hits one build harder than the other. A full `-a` rebuild fans out across every core, so parallel builds on the same machine are a likely source. That part is my guess too.

CI's failure was real, though. Only `baseline` crossed its ceiling, and [my comment on the PR](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/pull/643#issuecomment-4875740809) and the [#650](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/pull/650) description both put it down to the SDK bump. My reading of why `baseline` feels it most: it compiles a program with one `fmt` call, so a fixed cost for compiling the SDK dominates its percentage. #650 merged on 6 July and raised that ceiling from 500% to 550%. The maintainers loosened the limit rather than hold back the dependency bump. Judging a real measurement is a different job from catching a lying one.

Next, a confession about CI.

## CI is a second opinion, not the truth

We could end with "trust CI". The pinned workflow doesn't back that up. At the commit where #643 merged, the [overhead job](https://github.com/open-telemetry/opentelemetry-go-compile-instrumentation/blob/5911ac776cd58d0ba98d57eb3084e522bb0ddb44/.github/workflows/benchmark.yaml) declares `runs-on: ubuntu-latest`. That label names an image. It doesn't tell us how busy the host was. The workflow's other job, the CodSpeed walltime run, names a bare-metal machine instead. I don't know what else was running next to the overhead check, and I won't pretend to.

What CI gave us was a second measurement with different noise, and the two disagreed in a pattern we could read. That is [Part 4's](/posts/go-benchmarks-lying-ci/) territory: shared runners add their own kind of weather. Two readings and a scope argument beat one reading and a hunch.

Versions, links and commands checked on 2 October 2026.

## Before you trust a macrobenchmark

Next time a number looks alarming, ask the cheap question first: what scenario in this run could not have changed? If it moved too, the diff is innocent until proven otherwise. Then check how the test orders its halves, since a ratio only protects you from noise that lands on both sides.

The laptop said 230%. CI said 81%. The 230% told me more about my machine than about the pull request, and the question that showed it cost nothing to ask. 🌡️
