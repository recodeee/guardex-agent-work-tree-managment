#!/usr/bin/env bash
# test-agent-naming.sh — regression coverage for agent-branch-start.sh naming.
#
# New naming contract:
#   agent/<role>/<task-slug>-<YYYY-MM-DD>-<HH-MM>
#
# Where:
#   - role ∈ {claude, codex} for the common case, or any sanitized explicit role
#     token (integrator, executor, rust-port, ...) when passed directly or via
#     GUARDEX_AGENT_TYPE. The legacy name "bot" still falls back to codex.
#   - task-slug is the user-provided task name, lowercased + kebab-cased.
#   - timestamp is local YYYY-MM-DD-HH-MM; colons are forbidden in git refs, so
#     the HH:MM the user sees is stored as HH-MM in the slug.
#
# Usage: bash scripts/test-agent-naming.sh

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
START_SCRIPT="${REPO_ROOT}/scripts/agent-branch-start.sh"

if [[ ! -x "$START_SCRIPT" ]]; then
  echo "FAIL: ${START_SCRIPT} not found or not executable" >&2
  exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

assert_eq() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  PASS  %-60s actual=%q\n' "$label" "$actual"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  FAIL  %-60s\n         expected=%q\n         actual=  %q\n' \
      "$label" "$expected" "$actual"
  fi
}

assert_matches() {
  local label="$1"
  local actual="$2"
  local regex="$3"
  if [[ "$actual" =~ $regex ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  PASS  %-60s actual=%q\n' "$label" "$actual"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  FAIL  %-60s\n         regex=   %s\n         actual=  %q\n' \
      "$label" "$regex" "$actual"
  fi
}

refute_substring() {
  local label="$1"
  local actual="$2"
  local needle="$3"
  if [[ "$actual" == *"$needle"* ]]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  FAIL  %-60s\n         contains=%q\n         actual=  %q\n' \
      "$label" "$needle" "$actual"
  else
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  PASS  %-60s actual=%q\n' "$label" "$actual"
  fi
}

# Pinned timestamp → names are fully deterministic across test runs.
STAMP="2026-04-19-19-44"

run_name_only() {
  # Args: TASK AGENT [extra env as VAR=val ...]
  local task="$1"; shift
  local agent="$1"; shift
  env -i \
    PATH="/usr/bin:/bin:/usr/local/bin" \
    HOME="$HOME" \
    GIT_DIR="$(git -C "$REPO_ROOT" rev-parse --git-dir 2>/dev/null || echo "$REPO_ROOT/.git")" \
    GUARDEX_BRANCH_TIMESTAMP="$STAMP" \
    "$@" \
    bash "$START_SCRIPT" --print-name-only "$task" "$agent" 2>/dev/null \
    | tail -n 1
}

echo "== Role normalization =="

actual="$(run_name_only task1 codex)"
assert_eq "bare 'codex' role"               "$actual" "agent/codex/task1-${STAMP}"

actual="$(run_name_only task2 codex-admin-recodee-com)"
assert_eq "codex-* legacy name collapses"   "$actual" "agent/codex/task2-${STAMP}"

actual="$(run_name_only task3 claude-design-polish)"
assert_eq "claude-* legacy name collapses"  "$actual" "agent/claude/task3-${STAMP}"

actual="$(run_name_only task4 rust-port-lead CLAUDECODE=1)"
assert_eq "neutral name + CLAUDECODE=1 → claude" \
  "$actual" "agent/claude/task4-${STAMP}"

actual="$(run_name_only task5 rust-port-lead)"
assert_eq "neutral explicit name stays preserved" \
  "$actual" "agent/rust-port-lead/task5-${STAMP}"

actual="$(run_name_only task6 claude GUARDEX_AGENT_TYPE=codex)"
assert_eq "GUARDEX_AGENT_TYPE=codex overrides claude arg" \
  "$actual" "agent/codex/task6-${STAMP}"

actual="$(run_name_only task7 claude GUARDEX_AGENT_TYPE=integrator)"
assert_eq "GUARDEX_AGENT_TYPE=integrator wins" \
  "$actual" "agent/integrator/task7-${STAMP}"

echo ""
echo "== Task slug shape =="

actual="$(run_name_only "How It Works Design Polish" claude)"
assert_eq "whitespace/case → kebab-case task slug" \
  "$actual" "agent/claude/how-it-works-design-polish-${STAMP}"

actual="$(run_name_only "weird!!chars??here" codex)"
assert_eq "punctuation collapses to single dash"  \
  "$actual" "agent/codex/weird-chars-here-${STAMP}"

echo ""
echo "== Descriptor shape (no email/domain/host fragments) =="

actual="$(run_name_only some-task codex \
  GUARDEX_CODEX_AUTH_SNAPSHOT="admin@megkapja.hu")"
refute_substring "no email domain leak (-hu)"         "$actual" "-hu"
refute_substring "no host leak (zeus)"                "$actual" "zeus"
refute_substring "no nickname leak (admin)"           "$actual" "admin"
refute_substring "no email user leak (megkapja)"      "$actual" "megkapja"
assert_matches "final shape is agent/<role>/<task>-<timestamp>" \
  "$actual" "^agent/codex/some-task-${STAMP}$"

echo ""
echo "== Timestamp format =="

# Real timestamp (no GUARDEX_BRANCH_TIMESTAMP override) must be YYYY-MM-DD-HH-MM.
actual="$(
  env -i \
    PATH="/usr/bin:/bin:/usr/local/bin" \
    HOME="$HOME" \
    GIT_DIR="$(git -C "$REPO_ROOT" rev-parse --git-dir 2>/dev/null || echo "$REPO_ROOT/.git")" \
    bash "$START_SCRIPT" --print-name-only rt claude 2>/dev/null \
    | tail -n 1
)"
assert_matches "live timestamp is YYYY-MM-DD-HH-MM" \
  "$actual" '^agent/claude/rt-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$'

refute_substring "no colons in branch name"   "$actual" ":"

echo ""
echo "== Summary =="
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
