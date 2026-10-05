---
title: "Before CI: Can You Trust a Benchmark on Your Own Laptop?"
description: "Same benchmark, three conditions: an idle Mac, a saturated one, and a container pinned to one vCPU. The numbers show what local isolation buys you and where it stops."
date: 2026-07-21T00:00:00Z
publishDate: 2026-07-21T00:00:00Z
promote: false
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

Every benchmark number starts life on somebody's laptop. We write the function, run it, like what we see and open the pull request, long before CI or a pinned runner gets a say. That makes it the least controlled measurement in the pipeline, and the one we act on. If it lies, everything downstream inherits the lie. Sending a noisy benchmark to CI doesn't fix the noise. It industrialises it.

Today we'll interrogate one laptop with one benchmark. `BenchmarkMakeBuffer_Correct` costs 11.46 ns/op on an idle Apple M4 Max. Start sixteen busy loops next to it and the same code costs 34.97 ns/op. Pin it to a single CPU inside a container and it settles at 16.28 ns/op, with its variance back near the idle level. Hold on to those three conditions; we'll keep coming back to them.

This is part 3 of 5 in the [Why Your Go Benchmarks Are Lying](/series/why-your-go-benchmarks-are-lying/) series, the written companion to the [GopherCon UK 2026 talk](/talks/why-your-go-benchmarks-are-lying/). The series asks three questions of a benchmark: does the compiler let it do real work ([part 1](/posts/go-benchmarks-lying-compiler-honesty/)), is the sample stable enough to mean anything ([part 2](/posts/go-benchmarks-lying-statistics/), which also defined CV), and is the difference large relative to the noise. This part takes the last question down to the machine in front of us, the noise floor under any difference: we'll see what a pinned container on a Mac buys and where it stops, then borrow the Linux controls that go further. The [FOSDEM 2026 post](/posts/fosdem-2026-measuring-software-performance/) is the prerequisite for the series, and every number below comes from the demo in [gopherconuk-26 at fdce88c](https://github.com/kakkoyun/gopherconuk-26/tree/fdce88cc0ce129b7d2edfb1a20d02fe647c17eeb/talks/go-benchmarks-lying/demo).

Can we trust the laptop? Sometimes. Let's find out when.

## One benchmark, three conditions

