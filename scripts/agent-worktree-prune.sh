#!/usr/bin/env bash
set -euo pipefail

BASE_BRANCH="${MUSAFETY_BASE_BRANCH:-}"
BASE_BRANCH_EXPLICIT=0
DRY_RUN=0
FORCE_DIRTY=0
DELETE_BRANCHES=0
DELETE_REMOTE_BRANCHES=0
ONLY_DIRTY_WORKTREES=0
TARGET_BRANCH=""
IDLE_MINUTES=0
NOW_EPOCH_RAW="${MUSAFETY_PRUNE_NOW_EPOCH:-}"
IDLE_SECONDS=0
NOW_EPOCH=0

if [[ -n "$BASE_BRANCH" ]]; then
  BASE_BRANCH_EXPLICIT=1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      BASE_BRANCH="${2:-}"
      BASE_BRANCH_EXPLICIT=1
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force-dirty)
      FORCE_DIRTY=1
      shift
      ;;
    --delete-branches)
      DELETE_BRANCHES=1
      shift
      ;;
    --delete-remote-branches)
      DELETE_REMOTE_BRANCHES=1
      shift
      ;;
    --only-dirty-worktrees)
      ONLY_DIRTY_WORKTREES=1
      shift
      ;;
    --branch)
      TARGET_BRANCH="${2:-}"
      shift 2
      ;;
    --idle-minutes)
      IDLE_MINUTES="${2:-}"
      shift 2
      ;;
    *)
      echo "[agent-worktree-prune] Unknown argument: $1" >&2
      echo "Usage: $0 [--base <branch>] [--dry-run] [--force-dirty] [--delete-branches] [--delete-remote-branches] [--only-dirty-worktrees] [--branch <agent/...|__agent_integrate_*|__source-probe-*>]" >&2
      exit 1
      ;;
  esac
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[agent-worktree-prune] Not inside a git repository." >&2
  exit 1
fi

