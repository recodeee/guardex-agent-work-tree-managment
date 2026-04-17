#!/usr/bin/env bash
set -euo pipefail

BASE_BRANCH=""
BASE_BRANCH_EXPLICIT=0
SOURCE_BRANCH=""
SOURCE_BRANCH_EXPLICIT=0
PUSH_ENABLED=1
DELETE_REMOTE_BRANCH=0
DELETE_REMOTE_BRANCH_EXPLICIT=0
MERGE_MODE="auto"
GH_BIN="${MUSAFETY_GH_BIN:-gh}"
CLEANUP_AFTER_MERGE_RAW="${MUSAFETY_FINISH_CLEANUP:-false}"
WAIT_FOR_MERGE_RAW="${MUSAFETY_FINISH_WAIT_FOR_MERGE:-false}"
WAIT_TIMEOUT_SECONDS_RAW="${MUSAFETY_FINISH_WAIT_TIMEOUT_SECONDS:-1800}"
WAIT_POLL_SECONDS_RAW="${MUSAFETY_FINISH_WAIT_POLL_SECONDS:-10}"
REQUIRE_REMOTE_GATES_RAW="${MUSAFETY_REQUIRE_REMOTE_GATES:-false}"
ENFORCE_AGENT_CLEANUP_RAW="${MUSAFETY_ENFORCE_AGENT_CLEANUP:-true}"
PR_REF="${MUSAFETY_GH_PR_REF:-}"
GH_REPO_REF="${MUSAFETY_GH_REPO:-}"
NO_CLEANUP_REQUESTED=0

normalize_bool() {
  local raw="${1:-}"
  local fallback="${2:-0}"
  local lowered
  lowered="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$lowered" in
    1|true|yes|on) printf '1' ;;
    0|false|no|off) printf '0' ;;
    '') printf '%s' "$fallback" ;;
    *) printf '%s' "$fallback" ;;
  esac
}

normalize_int() {
  local raw="${1:-}"
  local fallback="${2:-0}"
  local min_value="${3:-0}"
  local value="$raw"

  if [[ -z "$value" || ! "$value" =~ ^[0-9]+$ ]]; then
    value="$fallback"
  fi

  if (( value < min_value )); then
    value="$min_value"
  fi

  printf '%s' "$value"
}

CLEANUP_AFTER_MERGE="$(normalize_bool "$CLEANUP_AFTER_MERGE_RAW" "0")"
WAIT_FOR_MERGE="$(normalize_bool "$WAIT_FOR_MERGE_RAW" "0")"
WAIT_TIMEOUT_SECONDS="$(normalize_int "$WAIT_TIMEOUT_SECONDS_RAW" "1800" "30")"
WAIT_POLL_SECONDS="$(normalize_int "$WAIT_POLL_SECONDS_RAW" "10" "0")"
REQUIRE_REMOTE_GATES="$(normalize_bool "$REQUIRE_REMOTE_GATES_RAW" "0")"
ENFORCE_AGENT_CLEANUP="$(normalize_bool "$ENFORCE_AGENT_CLEANUP_RAW" "1")"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      BASE_BRANCH="${2:-}"
      BASE_BRANCH_EXPLICIT=1
      shift 2
      ;;
    --branch)
      SOURCE_BRANCH="${2:-}"
      SOURCE_BRANCH_EXPLICIT=1
      shift 2
      ;;
    --no-push)
      PUSH_ENABLED=0
      shift
      ;;
    --keep-remote-branch)
      DELETE_REMOTE_BRANCH=0
      DELETE_REMOTE_BRANCH_EXPLICIT=1
      shift
      ;;
    --delete-remote-branch)
      DELETE_REMOTE_BRANCH=1
      DELETE_REMOTE_BRANCH_EXPLICIT=1
      shift
      ;;
    --cleanup)
      CLEANUP_AFTER_MERGE=1
      shift
      ;;
    --no-cleanup)
      CLEANUP_AFTER_MERGE=0
      NO_CLEANUP_REQUESTED=1
      shift
      ;;
    --wait-for-merge)
      WAIT_FOR_MERGE=1
      shift
      ;;
    --no-wait-for-merge)
      WAIT_FOR_MERGE=0
      shift
      ;;
    --wait-timeout-seconds)
      WAIT_TIMEOUT_SECONDS="$(normalize_int "${2:-}" "1800" "30")"
      shift 2
      ;;
    --wait-poll-seconds)
      WAIT_POLL_SECONDS="$(normalize_int "${2:-}" "10" "0")"
      shift 2
      ;;
    --mode)
      MERGE_MODE="${2:-auto}"
      shift 2
      ;;
    --pr)
      PR_REF="${2:-}"
      shift 2
      ;;
    --repo)
      GH_REPO_REF="${2:-}"
      shift 2
      ;;
    --require-remote-gates)
      REQUIRE_REMOTE_GATES=1
      shift
      ;;
    --no-require-remote-gates)
      REQUIRE_REMOTE_GATES=0
      shift
      ;;
    --via-pr)
      MERGE_MODE="pr"
      shift
      ;;
    --direct-only)
      MERGE_MODE="direct"
      shift
      ;;
    *)
      echo "[agent-branch-finish] Unknown argument: $1" >&2
      echo "Usage: $0 [--base <branch>] [--branch <branch>] [--no-push] [--cleanup|--no-cleanup] [--wait-for-merge|--no-wait-for-merge] [--wait-timeout-seconds <n>] [--wait-poll-seconds <n>] [--keep-remote-branch|--delete-remote-branch] [--mode auto|direct|pr|--via-pr|--direct-only] [--pr <ref>] [--repo <owner/name>] [--require-remote-gates|--no-require-remote-gates]" >&2
      exit 1
      ;;
  esac
