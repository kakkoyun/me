---
description: Draft the next issue of the CoreDump newsletter from coding-session logs. Runs interactively or unattended.
---

Draft the next issue of the CoreDump newsletter using the `coredump` skill.

Arguments (all optional): $ARGUMENTS

Supported overrides:
- `--days N`            search window in days
- `--since YYYY-MM-DD`  explicit window start (overrides auto-detected publishDate)
- `--until YYYY-MM-DD`  window end (default: today)
- `--issue NNN`         force a specific issue number
- `--unattended`        headless mode: skip the author interview and defer its questions
                        into the issue (for CI/cron runs)

Invoke the full `coredump` skill workflow with the arguments above. Follow all seven steps
(Step 0–6): resolve window → aggregate session logs → write brief → interview author (or
defer, when `--unattended`) → draft issue → Vale check → hand off.