We ran the benchmark with `-count=20 -benchtime=1s` on an Apple M4 Max (darwin/arm64, 16 logical CPUs) under three conditions. The "noisy" one starts 16 background spinners, pure busy-loops with no I/O and no allocation that saturate every logical core. The third reruns the benchmark on that same noisy host inside a `golang:1.26` container started with [`--cpuset-cpus=0 --cpus=1 --memory=512m`](https://docs.docker.com/engine/containers/resource_constraints/). The spinners never stop.

| Condition | Mean ns/op | Stddev | CV% |
|---|---|---|---|
| Idle host | 11.46 | 0.54 | 4.75 |
| Host with 16 background spinners | 34.97 | 6.60 | 18.88 |
| Container pinned to vCPU 0, same 16 spinners | 16.28 | 0.85 | 5.25 |

That's one run of 20 samples per condition on one machine. The host's Go version wasn't recorded, which is a little embarrassing for a post about reproducibility. We'll come back to that.

Idle to noisy: the benchmark slowed by 3× and CV jumped from 4.75% to 18.88%. Both effects most likely share a cause: the spinners and the benchmark compete for the same 16 cores, so the scheduler preempts the benchmark and moves it between cores, including the slower efficiency cores on this chip. This experiment does not separate those effects.

Noisy to pinned is the interesting one. CV drops to 5.25%, nearly back to the idle noise floor. The absolute runtime stays elevated (16.28 ns/op against 11.46 idle), which is unsurprising for a single pinned vCPU (`GOMAXPROCS=1`, judging by the missing `-16` suffix in the pinned run's output) inside a VM running a different OS, though this experiment does not isolate which of those accounts for it. The variance is the point, and it collapses, though at one run per condition the gap between 4.75% and 5.25% is within what sampling error alone could produce.

Pinning works, then. Sort of. 5.25% is not a triumph, and why it isn't tells us what a container can't do.

## What a container on a Mac can and can't pin

On a bare-metal Linux runner with SMT disabled and CPU frequency pinned, the [FOSDEM 2026 experiments](https://github.com/igoragoli/fosdem-2026-software-performance) measured around 0.05% CV on a CPU-bound task. That is roughly a hundred times tighter, across different workloads, than Docker on a Mac gave us.

Docker Desktop on macOS runs containers inside a Linux VM (here, Apple's Virtualization.framework). When we pass `--cpuset-cpus=0`, we pin to vCPU 0 inside that VM, not to a physical core on the host. The host scheduler can migrate that vCPU between physical cores at will, and nothing inside the container can pin the host CPU clock frequency. It's a quiet room in a building whose thermostat someone else controls.

What the pinning does buy is a stable CPU for the benchmark's threads, which stop migrating across the VM's virtual CPUs, and a VM with nothing else running in it. The table shows that matters. Frequency scaling, thermal variation and the host's choice of physical core for the VM's threads all remain in play.

The Mac numbers are good for catching obvious regressions during development, not for publication. Results that need to hold up to scrutiny belong on bare-metal Linux with SMT and frequency scaling disabled, with a note in the writeup saying so. Let's see what that environment is made of.

## The Linux toolbox

On Linux we can reach the knobs the Mac's VM hides. We'll go from free to fussy.

### CPU affinity

The OS scheduler migrates processes between cores to balance load, and each migration evicts warm cache lines. `taskset` stops that at zero setup cost:

```bash
taskset -c 0 go test -bench=. -count=10 -benchtime=2s ./...
```

The `-c 0` pins the whole run to core 0. It's worth it on Linux whenever we run `-count` of 10 or more. One side effect: the Go runtime reads the affinity mask, so this also sets `GOMAXPROCS=1` for the benchmark, which changes GC scheduling and any parallel benchmarks. Free isn't the same as harmless. When a pin isn't enough, we can take cores away from the scheduler entirely.

### Core isolation

With `isolcpus` on the kernel command line, specific cores leave the scheduler's load balancing, so only tasks we pin to them run there:

```text
# Add to kernel command line
isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3
```

After a reboot we pin benchmarks to the isolated cores with `taskset -c 2`. That suits a dedicated CI runner, since it needs a reboot and root. (`nohz_full` stops the scheduler tick on those cores while only one task runs there, and `rcu_nocbs` moves RCU callbacks off them; see the [kernel NO_HZ docs](https://docs.kernel.org/timers/no_hz.html).)

For a softer version that needs no reboot, `cset shield` achieves similar isolation at runtime, but only on hosts that still use cgroup v1:

```bash
sudo cset shield --cpu=2,3 --kthread=on
sudo cset shield --exec -- go test -bench=. -count=10 ./...
sudo cset shield --reset
```

Create the shield, run inside it, tear it down. The `--kthread=on` flag is critical: without it, kernel threads still run on the shielded cores.

### Process priority

`nice` raises the scheduling priority of the benchmark relative to other processes:

```bash
sudo nice -n -5 go test -bench=. -count=10 ./...
```

The effect is modest on a quiet machine but meaningful under moderate load. On dedicated machines, `chrt -f` (SCHED_FIFO) goes real-time:

```bash
sudo chrt -f 50 go test -bench=. -count=10 ./...
```

SCHED_FIFO can starve normal processes, the display server included, if the benchmark misbehaves (the kernel's default real-time throttling leaves them about 5%). That's a fine way to lose your terminal, so keep it to dedicated machines or a resource-capped container. Isolation and priority decide who gets the CPU. Frequency decides how fast it runs.

### CPU frequency control

Dynamic frequency scaling (DFS) is a large source of hidden variance on Linux: the CPU boosts when thermals allow and throttles when they do not.

[`perflock`](https://github.com/aclements/perflock), written by Austin Clements of the Go team, locks the CPU to a stable frequency for the duration of the run. It talks to a small daemon that holds the lock, so the setup has two steps:

```bash
GOBIN=$PWD go install github.com/aclements/perflock/cmd/perflock@b67f3f23152f
sudo install ./perflock /usr/bin/perflock
sudo -b perflock -daemon

perflock go test -bench=. -count=10 -benchtime=2s ./...
```

The first three lines build it at a pinned commit, install it and start the daemon. The last runs the benchmark under the lock. On Linux it pins the frequency by writing `scaling_min_freq` and `scaling_max_freq` through the cpufreq sysfs interface, which makes it one of the higher-value local tools after `benchstat`, daemon and all.

{{< sidenote side="right" label="perflock-mac" >}}
`perflock` builds on macOS, but its frequency pinning relies on the Linux cpufreq sysfs interface. On a Mac the governor step fails inside the daemon and the error is discarded, leaving only the mutual-exclusion lock: no racing benchmark runs, and no help with frequency noise.
{{< /sidenote >}}

If we'd rather apply the sysfs controls by hand, here they are:

```bash
# Performance governor
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Disable Intel Turbo Boost (intel_pstate driver)
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo

# Disable frequency boost (acpi-cpufreq or amd-pstate drivers)
echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost

# Disable SMT (caution: halves logical CPU count)
echo off | sudo tee /sys/devices/system/cpu/smt/control
# Re-enable when done
echo on | sudo tee /sys/devices/system/cpu/smt/control
```

The bare-metal SMT and DFS numbers behind these controls are in [part 4](/posts/go-benchmarks-lying-ci/#why-shared-runners-lie). Even a locked frequency leaves one thing we can't lock: how hot the chip is when the run starts.

## Thermal steady state

CPUs boost when cool and throttle when hot. A benchmark that starts on a cold chip and ends on a warm one shows a performance *decrease* across the run, which has nothing to do with the code. In raw `go test` output, the first few runs of a `-count=20` sequence are typically faster than the last few (the expected pattern, not one we measured here).

A throwaway run before capturing helps, as does waiting 30 to 60 seconds between major runs (a rule of thumb, not a measured number). Holding the frequency steady with `perflock` or by disabling DFS helps regardless of thermals. Laptops are worse than desktops here: ambient temperature, prior CPU workload and fan behavior all affect how long steady state takes. Skip the warmup and the early samples are biased warm. With the environment as quiet as it's going to get, we can finally compare two versions of the code.

## The Go-native A/B loop

Controls reduce noise, but we also need a structured way to compare two versions. The manual approach is to capture a baseline, apply the change, capture again and let `benchstat` compare:

```bash
# Capture baseline
go test -bench=BenchmarkMyFunc -benchmem -count=10 -benchtime=2s . > old.txt

# Apply change, then capture
go test -bench=BenchmarkMyFunc -benchmem -count=10 -benchtime=2s . > new.txt

# Compare
benchstat old.txt new.txt
```

The flags and machine conditions have to match on both sides, or we end up benchmarking the room instead of the code. Captured minutes apart, the two files can also see different machines. The [`benchstat` docs](https://pkg.go.dev/golang.org/x/perf@v0.0.0-20260929162123-406019bb8b68/cmd/benchstat) recommend interleaving the before and after runs, and `go test -c` makes that cheap: build both test binaries once, then alternate them.

```bash
GOOS=linux go test -c -o old.test   # on the base commit
GOOS=linux go test -c -o new.test   # with the change
for i in $(seq 10); do
  ./old.test -test.run='^$' -test.bench=. -test.count=1 >> old.txt
  ./new.test -test.run='^$' -test.bench=. -test.count=1 >> new.txt
done
benchstat old.txt new.txt
```

On a Mac, the `GOOS=linux` builds run inside the pinned container (`docker run --cpuset-cpus=0 -v "$PWD":/w -w /w ...`, with the loop as the command) so both sides share its conditions. For the inner development loop, [`benchdiff`](https://github.com/willabides/benchdiff) automates the cycle, with the base ref running in a temporary git worktree:

```bash
go install github.com/willabides/benchdiff/cmd/benchdiff@v0.9.1
benchdiff --base-ref=main --benchmem --count=10 --benchtime=2s
```

It runs both sides under the same conditions and compares them with a bundled, older copy of `benchstat`.

The toolchain is a condition too, and the one we forgot to record in our own table. Since Go 1.21 the `go` directive in `go.mod` is a minimum, not a pin: a newer local toolchain runs the module anyway. Different Go versions produce different numbers, so pin with `GOTOOLCHAIN=go1.26.5` and mention the version in any result you share. The last round of fixes needs no tools at all.

## Cheap wins that take five minutes

Close the browser, IDE and Slack, the most expensive background processes on most laptops. On macOS, turn off Spotlight indexing with `sudo mdutil -a -i off` so the indexer doesn't spike mid-run, and undo it afterwards with `sudo mdutil -a -i on`. Switch off Wi-Fi and Bluetooth (airplane mode, if your OS has one) to cut NIC interrupts and background traffic. On a noisy machine, closing the browser alone can noticeably lower CV before you touch anything else. Nobody has ever regretted closing Slack.

## Back to the three rows

Back to the rows from the top: 4.75% CV on an idle Mac, 18.88% with the spinners running, 5.25% in the pinned container. On a Mac, we run `-count=20 -benchtime=2s`, watch the `±` column in `benchstat` (a 95% confidence interval, not CV), compute CV as in [part 2](/posts/go-benchmarks-lying-statistics/#what-benchstat-doesnt-tell-you), and treat a CV above 5% as a reason to investigate the environment and above 10% as a reason not to trust the comparison at all (the bands from part 2).

Everywhere, that means `-count` of 10 or more, `benchstat`, `benchdiff` and closed apps. On Linux we add `taskset`, `perflock` and `nice`. On a dedicated machine or runner we add SMT and frequency control, `isolcpus` and `cset shield`. On a Mac, a pinned container helps with variance, not absolute numbers. Time to check our own numbers.

## Try it

To reproduce the three conditions, we clone the demo at the pinned commit. This needs Docker, and the container step mounts the current directory, so run it from a path your Docker VM can see:

```bash
git clone https://github.com/kakkoyun/gopherconuk-26
cd gopherconuk-26
git checkout fdce88cc0ce129b7d2edfb1a20d02fe647c17eeb
cd talks/go-benchmarks-lying/demo
make bench-docker
make cv
```

`make bench-docker` re-runs all three conditions (expect a minute or two) and overwrites `results/`, so your numbers will differ from ours. `make cv` recomputes the summary from whatever is in `results/`.

Versions, links and commands checked on 2 October 2026.

## Up next

[Part 4, Benchmark CI That Doesn't Lie](/posts/go-benchmarks-lying-ci/), takes the same discipline to CI: why shared runners lie, a two-tier gate, and the tools that back it. If sixteen spinners felt rude, wait until we meet other teams' Docker builds. Between the two sits a companion, [The laptop said 230%](/posts/go-benchmarks-laptop-said-230/), where a loaded laptop and CI disagreed about one change.