done

case "$MERGE_MODE" in
  auto|direct|pr) ;;
  *)
    echo "[agent-branch-finish] Invalid --mode value: ${MERGE_MODE} (expected auto|direct|pr)" >&2
    exit 1
    ;;
esac

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[agent-branch-finish] Not inside a git repository." >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
current_worktree="$(pwd -P)"
common_git_dir_raw="$(git -C "$repo_root" rev-parse --git-common-dir)"
if [[ "$common_git_dir_raw" == /* ]]; then
  common_git_dir="$common_git_dir_raw"
else
  common_git_dir="$(cd "$repo_root/$common_git_dir_raw" && pwd -P)"
fi
repo_common_root="$(cd "$common_git_dir/.." && pwd -P)"
agent_worktree_root="${repo_common_root}/.omx/agent-worktrees"

infer_agent_branch_from_worktree_path() {
  local wt_path="$1"
  local wt_name=""
  local suffix=""
  local candidate=""

  if [[ "$wt_path" != "${agent_worktree_root}"/* ]]; then
    return 1
  fi

  wt_name="$(basename "$wt_path")"
  if [[ "$wt_name" != agent__* ]]; then
    return 1
  fi

  suffix="${wt_name#agent__}"
  candidate="agent/${suffix//__//}"
  if [[ ! "$candidate" =~ ^agent/[A-Za-z0-9._/-]+$ ]]; then
    return 1
  fi
  printf '%s' "$candidate"
}

if [[ -z "$SOURCE_BRANCH" ]]; then
  SOURCE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
fi

if [[ "$SOURCE_BRANCH_EXPLICIT" -eq 0 && "$SOURCE_BRANCH" == "HEAD" ]]; then
  detached_hint_branch=""
  detached_recover_cmd=""
  detached_recover_branch=""
  detached_conflicts="$(git -C "$current_worktree" diff --name-only --diff-filter=U 2>/dev/null || true)"

  detached_hint_branch="$(infer_agent_branch_from_worktree_path "$current_worktree" || true)"
  if [[ -n "$detached_hint_branch" ]] && git -C "$repo_root" show-ref --verify --quiet "refs/heads/${detached_hint_branch}"; then
    detached_recover_cmd="git -C \"$current_worktree\" checkout \"$detached_hint_branch\""
  elif [[ -n "$detached_hint_branch" ]]; then
    detached_recover_cmd="git -C \"$current_worktree\" checkout -b \"$detached_hint_branch\""
  else
    detached_recover_branch="agent/recover/detached-$(date +%Y%m%d-%H%M%S)"
    detached_recover_cmd="git -C \"$current_worktree\" checkout -b \"$detached_recover_branch\""
  fi

  echo "[agent-branch-finish] Current worktree is in detached HEAD; finish requires a branch context." >&2
  if [[ -n "$detached_conflicts" ]]; then
    echo "[agent-branch-finish] Unmerged files detected in this detached worktree:" >&2
    while IFS= read -r file; do
      [[ -n "$file" ]] && echo "  - ${file}" >&2
    done <<< "$detached_conflicts"
  fi
  echo "[agent-branch-finish] Recover branch context with: ${detached_recover_cmd}" >&2
  if [[ -n "$detached_hint_branch" ]]; then
    echo "[agent-branch-finish] Then resolve/commit and rerun finish with: bash scripts/agent-branch-finish.sh --branch \"${detached_hint_branch}\" --base dev --via-pr --wait-for-merge --cleanup" >&2
  else
    echo "[agent-branch-finish] Then resolve/commit and rerun finish with --branch <your-recovered-agent-branch>." >&2
  fi
  exit 1
fi

if [[ "$BASE_BRANCH_EXPLICIT" -eq 1 && -z "$BASE_BRANCH" ]]; then
  echo "[agent-branch-finish] --base requires a non-empty branch name." >&2
  exit 1
fi

if [[ "$BASE_BRANCH_EXPLICIT" -eq 0 ]]; then
  configured_base="$(git -C "$repo_root" config --get multiagent.baseBranch || true)"
  if [[ -n "$configured_base" ]]; then
    BASE_BRANCH="$configured_base"
  fi
fi

if [[ -z "$BASE_BRANCH" ]]; then
  branch_stored_base="$(git -C "$repo_root" config --get "branch.${SOURCE_BRANCH}.musafetyBase" || true)"
  if [[ -n "$branch_stored_base" ]]; then
    BASE_BRANCH="$branch_stored_base"
  fi
fi

if [[ -z "$BASE_BRANCH" ]]; then
  source_upstream="$(git -C "$repo_root" for-each-ref --count=1 --format='%(upstream:short)' "refs/heads/${SOURCE_BRANCH}" || true)"
  source_upstream="${source_upstream:-}"
  if [[ "$source_upstream" == */* ]]; then
    BASE_BRANCH="${source_upstream#*/}"
  fi
fi

if [[ -z "$BASE_BRANCH" ]]; then
  current_branch="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -n "$current_branch" && "$current_branch" != "HEAD" && "$current_branch" != "$SOURCE_BRANCH" ]]; then
    BASE_BRANCH="$current_branch"
  fi
fi

if [[ -z "$BASE_BRANCH" ]]; then
  BASE_BRANCH="dev"
fi

if [[ "$SOURCE_BRANCH" == "$BASE_BRANCH" ]]; then
  echo "[agent-branch-finish] Source branch and base branch are both '$BASE_BRANCH'." >&2
  echo "[agent-branch-finish] Switch to your agent branch or pass --branch <agent-branch>." >&2
  exit 1
fi

