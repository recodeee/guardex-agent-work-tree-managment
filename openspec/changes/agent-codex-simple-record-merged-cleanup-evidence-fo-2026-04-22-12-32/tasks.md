## Definition of Done

This change is complete only when **all** of the following are true:

- Every checkbox below is checked.
- The agent branch reaches `MERGED` state on `origin` and the PR URL + state are recorded in the completion handoff.
- If any step blocks (test failure, conflict, ambiguous result), append a `BLOCKED:` line under section 4 explaining the blocker and **STOP**. Do not tick remaining cleanup boxes; do not silently skip the cleanup pipeline.

## Handoff

- Handoff: change=`agent-codex-simple-record-merged-cleanup-evidence-fo-2026-04-22-12-32`; branch=`agent/codex/simple-record-merged-cleanup-evidence-fo-2026-04-22-12-32`; scope=`scripts/codex-agent.sh, templates/scripts/codex-agent.sh, test/sandbox.test.js, OpenSpec change docs`; action=`finish the routing fix, verify it, then run the guarded finish pipeline on base main`.
- Copy prompt: Continue `agent-codex-simple-record-merged-cleanup-evidence-fo-2026-04-22-12-32` on branch `agent/codex/simple-record-merged-cleanup-evidence-fo-2026-04-22-12-32`. Work inside the existing sandbox, review `openspec/changes/agent-codex-simple-record-merged-cleanup-evidence-fo-2026-04-22-12-32/tasks.md`, continue from the current state instead of creating a new sandbox, and when the work is done run `gx branch finish --branch agent/codex/simple-record-merged-cleanup-evidence-fo-2026-04-22-12-32 --base main --via-pr --wait-for-merge --cleanup`.

## 1. Specification

- [x] 1.1 Finalize proposal scope and acceptance criteria for `agent-codex-simple-record-merged-cleanup-evidence-fo-2026-04-22-12-32`.
- [x] 1.2 Define normative requirements in `specs/simple-record-merged-cleanup-evidence-for-task-mode-decider/spec.md`.

## 2. Implementation

- [x] 2.1 Implement scoped behavior changes.
- [x] 2.2 Add/update focused regression coverage.

## 3. Verification

- [x] 3.1 Run targeted project verification commands. `node --test test/sandbox.test.js test/metadata.test.js` passed (`25/25`).
- [x] 3.2 Run `openspec validate agent-codex-simple-record-merged-cleanup-evidence-fo-2026-04-22-12-32 --type change --strict`. Passed.
- [x] 3.3 Run `openspec validate --specs`. Passed with `No items found to validate.` in the current repo state.

## 4. Cleanup (mandatory; run before claiming completion)

- [x] 4.1 Run the cleanup pipeline: `gx branch finish --branch agent/codex/simple-record-merged-cleanup-evidence-fo-2026-04-22-12-32 --base main --via-pr --wait-for-merge --cleanup`. The command ran from the main checkout, merged PR #306, and pruned the original sandbox; it then hit the known already-deleted-remote-ref edge, so final ref cleanup was completed with `git fetch --prune origin`.
- [x] 4.2 Record the PR URL and final merge state (`MERGED`) in the completion handoff. PR #306 (`https://github.com/recodeee/gitguardex/pull/306`) reached `MERGED` at `2026-04-22T12:58:38Z`; merge commit: `a40e42ba4edcd540a60a02c1d788a38a82236e3b`.
- [x] 4.3 Confirm the sandbox worktree is gone (`git worktree list` no longer shows the agent path; `git branch -a` shows no surviving local/remote refs for the branch). The original worktree `agent__codex__masterplan__simple-record-merged-cleanup-evidence-fo-2026-04-22-12-32` is gone from `.omx/agent-worktrees/`, and after `git fetch --prune origin` there are no remaining local or remote refs for `agent/codex/simple-record-merged-cleanup-evidence-fo-2026-04-22-12-32`.

Completion note: The routing fix landed via PR #306 (`https://github.com/recodeee/gitguardex/pull/306`), which reached `MERGED` at `2026-04-22T12:58:38Z` with merge commit `a40e42ba4edcd540a60a02c1d788a38a82236e3b`. The original agent worktree `agent__codex__masterplan__simple-record-merged-cleanup-evidence-fo-2026-04-22-12-32` was pruned by the finish flow, and the last stale remote-tracking ref was cleared with `git fetch --prune origin`.
