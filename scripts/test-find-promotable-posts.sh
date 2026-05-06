#!/usr/bin/env bash
# Unit tests for scripts/find-promotable-posts.sh
#
# Self-contained: each test case spins up an isolated git repo.
# No external test framework required.
#
# Usage: bash scripts/test-find-promotable-posts.sh
set -euo pipefail

FIND_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/find-promotable-posts.sh"
TODAY=$(date -u +%Y-%m-%d)

# Portable date arithmetic: GNU date (Linux CI) vs BSD date (macOS)
if date -d "1 day ago" +%Y-%m-%d >/dev/null 2>&1; then
  YESTERDAY=$(date -u -d "1 day ago" +%Y-%m-%d)
  TOMORROW=$(date -u -d "1 day" +%Y-%m-%d)
else
  YESTERDAY=$(date -u -v-1d +%Y-%m-%d)
  TOMORROW=$(date -u -v+1d +%Y-%m-%d)
fi

PASS=0
FAIL=0

# ── Assertion helpers ─────────────────────────────────────────────────────────

pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; (( PASS += 1 )); }
fail() {
  printf "  \033[31mFAIL\033[0m  %s\n" "$1"
  printf "         expected: %s\n" "${2:-<empty>}"
  printf "         actual:   %s\n" "${3:-<empty>}"
  (( FAIL += 1 ))
}

assert_eq() {
  if [ "$2" = "$3" ]; then
    pass "$1"
  else
    fail "$1" "$2" "$3"
  fi
}
assert_empty() { assert_eq "$1" "" "$2"; }

# ── Repo setup helpers (inherited by subshells via ( ... )) ───────────────────

setup_repo() {
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  mkdir -p content/posts
  touch content/posts/.gitkeep
  git add content/posts/.gitkeep
  GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" \
    git commit -q -m "init"
}

make_post() {
  # make_post <file> [publishDate] [draft=true|false]
  local file="$1"
  local pub_date="${2:-$TODAY}"
  local is_draft="${3:-false}"
  mkdir -p "$(dirname "$file")"
  {
    echo "---"
    echo "title: \"Test Post\""
    echo "publishDate: ${pub_date}T00:00:00Z"
    echo "categories:"
    echo "  - engineering"
    echo "tags:"
    echo "  - blog"
    [ "$is_draft" = "true" ] && echo "draft: true"
    echo "---"
    echo ""
    echo "Post body content."
  } > "$file"
}

commit_at() {
  # commit_at <file> <YYYY-MM-DD>
  # Uses GIT_COMMITTER_DATE so `git log --format=%cs` returns a controlled date.
  local file="$1"
  local commit_date="$2"
  git add "$file"
  GIT_COMMITTER_DATE="${commit_date}T12:00:00Z" GIT_AUTHOR_DATE="${commit_date}T12:00:00Z" \
    git commit -q -m "add $(basename "$file")"
}

run_find() {
  # Runs the find script; stderr (SKIP messages) suppressed, stdout captured by caller.
  bash "$FIND_SCRIPT" "$@" 2>/dev/null
}

make_post_raw() {
  # make_post_raw <file> <publishDate-value-verbatim> [draft=true|false]
  # Writes publishDate exactly as given — no T00:00:00Z appended.
  local file="$1"
  local pub_date_value="$2"
  local is_draft="${3:-false}"
  mkdir -p "$(dirname "$file")"
  {
    echo "---"
    echo "title: \"Test Post\""
    echo "publishDate: ${pub_date_value}"
    echo "categories:"
    echo "  - engineering"
    echo "tags:"
    echo "  - blog"
    [ "$is_draft" = "true" ] && echo "draft: true"
    echo "---"
    echo ""
    echo "Post body content."
  } > "$file"
}

make_post_no_date() {
  # make_post_no_date <file> [draft=true|false]
  # Writes a post with no publishDate field.
  local file="$1"
  local is_draft="${2:-false}"
  mkdir -p "$(dirname "$file")"
  {
    echo "---"
    echo "title: \"No Date Post\""
    [ "$is_draft" = "true" ] && echo "draft: true"
    echo "---"
    echo ""
    echo "Post body content."
  } > "$file"
}