cleanup_mandatory=0
if [[ "$ENFORCE_AGENT_CLEANUP" -eq 1 && "$PUSH_ENABLED" -eq 1 && "$SOURCE_BRANCH" =~ ^agent/ ]]; then
  cleanup_mandatory=1
fi

if [[ "$cleanup_mandatory" -eq 1 ]]; then
  if [[ "$CLEANUP_AFTER_MERGE" -ne 1 ]]; then
    if [[ "$NO_CLEANUP_REQUESTED" -eq 1 ]]; then
      echo "[agent-branch-finish] Ignoring --no-cleanup for '${SOURCE_BRANCH}': cleanup is mandatory for merged agent branches." >&2
    else
      echo "[agent-branch-finish] Enforcing mandatory cleanup for merged agent branch '${SOURCE_BRANCH}'." >&2
    fi
    CLEANUP_AFTER_MERGE=1
  fi
  if [[ "$DELETE_REMOTE_BRANCH" -ne 1 ]]; then
    if [[ "$DELETE_REMOTE_BRANCH_EXPLICIT" -eq 1 ]]; then
      echo "[agent-branch-finish] Ignoring --keep-remote-branch for '${SOURCE_BRANCH}': remote branch deletion is required by cleanup policy." >&2
    fi
    DELETE_REMOTE_BRANCH=1
  fi
fi

if [[ "$CLEANUP_AFTER_MERGE" -eq 1 && "$DELETE_REMOTE_BRANCH_EXPLICIT" -eq 0 ]]; then
  DELETE_REMOTE_BRANCH=1
fi

if ! git -C "$repo_root" show-ref --verify --quiet "refs/heads/${SOURCE_BRANCH}"; then
  echo "[agent-branch-finish] Local source branch does not exist: ${SOURCE_BRANCH}" >&2
  exit 1
fi

get_worktree_for_branch() {
  local branch="$1"
  git -C "$repo_root" worktree list --porcelain | awk -v target="refs/heads/${branch}" '
    $1 == "worktree" { wt = $2 }
    $1 == "branch" && $2 == target { print wt; exit }
  '
}

is_clean_worktree() {
  local wt="$1"
  git -C "$wt" diff --quiet -- . ":(exclude).omx/state/agent-file-locks.json" \
    && git -C "$wt" diff --cached --quiet -- . ":(exclude).omx/state/agent-file-locks.json"
}

