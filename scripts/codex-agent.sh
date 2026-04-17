#!/usr/bin/env bash
set -euo pipefail

TASK_NAME="${MUSAFETY_TASK_NAME:-task}"
AGENT_NAME="${MUSAFETY_AGENT_NAME:-agent}"
BASE_BRANCH="${MUSAFETY_BASE_BRANCH:-}"
BASE_BRANCH_EXPLICIT=0
CODEX_BIN="${MUSAFETY_CODEX_BIN:-codex}"
GH_PR_REF="${MUSAFETY_GH_PR_REF:-}"
GH_REPO_REF="${MUSAFETY_GH_REPO:-}"
GH_SYNC_FLAG=""

if [[ -n "$BASE_BRANCH" ]]; then
  BASE_BRANCH_EXPLICIT=1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)
      TASK_NAME="${2:-$TASK_NAME}"
      shift 2
      ;;
    --agent)
      AGENT_NAME="${2:-$AGENT_NAME}"
      shift 2
      ;;
    --base)
      BASE_BRANCH="${2:-$BASE_BRANCH}"
      BASE_BRANCH_EXPLICIT=1
      shift 2
      ;;
    --codex-bin)
      CODEX_BIN="${2:-$CODEX_BIN}"
      shift 2
      ;;
    --pr)
      GH_PR_REF="${2:-$GH_PR_REF}"
      shift 2
      ;;
    --repo)
      GH_REPO_REF="${2:-$GH_REPO_REF}"
      shift 2
      ;;
    --gh-sync)
      GH_SYNC_FLAG="--gh-sync"
      shift
      ;;
    --no-gh-sync)
      GH_SYNC_FLAG="--no-gh-sync"
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      break
      ;;
    *)
      TASK_NAME="$1"
      shift
      if [[ $# -gt 0 && "${1:-}" != -* ]]; then
        AGENT_NAME="$1"
        shift
      fi
      if [[ $# -gt 0 && "${1:-}" != -* ]]; then
        BASE_BRANCH="$1"
        BASE_BRANCH_EXPLICIT=1
        shift
      fi
      break
      ;;
  esac
done

if [[ "$BASE_BRANCH_EXPLICIT" -eq 1 && -z "$BASE_BRANCH" ]]; then
  echo "[codex-agent] --base requires a non-empty branch name." >&2
  exit 1
fi

if ! command -v "$CODEX_BIN" >/dev/null 2>&1; then
  echo "[codex-agent] Missing Codex CLI command: $CODEX_BIN" >&2
  echo "[codex-agent] Install Codex first, then retry." >&2
  exit 127
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[codex-agent] Not inside a git repository." >&2
  exit 1
fi
repo_root="$(git rev-parse --show-toplevel)"

if [[ ! -x "${repo_root}/scripts/agent-branch-start.sh" ]]; then
  echo "[codex-agent] Missing scripts/agent-branch-start.sh. Run: gx setup" >&2
  exit 1
fi

start_args=("$TASK_NAME" "$AGENT_NAME")
if [[ "$BASE_BRANCH_EXPLICIT" -eq 1 ]]; then
  start_args+=("$BASE_BRANCH")
fi
if [[ -n "$GH_PR_REF" ]]; then
  start_args+=(--pr "$GH_PR_REF")
fi
if [[ -n "$GH_REPO_REF" ]]; then
  start_args+=(--repo "$GH_REPO_REF")
fi
if [[ -n "$GH_SYNC_FLAG" ]]; then
  start_args+=("$GH_SYNC_FLAG")
fi

derive_worktree_session_key() {
  local worktree="$1"
  local digest=""

  if command -v sha256sum >/dev/null 2>&1; then
    digest="$(printf '%s' "$worktree" | sha256sum | awk '{print $1}' | cut -c1-20)"
  elif command -v shasum >/dev/null 2>&1; then
    digest="$(printf '%s' "$worktree" | shasum -a 256 | awk '{print $1}' | cut -c1-20)"
  fi

  if [[ -z "$digest" ]]; then
    digest="$(printf '%s' "$worktree" | tr -cs 'a-zA-Z0-9' '-' | sed -E 's/^-+//; s/-+$//' | cut -c1-40)"
  fi

  if [[ -z "$digest" ]]; then
    digest="sandbox"
  fi

  printf 'worktree:%s' "$digest"
}

export_worktree_mem0_env() {
  local worktree="$1"
  local mem0_dir="${worktree}/.omx/mem0"
  local notepad_path="${mem0_dir}/notepad.md"
  local project_memory_path="${mem0_dir}/project-memory.json"
  local scope_path="${mem0_dir}/worktree-scope.json"

  export OMX_MEM0_SCOPE="worktree"
  export OMX_MEM0_DIR="$mem0_dir"
  if [[ -f "$notepad_path" ]]; then
    export OMX_NOTEPAD_PATH="$notepad_path"
  fi
  if [[ -f "$project_memory_path" ]]; then
    export OMX_PROJECT_MEMORY_PATH="$project_memory_path"
  fi
  if [[ -f "$scope_path" ]]; then
    export OMX_MEM0_SCOPE_PATH="$scope_path"
  fi

  if [[ -z "${CODEX_AUTH_SESSION_KEY:-}" ]]; then
    export CODEX_AUTH_SESSION_KEY="$(derive_worktree_session_key "$worktree")"
    echo "[codex-agent] Scoped CODEX_AUTH_SESSION_KEY to ${CODEX_AUTH_SESSION_KEY}"
  fi

  echo "[codex-agent] Worktree mem0 scope: $mem0_dir"
}

resolve_finish_base_branch() {
  local branch="$1"
  local stored_base=""

  stored_base="$(git -C "$repo_root" config --get "branch.${branch}.musafetyBase" || true)"
  if [[ -n "$stored_base" ]]; then
    printf '%s' "$stored_base"
    return
  fi

  if [[ -n "$BASE_BRANCH" ]]; then
    printf '%s' "$BASE_BRANCH"
  fi
}

render_finish_hint() {
  local branch="$1"
  local base="${2:-}"
  local hint=""

  hint="bash scripts/agent-branch-finish.sh --branch \"${branch}\""
  if [[ -n "$base" ]]; then
    hint="${hint} --base \"${base}\""
  fi
  hint="${hint} --via-pr --wait-for-merge --cleanup"
  if [[ -n "$GH_PR_REF" ]]; then
    hint="${hint} --pr \"${GH_PR_REF}\""
  fi
  if [[ -n "$GH_REPO_REF" ]]; then
    hint="${hint} --repo \"${GH_REPO_REF}\""
  fi

  printf '%s' "$hint"
}

start_output="$(bash "${repo_root}/scripts/agent-branch-start.sh" "${start_args[@]}")"
printf '%s\n' "$start_output"

worktree_path="$(printf '%s\n' "$start_output" | sed -n 's/^\[agent-branch-start\] Worktree: //p' | tail -n1)"
if [[ -z "$worktree_path" ]]; then
  echo "[codex-agent] Could not determine sandbox worktree path from agent-branch-start output." >&2
  exit 1
fi

if [[ ! -d "$worktree_path" ]]; then
  echo "[codex-agent] Reported worktree path does not exist: $worktree_path" >&2
  exit 1
fi

export_worktree_mem0_env "$worktree_path"

echo "[codex-agent] Launching ${CODEX_BIN} in sandbox: $worktree_path"
cd "$worktree_path"
set +e
"$CODEX_BIN" "$@"
codex_exit="$?"
set -e

cd "$repo_root"

final_exit="$codex_exit"
worktree_branch="$(git -C "$worktree_path" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
finish_base_branch=""
finish_hint=""
if [[ -n "$worktree_branch" && "$worktree_branch" != "HEAD" ]]; then
  finish_base_branch="$(resolve_finish_base_branch "$worktree_branch")"
  finish_hint="$(render_finish_hint "$worktree_branch" "$finish_base_branch")"
fi

if [[ "$codex_exit" -eq 0 ]]; then
  if [[ -x "${repo_root}/scripts/agent-branch-finish.sh" ]]; then
    if [[ -n "$worktree_branch" && "$worktree_branch" != "HEAD" ]]; then
      finish_args=(--branch "$worktree_branch")
      if [[ -n "$finish_base_branch" ]]; then
        finish_args+=(--base "$finish_base_branch")
      fi
      finish_args+=(--via-pr --wait-for-merge --cleanup)
      if [[ -n "$GH_PR_REF" ]]; then
        finish_args+=(--pr "$GH_PR_REF")
      fi
      if [[ -n "$GH_REPO_REF" ]]; then
        finish_args+=(--repo "$GH_REPO_REF")
      fi

      echo "[codex-agent] Codex finished successfully. Auto-finishing branch via PR merge + cleanup..."
      if ! bash "${repo_root}/scripts/agent-branch-finish.sh" "${finish_args[@]}"; then
        echo "[codex-agent] Auto-finish failed. Sandbox is kept for manual resolve/retry." >&2
        if [[ -n "$finish_hint" ]]; then
          echo "[codex-agent] Retry with: ${finish_hint}" >&2
        fi
        final_exit=1
      fi
    else
      echo "[codex-agent] Could not determine sandbox branch name; skipping auto-finish." >&2
      final_exit=1
    fi
  else
    echo "[codex-agent] Missing scripts/agent-branch-finish.sh; skipping auto-finish." >&2
    final_exit=1
  fi
else
  echo "[codex-agent] Skipping auto-finish because Codex exited with status ${codex_exit}."
fi

if [[ -x "${repo_root}/scripts/agent-worktree-prune.sh" ]]; then
  echo "[codex-agent] Session ended (exit=${final_exit}). Running worktree cleanup..."
  prune_args=()
  if [[ "$BASE_BRANCH_EXPLICIT" -eq 1 ]]; then
    prune_args+=(--base "$BASE_BRANCH")
  fi
  if ! bash "${repo_root}/scripts/agent-worktree-prune.sh" "${prune_args[@]}"; then
    echo "[codex-agent] Warning: automatic worktree cleanup failed." >&2
  fi
fi

if [[ ! -d "$worktree_path" ]]; then
  echo "[codex-agent] Auto-cleaned sandbox worktree: $worktree_path"
else
  echo "[codex-agent] Sandbox worktree kept: $worktree_path"
  if [[ -n "$worktree_branch" && "$worktree_branch" != "HEAD" ]]; then
    if [[ -z "$finish_hint" ]]; then
      finish_base_branch="$(resolve_finish_base_branch "$worktree_branch")"
      finish_hint="$(render_finish_hint "$worktree_branch" "$finish_base_branch")"
    fi
    echo "[codex-agent] If finished, merge + clean with: ${finish_hint}"
  fi
fi

exit "$final_exit"