# ── Test runner ───────────────────────────────────────────────────────────────
# Each test function is called inside a ( subshell ) that has cd'd into a fresh
# temp repo. Functions inherit setup_repo/make_post/commit_at/run_find/TODAY etc.

with_repo() {
  # with_repo <fn> — capture stdout from fn running in an isolated git repo
  local fn="$1"
  local tmpdir
  tmpdir=$(mktemp -d)
  # Inner subshell: cd + setup + run test body
  (cd "$tmpdir" && setup_repo && "$fn")
  local rc=$?
  rm -rf "$tmpdir"
  return "$rc"
}

# ── push mode ─────────────────────────────────────────────────────────────────

echo "── push mode ──────────────────────────────────────────"

_push_today()   { make_post "content/posts/new.md" "$TODAY";     commit_at "content/posts/new.md" "$TODAY";     run_find push; }
_push_future()  { make_post "content/posts/fut.md" "$TOMORROW";  commit_at "content/posts/fut.md" "$TODAY";     run_find push; }
_push_draft()   { make_post "content/posts/d.md"   "$TODAY" true; commit_at "content/posts/d.md"  "$TODAY";     run_find push; }
_push_no_post() {
  echo "readme" > README.md
  git add README.md
  GIT_COMMITTER_DATE="${TODAY}T12:00:00Z" GIT_AUTHOR_DATE="${TODAY}T12:00:00Z" git commit -q -m "readme"
  run_find push
}
_push_mixed() {
  make_post "content/posts/ok.md"     "$TODAY"
  make_post "content/posts/draft.md"  "$TODAY" true
  make_post "content/posts/future.md" "$TOMORROW"
  git add content/posts/
  GIT_COMMITTER_DATE="${TODAY}T12:00:00Z" GIT_AUTHOR_DATE="${TODAY}T12:00:00Z" git commit -q -m "mixed"
  run_find push
}

result=$(with_repo _push_today)
assert_eq   "push: promotes new post with today's publishDate" "content/posts/new.md" "$result"

result=$(with_repo _push_future)
assert_empty "push: skips new post with future publishDate" "$result"

result=$(with_repo _push_draft)
assert_empty "push: skips draft post" "$result"

result=$(with_repo _push_no_post)
assert_empty "push: no output when commit has no posts" "$result"

result=$(with_repo _push_mixed)
assert_eq   "push: promotes only the publishable post from a mixed commit" "content/posts/ok.md" "$result"

# ── schedule mode ─────────────────────────────────────────────────────────────

echo ""
echo "── schedule mode ──────────────────────────────────────"

_sched_yesterday() { make_post "content/posts/sched.md" "$TODAY";         commit_at "content/posts/sched.md" "$YESTERDAY"; run_find schedule; }
_sched_today()     { make_post "content/posts/same.md"  "$TODAY";         commit_at "content/posts/same.md"  "$TODAY";     run_find schedule; }
_sched_future()    { make_post "content/posts/fut.md"   "$TOMORROW";      commit_at "content/posts/fut.md"   "$YESTERDAY"; run_find schedule; }
_sched_draft()     { make_post "content/posts/d.md"     "$TODAY" true;    commit_at "content/posts/d.md"     "$YESTERDAY"; run_find schedule; }
_sched_dedup() {
  # pushed-today: committed today (should be deduped, push trigger ran it)
  make_post "content/posts/pushed-today.md" "$TODAY"
  commit_at "content/posts/pushed-today.md" "$TODAY"
  # scheduled: committed yesterday, publishDate today → should promote
  make_post "content/posts/scheduled.md" "$TODAY"
  commit_at "content/posts/scheduled.md" "$YESTERDAY"
  run_find schedule
}