validate_openspec_tasks_gate() {
  local branch="$1"
  local branch_root="$2"
  local helper_base=""

  if [[ ! "$branch" =~ ^agent/ ]]; then
    return 0
  fi

  helper_base="$(git -C "$repo_root" config --get "branch.${branch}.musafetyBase" || true)"
  if [[ "$BASE_BRANCH" == agent/* ]] || [[ "$helper_base" == agent/* ]]; then
    if [[ -z "$helper_base" && "$BASE_BRANCH" == agent/* ]]; then
      helper_base="$BASE_BRANCH"
    fi
    echo "[agent-branch-finish] Skipping OpenSpec tasks gate for helper branch '${branch}' (base '${helper_base}')." >&2
    return 0
  fi

  local change_slug="${branch//\//-}"
  local tasks_file="${branch_root}/openspec/changes/${change_slug}/tasks.md"
  local use_collaboration_flow=0
  local cleanup_step="4"
  local required_section_labels=(
    "## 1. Specification"
    "## 2. Implementation"
    "## 3. Verification"
  )
  local required_section_patterns=(
    '^## 1\. Specification([[:space:]].*)?$'
    '^## 2\. Implementation([[:space:]].*)?$'
    '^## 3\. Verification([[:space:]].*)?$'
  )

  if [[ ! -f "$tasks_file" ]]; then
    echo "[agent-branch-finish] OpenSpec tasks gate failed for '${branch}'." >&2
    echo "[agent-branch-finish] Missing required file: openspec/changes/${change_slug}/tasks.md" >&2
    echo "[agent-branch-finish] Finish is blocked until the checklist file exists and is fully updated." >&2
    exit 1
  fi

  if grep -Eq '^## 4\. Collaboration([[:space:]].*)?$' "$tasks_file" && grep -Eq '^## 5\. Cleanup([[:space:]].*)?$' "$tasks_file"; then
    use_collaboration_flow=1
    cleanup_step="5"
    required_section_labels+=("## 4. Collaboration" "## 5. Cleanup")
    required_section_patterns+=('^## 4\. Collaboration([[:space:]].*)?$' '^## 5\. Cleanup([[:space:]].*)?$')
  else
    required_section_labels+=("## 4. Cleanup")
    required_section_patterns+=('^## 4\. Cleanup([[:space:]].*)?$')
  fi

  local missing_section=0
  local i
  for i in "${!required_section_labels[@]}"; do
    local section_label="${required_section_labels[$i]}"
    local section_pattern="${required_section_patterns[$i]}"
    if ! grep -Eq "$section_pattern" "$tasks_file"; then
      missing_section=1
      echo "[agent-branch-finish] OpenSpec tasks gate failed for '${branch}'." >&2
      echo "[agent-branch-finish] Missing required section in ${tasks_file}: ${section_label}" >&2
    fi
  done
  if [[ "$missing_section" -eq 1 ]]; then
    echo "[agent-branch-finish] Finish is blocked until all required checklist sections are present." >&2
    exit 1
  fi

  if ! grep -Eq "^[[:space:]]*-[[:space:]]*\\[[ xX]\\][[:space:]]*${cleanup_step}\\.1\\b" "$tasks_file"; then
    echo "[agent-branch-finish] OpenSpec tasks gate failed for '${branch}'." >&2
    echo "[agent-branch-finish] Missing required cleanup readiness item in ${tasks_file}: ${cleanup_step}.1" >&2
    echo "[agent-branch-finish] Finish is blocked until cleanup item ${cleanup_step}.1 is present." >&2
    exit 1
  fi

  local gate_unchecked
  gate_unchecked="$(awk -v collab_flow="$use_collaboration_flow" '
    BEGIN { scope = "" }
    /^## 1\. Specification([[:space:]].*)?$/ { scope = "spec"; next }
    /^## 2\. Implementation([[:space:]].*)?$/ { scope = "impl"; next }
    /^## 3\. Verification([[:space:]].*)?$/ { scope = "verify"; next }
    collab_flow == 1 && /^## 4\. Collaboration([[:space:]].*)?$/ { scope = "collaboration"; next }
    collab_flow == 1 && /^## 5\. Cleanup([[:space:]].*)?$/ { scope = "cleanup"; next }
    collab_flow != 1 && /^## 4\. Cleanup([[:space:]].*)?$/ { scope = "cleanup"; next }
    /^## / { scope = "" }

    scope ~ /^(spec|impl|verify)$/ && /^[[:space:]]*-[[:space:]]*\[ \]/ {
      print NR ":" $0
      next
    }
  ' "$tasks_file")"

  if [[ -n "$gate_unchecked" ]]; then
    echo "[agent-branch-finish] OpenSpec tasks gate failed for '${branch}'." >&2
    echo "[agent-branch-finish] Unchecked checklist items remain in ${tasks_file}:" >&2
    while IFS= read -r line; do
      [[ -n "$line" ]] && echo "  - ${line}" >&2
    done <<< "$gate_unchecked"
    echo "[agent-branch-finish] Finish is blocked until all items in sections 1-3 are marked [x]." >&2
    exit 1
  fi
}

source_worktree="$(get_worktree_for_branch "$SOURCE_BRANCH")"
created_source_probe=0
source_probe_path=""

if [[ -z "$source_worktree" ]]; then
  source_probe_path="${agent_worktree_root}/__source-probe-${SOURCE_BRANCH//\//__}-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$(dirname "$source_probe_path")"
  git -C "$repo_root" worktree add "$source_probe_path" "$SOURCE_BRANCH" >/dev/null
  source_worktree="$source_probe_path"
  created_source_probe=1
fi

validate_openspec_tasks_gate "$SOURCE_BRANCH" "$source_worktree"

if ! is_clean_worktree "$source_worktree"; then
  echo "[agent-branch-finish] Source worktree is not clean for '${SOURCE_BRANCH}': ${source_worktree}" >&2
  echo "[agent-branch-finish] Commit/stash changes on the source branch before finishing." >&2
  exit 1
fi

start_ref="$BASE_BRANCH"
if git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/${BASE_BRANCH}"; then
  git -C "$repo_root" fetch origin "$BASE_BRANCH" --quiet
  start_ref="origin/${BASE_BRANCH}"
fi

require_before_finish_raw="$(git -C "$repo_root" config --get multiagent.sync.requireBeforeFinish || true)"
if [[ -z "$require_before_finish_raw" ]]; then
  require_before_finish_raw="true"
fi
require_before_finish="$(printf '%s' "$require_before_finish_raw" | tr '[:upper:]' '[:lower:]')"
should_require_sync=0
case "$require_before_finish" in
  1|true|yes|on) should_require_sync=1 ;;
  0|false|no|off) should_require_sync=0 ;;
  *) should_require_sync=1 ;;
esac

if [[ "$should_require_sync" -eq 1 ]] && git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/${BASE_BRANCH}"; then
  behind_count="$(git -C "$repo_root" rev-list --left-right --count "${SOURCE_BRANCH}...origin/${BASE_BRANCH}" 2>/dev/null | awk '{print $2}')"
  behind_count="${behind_count:-0}"
  if [[ "$behind_count" -gt 0 ]]; then
    echo "[agent-sync-guard] Branch '${SOURCE_BRANCH}' is behind origin/${BASE_BRANCH} by ${behind_count} commit(s)." >&2
    echo "[agent-sync-guard] Auto-syncing '${SOURCE_BRANCH}' onto origin/${BASE_BRANCH} before finish..." >&2
    if ! git -C "$source_worktree" rebase "origin/${BASE_BRANCH}"; then
      git_dir="$(git -C "$source_worktree" rev-parse --git-dir)"
      rebase_active=0
      if [[ -e "${git_dir}/rebase-merge" || -e "${git_dir}/rebase-apply" ]]; then
        rebase_active=1
      fi

      echo "[agent-sync-guard] Auto-sync failed while rebasing '${SOURCE_BRANCH}' onto origin/${BASE_BRANCH}." >&2
      if [[ "$rebase_active" -eq 1 ]]; then
        echo "[agent-sync-guard] Resolve conflicts, then run: git -C \"$source_worktree\" rebase --continue" >&2
        echo "[agent-sync-guard] Or abort: git -C \"$source_worktree\" rebase --abort" >&2
      fi
      exit 1
    fi

    behind_after="$(git -C "$repo_root" rev-list --left-right --count "${SOURCE_BRANCH}...origin/${BASE_BRANCH}" 2>/dev/null | awk '{print $2}')"
    behind_after="${behind_after:-0}"
    echo "[agent-sync-guard] Auto-sync complete (behind now: ${behind_after})." >&2
  fi
fi

integration_worktree=""
integration_branch=""
use_integration_worktree=1
if [[ "$MERGE_MODE" == "pr" && "$PUSH_ENABLED" -eq 1 ]]; then
  # PR mode merges by pushing the source branch and letting GitHub merge.
  # Skip creating temporary local integration worktrees in this lane.
  use_integration_worktree=0
fi

if [[ "$use_integration_worktree" -eq 1 ]]; then
  integration_worktree="${agent_worktree_root}/__integrate-${BASE_BRANCH//\//__}-$(date +%Y%m%d-%H%M%S)"
  integration_branch="__agent_integrate_${BASE_BRANCH//\//_}_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$(dirname "$integration_worktree")"
  git -C "$repo_root" worktree add "$integration_worktree" "$start_ref" >/dev/null
  git -C "$integration_worktree" checkout -b "$integration_branch" >/dev/null
else
  integration_worktree=""
  integration_branch=""
fi

transient_worktrees_released=0

release_transient_worktrees() {
  if [[ "$transient_worktrees_released" -eq 1 ]]; then
    return
  fi
  if [[ -d "$integration_worktree" ]]; then
    git -C "$repo_root" worktree remove "$integration_worktree" --force >/dev/null 2>&1 || true
  fi
  if git -C "$repo_root" show-ref --verify --quiet "refs/heads/${integration_branch}"; then
    local integration_branch_worktree=""
    integration_branch_worktree="$(get_worktree_for_branch "$integration_branch" || true)"
    if [[ -z "$integration_branch_worktree" ]]; then
      git -C "$repo_root" branch -D "$integration_branch" >/dev/null 2>&1 || true
    fi
  fi
  if [[ "$created_source_probe" -eq 1 && -n "$source_probe_path" && -d "$source_probe_path" ]]; then
    git -C "$repo_root" worktree remove "$source_probe_path" --force >/dev/null 2>&1 || true
  fi
  if [[ "$created_source_probe" -eq 1 ]]; then
    source_worktree="$repo_root"
    created_source_probe=0
    source_probe_path=""
  fi
  transient_worktrees_released=1
}

cleanup() {
  release_transient_worktrees
}

handle_interrupt() {
  cleanup
  exit 130
}

trap cleanup EXIT
trap handle_interrupt INT TERM HUP
merge_gate_json=""

run_merge_quality_gate() {
  if [[ ! -x "${repo_root}/scripts/omx-merge-gate.sh" ]]; then
    echo "[agent-branch-finish] Required merge-gate helper is missing: scripts/omx-merge-gate.sh" >&2
    echo "[agent-branch-finish] Repair with: gx doctor (or restore the script) before finishing." >&2
    return 1
  fi

  local gate_args=(--branch "$SOURCE_BRANCH" --base "$BASE_BRANCH" --output-dir "${repo_root}/.omx/state/merge-gates")
  if [[ -n "$PR_REF" ]]; then
    gate_args+=(--pr "$PR_REF")
  fi
  if [[ -n "$GH_REPO_REF" ]]; then
    gate_args+=(--repo "$GH_REPO_REF")
  fi
  if [[ "$REQUIRE_REMOTE_GATES" -eq 1 ]]; then
    gate_args+=(--require-remote)
  fi

  local gate_output=""
  if gate_output="$(bash "${repo_root}/scripts/omx-merge-gate.sh" "${gate_args[@]}" 2>&1)"; then
    printf '%s\n' "$gate_output"
    merge_gate_json="$(printf '%s\n' "$gate_output" | sed -n 's/^Merge gate JSON: //p' | tail -n1)"
    return 0
  fi

  merge_gate_json="$(printf '%s\n' "$gate_output" | sed -n 's/^Merge gate JSON: //p' | tail -n1)"
  echo "$gate_output" >&2
  echo "[agent-branch-finish] Merge-quality gate failed. Resolve blockers before finishing." >&2
  if [[ -n "$merge_gate_json" ]]; then
    echo "[agent-branch-finish] Gate details: ${merge_gate_json}" >&2
  fi
  return 1
}

if git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/${BASE_BRANCH}"; then
  git -C "$source_worktree" fetch origin "$BASE_BRANCH" --quiet

  if ! git -C "$source_worktree" merge --no-commit --no-ff "origin/${BASE_BRANCH}" >/dev/null 2>&1; then
    conflict_files="$(git -C "$source_worktree" diff --name-only --diff-filter=U || true)"
    git -C "$source_worktree" merge --abort >/dev/null 2>&1 || true

    echo "[agent-branch-finish] Preflight conflict detected between '${SOURCE_BRANCH}' and latest origin/${BASE_BRANCH}." >&2
    if [[ -n "$conflict_files" ]]; then
      echo "[agent-branch-finish] Conflicting files:" >&2
      while IFS= read -r file; do
        [[ -n "$file" ]] && echo "  - ${file}" >&2
      done <<< "$conflict_files"
    fi
    echo "[agent-branch-finish] Rebase/merge '${BASE_BRANCH}' into '${SOURCE_BRANCH}' and resolve conflicts before finishing." >&2
    exit 1
  fi

  git -C "$source_worktree" merge --abort >/dev/null 2>&1 || true
fi

if ! run_merge_quality_gate; then
  exit 1
fi

if [[ "$use_integration_worktree" -eq 1 ]]; then
  if ! git -C "$integration_worktree" merge --no-ff --no-edit "$SOURCE_BRANCH"; then
    echo "[agent-branch-finish] Merge conflict detected while merging '${SOURCE_BRANCH}' into '${BASE_BRANCH}'." >&2
    git -C "$integration_worktree" merge --abort >/dev/null 2>&1 || true
    exit 1
  fi
fi

merge_completed=1
merge_status="direct"
direct_push_error=""
pr_url=""

is_local_branch_delete_error() {
  local output="$1"
  if [[ "$output" != *"failed to delete local branch"* ]]; then
    return 1
  fi
  if [[ "$output" == *"cannot delete branch"* ]] || [[ "$output" == *"used by worktree"* ]]; then
    return 0
  fi
  return 1
}

delete_local_source_branch() {
  local branch="$1"
  local base_branch="$2"
  local delete_output=""
  local branch_upstream=""
  local safe_delete_ref=""
  local safe_to_force_delete=0

  branch_upstream="$(git -C "$repo_root" for-each-ref --count=1 --format='%(upstream:short)' "refs/heads/${branch}" || true)"
  branch_upstream="${branch_upstream:-}"
  if git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/${base_branch}"; then
    safe_delete_ref="origin/${base_branch}"
  elif git -C "$repo_root" show-ref --verify --quiet "refs/heads/${base_branch}"; then
    safe_delete_ref="${base_branch}"
  fi
  if [[ -n "$safe_delete_ref" ]] && git -C "$repo_root" merge-base --is-ancestor "$branch" "$safe_delete_ref" >/dev/null 2>&1; then
    safe_to_force_delete=1
  fi

  if delete_output="$(git -C "$repo_root" branch -d "$branch" 2>&1)"; then
    return 0
  fi

  if [[ "$branch_upstream" == "origin/${branch}" ]]; then
    git -C "$repo_root" branch --unset-upstream "$branch" >/dev/null 2>&1 || true
    if git -C "$repo_root" branch -d "$branch" >/dev/null 2>&1; then
      echo "[agent-branch-finish] Cleared upstream tracking for '${branch}' to complete local merged-branch cleanup." >&2
      return 0
    fi
  fi

  if [[ "$safe_to_force_delete" -eq 1 ]]; then
    if git -C "$repo_root" branch -D "$branch" >/dev/null 2>&1; then
      echo "[agent-branch-finish] Deleted '${branch}' with forced local cleanup after verifying merge ancestry in '${safe_delete_ref}'." >&2
      return 0
    fi
  fi

  echo "[agent-branch-finish] Failed to delete local branch '${branch}' after merge." >&2
  echo "$delete_output" >&2
  return 1
}

read_pr_state() {
  local preferred_ref="${1:-}"
  local state_line=""
  local refs_to_try=()
  local candidate_ref

  if [[ -n "$preferred_ref" ]]; then
    refs_to_try+=("$preferred_ref")
  fi
  if [[ -n "$pr_url" && "$pr_url" != "$preferred_ref" ]]; then
    refs_to_try+=("$pr_url")
  fi
  if [[ "$SOURCE_BRANCH" != "$preferred_ref" ]]; then
    refs_to_try+=("$SOURCE_BRANCH")
  fi

  for candidate_ref in "${refs_to_try[@]}"; do
    state_line="$("$GH_BIN" pr view "$candidate_ref" --json state,mergedAt,url --jq '[.state, (.mergedAt // ""), (.url // "")] | join("\u001f")' 2>/dev/null || true)"
    if [[ -z "$state_line" ]]; then
      continue
    fi

    local parsed_state=""
    local parsed_merged_at=""
    local parsed_url=""
    IFS=$'\x1f' read -r parsed_state parsed_merged_at parsed_url <<< "$state_line"
    PR_STATE="$parsed_state"
    PR_MERGED_AT="$parsed_merged_at"
    if [[ -n "$parsed_url" ]]; then
      pr_url="$parsed_url"
    fi
    return 0
  done

  return 1
}

wait_for_pr_merge() {
  # Integration/source-probe worktrees are no longer needed during GH check wait loops.
  # Release them early so long waits do not leave temporary repos visible in Source Control.
  release_transient_worktrees
  local deadline
  deadline=$(( $(date +%s) + WAIT_TIMEOUT_SECONDS ))
  local wait_notice_printed=0
  local merge_output=""

  while true; do
    if merge_output="$("$GH_BIN" pr merge "$SOURCE_BRANCH" --squash --delete-branch 2>&1)"; then
      return 0
    fi
    if is_local_branch_delete_error "$merge_output"; then
      echo "[agent-branch-finish] PR merged but gh could not delete the local branch (active worktree); continuing local cleanup." >&2
      return 0
    fi

    PR_STATE=""
    PR_MERGED_AT=""
    if read_pr_state; then
      if [[ "$PR_STATE" == "MERGED" || -n "$PR_MERGED_AT" ]]; then
        return 0
      fi
      if [[ "$PR_STATE" == "CLOSED" ]]; then
        echo "[agent-branch-finish] PR closed without merge; cannot continue auto-finish." >&2
        if [[ -n "$pr_url" ]]; then
          echo "[agent-branch-finish] PR: ${pr_url}" >&2
        fi
        if [[ -n "$merge_output" ]]; then
          echo "$merge_output" >&2
        fi
        return 1
      fi
    fi

    if [[ "$wait_notice_printed" -eq 0 ]]; then
      echo "[agent-branch-finish] Waiting for required checks/reviews, then retrying merge automatically (timeout ${WAIT_TIMEOUT_SECONDS}s)." >&2
      if [[ -n "$pr_url" ]]; then
        echo "[agent-branch-finish] PR: ${pr_url}" >&2
      fi
      wait_notice_printed=1
    fi

    if (( $(date +%s) >= deadline )); then
      echo "[agent-branch-finish] Timed out waiting for PR merge after ${WAIT_TIMEOUT_SECONDS}s." >&2
      if [[ -n "$merge_output" ]]; then
        echo "$merge_output" >&2
      fi
      return 2
    fi

    sleep "$WAIT_POLL_SECONDS"
  done
}

run_pr_flow() {
  if ! command -v "$GH_BIN" >/dev/null 2>&1; then
    echo "[agent-branch-finish] PR fallback requested but GitHub CLI not found: ${GH_BIN}" >&2
    return 1
  fi

  git -C "$source_worktree" push -u origin "$SOURCE_BRANCH"

  pr_title="$(git -C "$repo_root" log -1 --pretty=%s "$SOURCE_BRANCH" 2>/dev/null || true)"
  if [[ -z "$pr_title" ]]; then
    pr_title="Merge ${SOURCE_BRANCH} into ${BASE_BRANCH}"
  fi
  pr_body="Automated by scripts/agent-branch-finish.sh (PR flow)."

  "$GH_BIN" pr create \
    --base "$BASE_BRANCH" \
    --head "$SOURCE_BRANCH" \
    --title "$pr_title" \
    --body "$pr_body" >/dev/null 2>&1 || true

  pr_url="$("$GH_BIN" pr view "$SOURCE_BRANCH" --json url --jq '.url' 2>/dev/null || true)"

  merge_output=""
  if merge_output="$("$GH_BIN" pr merge "$SOURCE_BRANCH" --squash --delete-branch 2>&1)"; then
    return 0
  fi
  if is_local_branch_delete_error "$merge_output"; then
    echo "[agent-branch-finish] PR merged but gh could not delete the local branch (active worktree); continuing local cleanup." >&2
    return 0
  fi
  PR_STATE=""
  PR_MERGED_AT=""
  if read_pr_state "$pr_url"; then
    if [[ "$PR_STATE" == "MERGED" || -n "$PR_MERGED_AT" ]]; then
      return 0
    fi
  fi

  if [[ "$WAIT_FOR_MERGE" -eq 1 ]]; then
    wait_for_pr_merge
    return $?
  fi

  auto_output=""
  if auto_output="$("$GH_BIN" pr merge "$SOURCE_BRANCH" --squash --delete-branch --auto 2>&1)"; then
    echo "[agent-branch-finish] PR auto-merge enabled; waiting for required checks/reviews." >&2
    return 2
  fi

  if [[ -n "$merge_output" ]]; then
    echo "[agent-branch-finish] PR merge not completed yet; leaving PR open." >&2
    echo "${merge_output}" >&2
  fi
  if [[ -n "$auto_output" ]]; then
    echo "${auto_output}" >&2
  fi
  return 2
}

capture_post_merge_learning() {
  if [[ ! -x "${repo_root}/scripts/omx-learning-capture.sh" ]]; then
    return 0
  fi

  local learning_args=(
    --branch "$SOURCE_BRANCH"
    --base "$BASE_BRANCH"
    --outcome "merged-${merge_status}"
    --summary "Merged ${SOURCE_BRANCH} into ${BASE_BRANCH} via ${merge_status} flow."
    --output-dir "${repo_root}/.omx/learning"
  )
  if [[ -n "$PR_REF" ]]; then
    learning_args+=(--pr "$PR_REF")
  elif [[ -n "$pr_url" ]]; then
    learning_args+=(--pr "$pr_url")
  fi
  if [[ -n "$GH_REPO_REF" ]]; then
    learning_args+=(--repo "$GH_REPO_REF")
  fi
  if [[ -n "$merge_gate_json" ]]; then
    learning_args+=(--merge-gate-file "$merge_gate_json")
  fi
  if [[ -f "${source_worktree}/.omx/context/github/sandbox-startup-latest.json" ]]; then
    learning_args+=(--context-file "${source_worktree}/.omx/context/github/sandbox-startup-latest.json")
  fi

  local learning_output=""
  if learning_output="$(bash "${repo_root}/scripts/omx-learning-capture.sh" "${learning_args[@]}" 2>&1)"; then
    printf '%s\n' "$learning_output"
  else
    echo "[agent-branch-finish] Warning: post-merge learning capture failed." >&2
    printf '%s\n' "$learning_output" >&2
  fi
}

if [[ "$PUSH_ENABLED" -eq 1 ]]; then
  if [[ "$MERGE_MODE" != "pr" ]]; then
    if ! direct_push_output="$(git -C "$integration_worktree" push origin "HEAD:${BASE_BRANCH}" 2>&1)"; then
      direct_push_error="$direct_push_output"
      merge_completed=0
    fi
  else
    merge_completed=0
  fi

  if [[ "$merge_completed" -eq 0 ]]; then
    if [[ "$MERGE_MODE" == "direct" ]]; then
      echo "[agent-branch-finish] Direct push/merge failed in --direct-only mode." >&2
      if [[ -n "$direct_push_error" ]]; then
        echo "$direct_push_error" >&2
      fi
      exit 1
    fi

    if run_pr_flow; then
      merge_completed=1
      merge_status="pr"
    else
      pr_exit=$?
      if [[ "$pr_exit" -eq 2 ]]; then
        echo "[agent-branch-finish] PR flow created/updated branch '${SOURCE_BRANCH}' against '${BASE_BRANCH}'." >&2
        if [[ -n "$pr_url" ]]; then
          echo "[agent-branch-finish] PR: ${pr_url}" >&2
        fi
        if [[ "$WAIT_FOR_MERGE" -eq 1 ]]; then
          echo "[agent-branch-finish] Merge did not complete within wait window; keeping branch open." >&2
          exit 1
        fi
        echo "[agent-branch-finish] Merge pending review/check policy. Branch cleanup skipped for now." >&2
        exit 0
      fi
      echo "[agent-branch-finish] PR flow failed." >&2
      if [[ -n "$direct_push_error" ]]; then
        echo "[agent-branch-finish] Direct push failure details:" >&2
        echo "$direct_push_error" >&2
      fi
      exit 1
    fi
  fi
fi

if [[ "$merge_completed" -eq 1 ]]; then
  capture_post_merge_learning
fi

if [[ -x "${repo_root}/scripts/agent-file-locks.py" ]]; then
  python3 "${repo_root}/scripts/agent-file-locks.py" release --branch "$SOURCE_BRANCH" >/dev/null 2>&1 || true
fi

base_worktree="$(get_worktree_for_branch "$BASE_BRANCH")"
if [[ -n "$base_worktree" ]] && is_clean_worktree "$base_worktree" && [[ "$PUSH_ENABLED" -eq 1 ]]; then
  git -C "$base_worktree" pull --ff-only origin "$BASE_BRANCH" >/dev/null 2>&1 || true
fi

if [[ "$CLEANUP_AFTER_MERGE" -eq 1 ]]; then
  cleanup_incomplete=0
  cleanup_remaining_messages=()

  if [[ "$source_worktree" == "$repo_root" ]]; then
    if is_clean_worktree "$source_worktree"; then
      switched_to_base=0
      if git -C "$source_worktree" checkout "$BASE_BRANCH" >/dev/null 2>&1; then
        switched_to_base=1
      else
        git -C "$source_worktree" checkout --detach >/dev/null 2>&1 || true
      fi
      if [[ "$switched_to_base" -eq 1 && "$PUSH_ENABLED" -eq 1 ]] && git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/${BASE_BRANCH}"; then
        git -C "$source_worktree" pull --ff-only origin "$BASE_BRANCH" >/dev/null 2>&1 || true
      fi
    fi
  elif [[ "$source_worktree" == "$current_worktree" && "$source_worktree" == "${agent_worktree_root}"/* ]]; then
    git -C "$source_worktree" checkout --detach >/dev/null 2>&1 || true
  fi

  if [[ "$source_worktree" != "$current_worktree" && "$source_worktree" == "${agent_worktree_root}"/* ]]; then
    git -C "$repo_root" worktree remove "$source_worktree" --force >/dev/null 2>&1 || true
  fi

  delete_local_source_branch "$SOURCE_BRANCH" "$BASE_BRANCH"

  if [[ "$PUSH_ENABLED" -eq 1 && "$DELETE_REMOTE_BRANCH" -eq 1 ]]; then
    if git -C "$repo_root" ls-remote --exit-code --heads origin "$SOURCE_BRANCH" >/dev/null 2>&1; then
      git -C "$repo_root" push origin --delete "$SOURCE_BRANCH"
    fi
  fi

  if [[ -x "${repo_root}/scripts/agent-worktree-prune.sh" ]]; then
    prune_args=(--base "$BASE_BRANCH" --only-dirty-worktrees --delete-branches)
    if [[ "$DELETE_REMOTE_BRANCH" -eq 1 ]]; then
      prune_args+=(--delete-remote-branches)
    fi
    if ! bash "${repo_root}/scripts/agent-worktree-prune.sh" "${prune_args[@]}"; then
      echo "[agent-branch-finish] Warning: automatic worktree prune failed." >&2
      echo "[agent-branch-finish] You can run manual cleanup: bash scripts/agent-worktree-prune.sh --base ${BASE_BRANCH} --delete-branches" >&2
    fi
  fi

  if git -C "$repo_root" show-ref --verify --quiet "refs/heads/${SOURCE_BRANCH}"; then
    cleanup_incomplete=1
    cleanup_remaining_messages+=("local branch still exists: ${SOURCE_BRANCH}")
  fi

  if [[ "$PUSH_ENABLED" -eq 1 && "$DELETE_REMOTE_BRANCH" -eq 1 ]]; then
    if git -C "$repo_root" ls-remote --exit-code --heads origin "$SOURCE_BRANCH" >/dev/null 2>&1; then
      cleanup_incomplete=1
      cleanup_remaining_messages+=("remote branch still exists: origin/${SOURCE_BRANCH}")
    fi
  fi

  if [[ "$source_worktree" == "${agent_worktree_root}"/* && -d "$source_worktree" ]]; then
    cleanup_incomplete=1
    cleanup_remaining_messages+=("agent worktree path still exists: ${source_worktree}")
  fi

  if [[ "$cleanup_incomplete" -eq 1 ]]; then
    echo "[agent-branch-finish] Merged '${SOURCE_BRANCH}' into '${BASE_BRANCH}' via ${merge_status} flow, but mandatory cleanup is still incomplete." >&2
    for cleanup_message in "${cleanup_remaining_messages[@]}"; do
      echo "[agent-branch-finish] Remaining cleanup: ${cleanup_message}" >&2
    done
    if [[ "$source_worktree" == "$current_worktree" && "$source_worktree" == "${agent_worktree_root}"/* ]]; then
      echo "[agent-branch-finish] Leave this active sandbox directory, then rerun: bash scripts/agent-branch-finish.sh --branch ${SOURCE_BRANCH} --base ${BASE_BRANCH} --via-pr --wait-for-merge --cleanup" >&2
    fi
    exit 1
  fi

  echo "[agent-branch-finish] Merged '${SOURCE_BRANCH}' into '${BASE_BRANCH}' via ${merge_status} flow and cleaned source branch/worktree."
else
  if [[ -x "${repo_root}/scripts/agent-worktree-prune.sh" ]]; then
    if ! bash "${repo_root}/scripts/agent-worktree-prune.sh" --base "$BASE_BRANCH"; then
      echo "[agent-branch-finish] Warning: temporary worktree prune failed." >&2
    fi
  fi

  echo "[agent-branch-finish] Merged '${SOURCE_BRANCH}' into '${BASE_BRANCH}' via ${merge_status} flow and kept source branch/worktree."
  echo "[agent-branch-finish] Cleanup later with: bash scripts/agent-worktree-prune.sh --base ${BASE_BRANCH} --delete-branches --delete-remote-branches"
fi