current_worktree_root="$(git rev-parse --show-toplevel)"
common_git_dir_raw="$(git -C "$current_worktree_root" rev-parse --git-common-dir)"
if [[ "$common_git_dir_raw" == /* ]]; then
  repo_common_dir="$common_git_dir_raw"
else
  repo_common_dir="${current_worktree_root}/${common_git_dir_raw}"
fi
repo_common_dir="$(cd "$repo_common_dir" && pwd -P)"
repo_root="$(cd "$repo_common_dir/.." && pwd -P)"
current_pwd="$(pwd -P)"
worktree_root="${repo_root}/.omx/agent-worktrees"
repo_common_dir="$(
  git -C "$repo_root" rev-parse --git-common-dir \
    | awk -v root="$repo_root" '{ if ($0 ~ /^\//) { print $0 } else { print root "/" $0 } }'
)"
repo_common_dir="$(cd "$repo_common_dir" && pwd -P)"

resolve_base_branch() {
  local configured=""
  local current=""

  configured="$(git -C "$repo_root" config --get multiagent.baseBranch || true)"
  if [[ -n "$configured" ]] && git -C "$repo_root" show-ref --verify --quiet "refs/heads/${configured}"; then
    printf '%s' "$configured"
    return 0
  fi

  current="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -n "$current" && "$current" != "HEAD" ]] && git -C "$repo_root" show-ref --verify --quiet "refs/heads/${current}"; then
    printf '%s' "$current"
    return 0
  fi

  for fallback in main dev; do
    if git -C "$repo_root" show-ref --verify --quiet "refs/heads/${fallback}"; then
      printf '%s' "$fallback"
      return 0
    fi
  done

  printf '%s' ""
}

is_agent_branch() {
  local branch="$1"
  [[ "$branch" == agent/* ]]
}

is_temporary_branch() {
  local branch="$1"
  [[ "$branch" == __agent_integrate_* || "$branch" == __source-probe-* ]]
}

is_supported_target_branch() {
  local branch="$1"
  is_agent_branch "$branch" || is_temporary_branch "$branch"
}

if [[ "$BASE_BRANCH_EXPLICIT" -eq 1 && -z "$BASE_BRANCH" ]]; then
  echo "[agent-worktree-prune] --base requires a non-empty branch name." >&2
  exit 1
fi

if [[ -n "$TARGET_BRANCH" ]] && ! is_supported_target_branch "$TARGET_BRANCH"; then
  echo "[agent-worktree-prune] --branch must reference agent/*, __agent_integrate_*, or __source-probe-*: ${TARGET_BRANCH}" >&2
  exit 1
fi

if [[ ! "$IDLE_MINUTES" =~ ^[0-9]+$ ]]; then
  echo "[agent-worktree-prune] --idle-minutes must be an integer >= 0." >&2
  exit 1
fi

if [[ -n "$NOW_EPOCH_RAW" && ! "$NOW_EPOCH_RAW" =~ ^[0-9]+$ ]]; then
  echo "[agent-worktree-prune] MUSAFETY_PRUNE_NOW_EPOCH must be a unix timestamp integer." >&2
  exit 1
fi

if [[ "$BASE_BRANCH_EXPLICIT" -eq 0 ]]; then
  BASE_BRANCH="$(resolve_base_branch)"
fi

if [[ -z "$BASE_BRANCH" ]]; then
  echo "[agent-worktree-prune] Unable to infer base branch. Pass --base <branch>." >&2
  exit 1
fi

if ! git -C "$repo_root" show-ref --verify --quiet "refs/heads/${BASE_BRANCH}"; then
  echo "[agent-worktree-prune] Base branch not found: ${BASE_BRANCH}" >&2
  exit 1
fi

IDLE_SECONDS=$((IDLE_MINUTES * 60))
if [[ -n "$NOW_EPOCH_RAW" ]]; then
  NOW_EPOCH="$NOW_EPOCH_RAW"
else
  NOW_EPOCH="$(date +%s)"
fi

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[agent-worktree-prune] [dry-run] $*"
    return 0
  fi
  "$@"
}

branch_has_worktree() {
  local branch="$1"
  git -C "$repo_root" worktree list --porcelain | awk -v target="refs/heads/${branch}" '
    $1 == "branch" && $2 == target { found = 1; exit }
    END { exit(found ? 0 : 1) }
  '
}

is_clean_worktree() {
  local wt="$1"
  git -C "$wt" diff --quiet -- . ":(exclude).omx/state/agent-file-locks.json" \
    && git -C "$wt" diff --cached --quiet -- . ":(exclude).omx/state/agent-file-locks.json" \
    && [[ -z "$(git -C "$wt" ls-files --others --exclude-standard)" ]]
}

has_unmerged_conflicts() {
  local wt="$1"
  [[ -n "$(git -C "$wt" diff --name-only --diff-filter=U 2>/dev/null || true)" ]]
}

filtered_status_output() {
  local wt="$1"
  git -C "$wt" status --porcelain --untracked-files=normal -- \
    . \
    ":(exclude).omx/state/agent-file-locks.json" \
    ":(exclude).dev-ports.json" \
    ":(exclude)apps/logs/*.log"
}

resolve_worktree_git_dir() {
  local wt="$1"
  local git_dir=""
  git_dir="$(git -C "$wt" rev-parse --git-dir 2>/dev/null || true)"
  if [[ -z "$git_dir" ]]; then
    return 1
  fi
  if [[ "$git_dir" == /* ]]; then
    git_dir="$(cd "$git_dir" 2>/dev/null && pwd -P || true)"
  else
    git_dir="$(cd "$wt/$git_dir" 2>/dev/null && pwd -P || true)"
  fi
  if [[ -z "$git_dir" ]]; then
    return 1
  fi
  printf '%s' "$git_dir"
}

bootstrap_manifest_path_for_worktree() {
  local wt="$1"
  local git_dir=""
  git_dir="$(resolve_worktree_git_dir "$wt" || true)"
  if [[ -z "$git_dir" ]]; then
    return 1
  fi
  printf '%s/musafety-bootstrap-manifest.json' "$git_dir"
}

worktree_matches_bootstrap_manifest() {
  local wt="$1"
  local manifest_path=""
  local status_output=""

  manifest_path="$(bootstrap_manifest_path_for_worktree "$wt" || true)"
  if [[ -z "$manifest_path" || ! -f "$manifest_path" ]]; then
    return 1
  fi

  status_output="$(filtered_status_output "$wt")"
  if [[ -z "$status_output" ]]; then
    return 1
  fi

  STATUS_OUTPUT="$status_output" python3 - "$wt" "$manifest_path" <<'PY'
from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path


def parse_status_paths(raw: str) -> list[str]:
    paths: list[str] = []
    for line in raw.splitlines():
        if len(line) < 4:
            continue
        path_part = line[3:]
        if " -> " in path_part:
            path_part = path_part.split(" -> ", 1)[1]
        path_part = path_part.strip()
        if path_part:
            paths.append(path_part)
    return paths


def sha256_for_path(path: Path) -> str | None:
    if not path.exists() or not path.is_file():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


if len(sys.argv) != 3:
    sys.exit(1)

worktree_root = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])
status_raw = os.environ.get("STATUS_OUTPUT", "")
status_paths = sorted(set(parse_status_paths(status_raw)))
if not status_paths:
    sys.exit(1)

try:
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
except Exception:
    sys.exit(1)

entries = payload.get("files")
if not isinstance(entries, list):
    sys.exit(1)

manifest_by_path: dict[str, str | None] = {}
for entry in entries:
    if not isinstance(entry, dict):
        continue
    path_value = entry.get("path")
    if not isinstance(path_value, str) or not path_value:
        continue
    sha_value = entry.get("sha256")
    if sha_value is not None and not isinstance(sha_value, str):
        continue
    manifest_by_path[path_value] = sha_value

if not manifest_by_path:
    sys.exit(1)

for rel_path in status_paths:
    if rel_path not in manifest_by_path:
        sys.exit(1)
    file_path = worktree_root / rel_path
    current_sha = sha256_for_path(file_path)
    if current_sha != manifest_by_path.get(rel_path):
        sys.exit(1)

sys.exit(0)
PY
}

sanitize_branch_component() {
  local raw="$1"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [[ -z "$raw" ]]; then
    raw="sandbox"
  fi
  printf '%s' "$raw"
}

resolve_unique_recovery_branch_name() {
  local seed="$1"
  local candidate="$seed"
  local suffix=2
  while git -C "$repo_root" show-ref --verify --quiet "refs/heads/${candidate}"; do
    candidate="${seed}-${suffix}"
    suffix=$((suffix + 1))
  done
  printf '%s' "$candidate"
}

resolve_worktree_common_dir() {
  local wt="$1"
  local common_dir=""
  common_dir="$(git -C "$wt" rev-parse --git-common-dir 2>/dev/null || true)"
  if [[ -z "$common_dir" ]]; then
    return 1
  fi
  if [[ "$common_dir" == /* ]]; then
    common_dir="$(cd "$common_dir" 2>/dev/null && pwd -P || true)"
  else
    common_dir="$(cd "$wt/$common_dir" 2>/dev/null && pwd -P || true)"
  fi
  if [[ -z "$common_dir" ]]; then
    return 1
  fi
  printf '%s' "$common_dir"
}

select_unique_worktree_path() {
  local root="$1"
  local name="$2"
  local candidate="${root}/${name}"
  local suffix=2
  while [[ -e "$candidate" ]]; do
    candidate="${root}/${name}-${suffix}"
    suffix=$((suffix + 1))
  done
  printf '%s' "$candidate"
}

skipped_recent=0

branch_idle_gate() {
  local branch="$1"
  local wt="$2"
  local reason="$3"
  local subject=""
  local commit_epoch=""
  local age=0
  local wait_remaining=0

  if [[ "$IDLE_SECONDS" -le 0 ]]; then
    return 0
  fi

  if [[ -n "$branch" ]] && git -C "$repo_root" show-ref --verify --quiet "refs/heads/${branch}"; then
    commit_epoch="$(git -C "$repo_root" log -1 --format=%ct "$branch" 2>/dev/null || true)"
    subject="$branch"
  elif [[ -n "$wt" ]]; then
    commit_epoch="$(git -C "$wt" log -1 --format=%ct 2>/dev/null || true)"
    subject="$wt"
  fi

  if [[ -z "$commit_epoch" || ! "$commit_epoch" =~ ^[0-9]+$ ]]; then
    return 0
  fi

  age=$((NOW_EPOCH - commit_epoch))
  if (( age < 0 )); then
    age=0
  fi

  if (( age < IDLE_SECONDS )); then
    wait_remaining=$((IDLE_SECONDS - age))
    skipped_recent=$((skipped_recent + 1))
    echo "[agent-worktree-prune] Skipping recent ${reason}: ${subject} (age=${age}s, threshold=${IDLE_SECONDS}s, wait~${wait_remaining}s)"
    return 1
  fi

  return 0
}

relocated_foreign=0
skipped_foreign=0

relocate_foreign_worktree_entries() {
  [[ -d "$worktree_root" ]] || return 0

  local entry=""
  for entry in "${worktree_root}"/*; do
    [[ -d "$entry" ]] || continue
    if ! git -C "$entry" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      continue
    fi

    local entry_common_dir=""
    entry_common_dir="$(resolve_worktree_common_dir "$entry" || true)"
    [[ -n "$entry_common_dir" ]] || continue

    if [[ "$entry_common_dir" == "$repo_common_dir" ]]; then
      continue
    fi

    if [[ "$(basename "$entry_common_dir")" != ".git" ]]; then
      skipped_foreign=$((skipped_foreign + 1))
      echo "[agent-worktree-prune] Skipping foreign worktree with unsupported git common dir: ${entry}"
      continue
    fi

    local owner_repo_root
    owner_repo_root="$(dirname "$entry_common_dir")"
    local owner_worktree_root="${owner_repo_root}/.omx/agent-worktrees"
    local target_path
    target_path="$(select_unique_worktree_path "$owner_worktree_root" "$(basename "$entry")")"

    if [[ "$entry" == "$current_pwd" || "$current_pwd" == "${entry}"/* ]]; then
      skipped_foreign=$((skipped_foreign + 1))
      echo "[agent-worktree-prune] Skipping active foreign worktree: ${entry}"
      continue
    fi

    echo "[agent-worktree-prune] Relocating foreign worktree to owning repo: ${entry} -> ${target_path}"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      relocated_foreign=$((relocated_foreign + 1))
      continue
    fi

    mkdir -p "$owner_worktree_root"
    if git -C "$owner_repo_root" worktree move "$entry" "$target_path" >/dev/null 2>&1; then
      relocated_foreign=$((relocated_foreign + 1))
    else
      skipped_foreign=$((skipped_foreign + 1))
      echo "[agent-worktree-prune] Failed to relocate foreign worktree: ${entry}" >&2
    fi
  done
}

removed_worktrees=0
removed_branches=0
skipped_active=0
skipped_dirty=0
repaired_detached_conflicts=0
failed_ops=0

relocate_foreign_worktree_entries

relocate_foreign_worktree_entries

process_entry() {
  local wt="$1"
  local branch_ref="$2"

  [[ -z "$wt" ]] && return
  [[ "$wt" != "${worktree_root}"/* ]] && return

  local branch=""
  if [[ -n "$branch_ref" ]]; then
    branch="${branch_ref#refs/heads/}"
  fi

  if [[ -n "$TARGET_BRANCH" && "$branch" != "$TARGET_BRANCH" ]]; then
    return
  fi

  if [[ "$wt" == "$current_pwd" ]]; then
    skipped_active=$((skipped_active + 1))
    echo "[agent-worktree-prune] Skipping active cwd worktree: ${wt}"
    return
  fi

  local remove_reason=""
  local wt_name
  wt_name="$(basename "$wt")"

  if [[ "$wt_name" == __integrate-* || "$wt_name" == __source-probe-* ]]; then
    remove_reason="temporary-worktree"
  elif [[ -z "$branch_ref" ]]; then
    remove_reason="detached-worktree"
  elif ! git -C "$repo_root" show-ref --verify --quiet "refs/heads/${branch}"; then
    remove_reason="missing-branch"
  elif is_agent_branch "$branch"; then
    if git -C "$repo_root" merge-base --is-ancestor "$branch" "$BASE_BRANCH"; then
      if [[ "$DELETE_BRANCHES" -eq 1 ]]; then
        remove_reason="merged-agent-branch"
      else
        remove_reason="merged-agent-worktree"
      fi
    elif [[ "$ONLY_DIRTY_WORKTREES" -eq 1 ]] && is_clean_worktree "$wt"; then
      remove_reason="clean-agent-worktree"
    fi
  elif is_temporary_branch "$branch"; then
    remove_reason="temporary-worktree"
  fi

  if [[ -z "$remove_reason" ]]; then
    return
  fi

  if ! branch_idle_gate "$branch" "$wt" "$remove_reason"; then
    return
  fi

  if [[ "$FORCE_DIRTY" -ne 1 ]] \
    && [[ "$remove_reason" == "detached-worktree" ]] \
    && has_unmerged_conflicts "$wt"; then
    local wt_component
    local base_component
    local recovery_seed
    local recovery_branch

    wt_component="$(sanitize_branch_component "$wt_name")"
    base_component="$(sanitize_branch_component "$BASE_BRANCH")"
    recovery_seed="agent/recover/${base_component}-${wt_component}-$(date +%Y%m%d-%H%M%S)"
    recovery_branch="$(resolve_unique_recovery_branch_name "$recovery_seed")"

    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[agent-worktree-prune] [dry-run] Would recover detached conflicted worktree: ${wt} -> ${recovery_branch}"
      repaired_detached_conflicts=$((repaired_detached_conflicts + 1))
      return
    fi

    if git -C "$wt" checkout -b "$recovery_branch" >/dev/null 2>&1; then
      repaired_detached_conflicts=$((repaired_detached_conflicts + 1))
      echo "[agent-worktree-prune] Recovered detached conflicted worktree: ${wt} -> ${recovery_branch}"
      return
    fi

    failed_ops=$((failed_ops + 1))
    echo "[agent-worktree-prune] Failed to recover detached conflicted worktree: ${wt}" >&2
    return
  fi

  if [[ "$FORCE_DIRTY" -ne 1 ]] && ! is_clean_worktree "$wt"; then
    if [[ "$remove_reason" == "merged-agent-branch" || "$remove_reason" == "merged-agent-worktree" ]] \
      && worktree_matches_bootstrap_manifest "$wt"; then
      echo "[agent-worktree-prune] Treating bootstrap-only sandbox as safe to remove (${remove_reason}): ${wt}"
    else
      skipped_dirty=$((skipped_dirty + 1))
      echo "[agent-worktree-prune] Skipping dirty worktree (${remove_reason}): ${wt}"
      return
    fi
  fi

  echo "[agent-worktree-prune] Removing worktree (${remove_reason}): ${wt}"
  if run_cmd git -C "$repo_root" worktree remove "$wt" --force; then
    removed_worktrees=$((removed_worktrees + 1))
  else
    failed_ops=$((failed_ops + 1))
    echo "[agent-worktree-prune] Failed to remove worktree (${remove_reason}): ${wt}" >&2
    return
  fi

  if [[ -z "$branch" ]]; then
    return
  fi

  if git -C "$repo_root" show-ref --verify --quiet "refs/heads/${branch}" && ! branch_has_worktree "$branch"; then
    if is_agent_branch "$branch" && [[ "$DELETE_BRANCHES" -eq 1 ]]; then
      if run_cmd git -C "$repo_root" branch -d "$branch" >/dev/null 2>&1; then
        removed_branches=$((removed_branches + 1))
        echo "[agent-worktree-prune] Deleted merged branch: ${branch}"
        if [[ "$DELETE_REMOTE_BRANCHES" -eq 1 ]]; then
          if git -C "$repo_root" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
            run_cmd git -C "$repo_root" push origin --delete "$branch" >/dev/null 2>&1 || true
            echo "[agent-worktree-prune] Deleted merged remote branch: ${branch}"
          fi
        fi
      fi
    elif is_temporary_branch "$branch"; then
      run_cmd git -C "$repo_root" branch -D "$branch" >/dev/null 2>&1 || true
      removed_branches=$((removed_branches + 1))
      echo "[agent-worktree-prune] Deleted temporary branch: ${branch}"
    fi
  fi
}

current_wt=""
current_branch_ref=""

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ -z "$line" ]]; then
    process_entry "$current_wt" "$current_branch_ref"
    current_wt=""
    current_branch_ref=""
    continue
  fi

  case "$line" in
    worktree\ *)
      current_wt="${line#worktree }"
      ;;
    branch\ *)
      current_branch_ref="${line#branch }"
      ;;
  esac
done < <(git -C "$repo_root" worktree list --porcelain)

process_entry "$current_wt" "$current_branch_ref"

if [[ "$DELETE_BRANCHES" -eq 1 ]]; then
  while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    if [[ -n "$TARGET_BRANCH" && "$branch" != "$TARGET_BRANCH" ]]; then
      continue
    fi
    if branch_has_worktree "$branch"; then
      continue
    fi
    if is_temporary_branch "$branch"; then
      if ! branch_idle_gate "$branch" "" "stale-temporary-branch"; then
        continue
      fi
      if run_cmd git -C "$repo_root" branch -D "$branch" >/dev/null 2>&1; then
        removed_branches=$((removed_branches + 1))
        if [[ "$DRY_RUN" -eq 1 ]]; then
          echo "[agent-worktree-prune] Would delete stale temporary branch: ${branch}"
        else
          echo "[agent-worktree-prune] Deleted stale temporary branch: ${branch}"
        fi
      fi
      continue
    fi
    if ! is_agent_branch "$branch"; then
      continue
    fi
    if ! branch_idle_gate "$branch" "" "stale-merged-branch"; then
      continue
    fi
    if git -C "$repo_root" merge-base --is-ancestor "$branch" "$BASE_BRANCH"; then
      if run_cmd git -C "$repo_root" branch -d "$branch" >/dev/null 2>&1; then
        removed_branches=$((removed_branches + 1))
        if [[ "$DRY_RUN" -eq 1 ]]; then
          echo "[agent-worktree-prune] Would delete stale merged branch: ${branch}"
        else
          echo "[agent-worktree-prune] Deleted stale merged branch: ${branch}"
        fi
        if [[ "$DELETE_REMOTE_BRANCHES" -eq 1 ]]; then
          if git -C "$repo_root" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
            run_cmd git -C "$repo_root" push origin --delete "$branch" >/dev/null 2>&1 || true
            if [[ "$DRY_RUN" -eq 1 ]]; then
              echo "[agent-worktree-prune] Would delete stale merged remote branch: ${branch}"
            else
              echo "[agent-worktree-prune] Deleted stale merged remote branch: ${branch}"
            fi
          fi
        fi
      fi
    fi
  done < <(git -C "$repo_root" for-each-ref --format='%(refname:short)' refs/heads | awk '/^agent\// || /^__agent_integrate_/ || /^__source-probe-/')
fi

if [[ "$DELETE_REMOTE_BRANCHES" -eq 1 ]]; then
  while IFS= read -r remote_ref; do
    [[ -z "$remote_ref" ]] && continue
    local_branch="${remote_ref#origin/}"
    if [[ -n "$TARGET_BRANCH" && "$local_branch" != "$TARGET_BRANCH" ]]; then
      continue
    fi
    if git -C "$repo_root" show-ref --verify --quiet "refs/heads/${local_branch}"; then
      continue
    fi
    if ! is_agent_branch "$local_branch"; then
      continue
    fi
    if git -C "$repo_root" merge-base --is-ancestor "$remote_ref" "$BASE_BRANCH"; then
      if run_cmd git -C "$repo_root" push origin --delete "$local_branch" >/dev/null 2>&1; then
        removed_branches=$((removed_branches + 1))
        if [[ "$DRY_RUN" -eq 1 ]]; then
          echo "[agent-worktree-prune] Would delete stale merged remote-only branch: ${local_branch}"
        else
          echo "[agent-worktree-prune] Deleted stale merged remote-only branch: ${local_branch}"
        fi
      fi
    fi
  done < <(git -C "$repo_root" for-each-ref --format='%(refname:short)' refs/remotes/origin/agent)
fi

if ! run_cmd git -C "$repo_root" worktree prune; then
  failed_ops=$((failed_ops + 1))
  echo "[agent-worktree-prune] Warning: git worktree prune failed." >&2
fi

echo "[agent-worktree-prune] Summary: base=${BASE_BRANCH}, removed_worktrees=${removed_worktrees}, removed_branches=${removed_branches}, skipped_active=${skipped_active}, skipped_dirty=${skipped_dirty}, repaired_detached_conflicts=${repaired_detached_conflicts}"
if [[ "$relocated_foreign" -gt 0 || "$skipped_foreign" -gt 0 ]]; then
  echo "[agent-worktree-prune] Foreign routing: relocated=${relocated_foreign}, skipped=${skipped_foreign}"
fi
if [[ "$skipped_active" -gt 0 ]]; then
  echo "[agent-worktree-prune] Tip: leave active agent worktree directories, then run this command again for full cleanup." >&2
fi
if [[ "$skipped_dirty" -gt 0 ]]; then
  echo "[agent-worktree-prune] Tip: dirty worktrees were preserved. Clean/finish them first, or pass --force-dirty to remove anyway." >&2
fi
if [[ "$IDLE_SECONDS" -gt 0 && "$skipped_recent" -gt 0 ]]; then
  echo "[agent-worktree-prune] Tip: recent branches were preserved by --idle-minutes=${IDLE_MINUTES}. Re-run later or lower the threshold." >&2
fi
if [[ "$failed_ops" -gt 0 ]]; then
  echo "[agent-worktree-prune] Tip: some cleanup operations failed and were skipped. Re-run after fixing file-system or permission blockers." >&2
fi