result=$(with_repo _sched_yesterday)
assert_eq   "schedule: promotes post committed yesterday with today's publishDate" "content/posts/sched.md" "$result"

result=$(with_repo _sched_today)
assert_empty "schedule: dedup — skips post added today (push trigger already ran)" "$result"

result=$(with_repo _sched_future)
assert_empty "schedule: skips post with future publishDate" "$result"

result=$(with_repo _sched_draft)
assert_empty "schedule: skips draft even when publishDate matches today" "$result"

result=$(with_repo _sched_dedup)
assert_eq   "schedule: dedup skips today-added, promotes yesterday-committed" "content/posts/scheduled.md" "$result"

# ── manual mode ───────────────────────────────────────────────────────────────

echo ""
echo "── manual mode ─────────────────────────────────────────"

_manual_old()         { make_post "content/posts/old.md"   "2020-01-01";      commit_at "content/posts/old.md"   "2020-01-01"; run_find manual "content/posts/old.md";   }
_manual_draft()       { make_post "content/posts/d.md"     "$TODAY" true;     commit_at "content/posts/d.md"     "$TODAY";     run_find manual "content/posts/d.md";     }
_manual_missing()     {                                                                                                          run_find manual "content/posts/gone.md"; }

result=$(with_repo _manual_old)
assert_eq   "manual: returns path regardless of publishDate" "content/posts/old.md" "$result"

result=$(with_repo _manual_draft)
assert_empty "manual: skips draft" "$result"

result=$(with_repo _manual_missing)
assert_empty "manual: skips nonexistent file" "$result"

# ── edge cases (date/path invariants) ─────────────────────────────────────────

echo ""
echo "── edge cases ──────────────────────────────────────────"

_edge_datetime_pub() {
  # publishDate with time component — get_publish_date must strip T...
  make_post_raw "content/posts/dt.md" "${TODAY}T12:00:00Z"
  commit_at "content/posts/dt.md" "$TODAY"
  run_find push
}
_edge_missing_pub_date() {
  # No publishDate field — validate_post must SKIP
  make_post_no_date "content/posts/nodate.md"
  commit_at "content/posts/nodate.md" "$TODAY"
  run_find push
}
_edge_quoted_date() {
  # publishDate: "YYYY-MM-DD" — tr -d '"' branch in get_publish_date
  make_post_raw "content/posts/quoted.md" "\"${TODAY}\""
  commit_at "content/posts/quoted.md" "$TODAY"
  run_find push
}
_edge_sched_empty_dir() {
  # content/posts/ has no .md files — schedule must be a no-op, not a glob failure
  run_find schedule
}
_edge_manual_out_of_tree() {
  # manual accepts a path outside content/posts/ (date check is skipped)
  mkdir -p other/dir
  make_post_raw "other/dir/external.md" "2020-01-01"
  git add other/dir/external.md
  GIT_COMMITTER_DATE="${TODAY}T12:00:00Z" GIT_AUTHOR_DATE="${TODAY}T12:00:00Z" \
    git commit -q -m "out of tree"
  run_find manual "other/dir/external.md"
}

result=$(with_repo _edge_datetime_pub)
assert_eq    "edge: push handles publishDate with time component (get_publish_date strips T...)" "content/posts/dt.md" "$result"

result=$(with_repo _edge_missing_pub_date)
assert_empty "edge: push skips post with missing publishDate" "$result"

result=$(with_repo _edge_quoted_date)
assert_eq    "edge: push handles quoted publishDate (tr -d '\"' branch)" "content/posts/quoted.md" "$result"

result=$(with_repo _edge_sched_empty_dir)
assert_empty "edge: schedule is a no-op when content/posts has no .md files" "$result"

result=$(with_repo _edge_manual_out_of_tree)
assert_eq    "edge: manual accepts path outside content/posts (permissive, date check skipped)" "other/dir/external.md" "$result"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
TOTAL=$(( PASS + FAIL ))
printf "%d/%d tests passed\n" "$PASS" "$TOTAL"
[ "$FAIL" -eq 0 ]
