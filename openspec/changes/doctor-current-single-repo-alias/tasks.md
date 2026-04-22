## Definition of Done

This change is complete only when **all** of the following are true:

- Every checkbox below is checked.
- The agent branch reaches `MERGED` state on `origin` and the PR URL + state are recorded in the completion handoff.
- If any step blocks, add a `BLOCKED:` line under section 4 and stop.

## 1. Specification

- [x] 1.1 Capture the `gx doctor --current` alias scope and acceptance criteria.
- [x] 1.2 Add normative OpenSpec coverage for the single-repo alias behavior.

## 2. Implementation

- [x] 2.1 Accept `--current` as a doctor-only alias for `--single-repo`.
- [x] 2.2 Update the recursive doctor hint text to mention `--current`.
- [x] 2.3 Add a regression proving nested repos under the target path stay untouched.

## 3. Verification

- [x] 3.1 Run `node --check bin/multiagent-safety.js`.
- [x] 3.2 Run `node --test test/doctor.test.js`.
- [x] 3.3 Run `openspec validate doctor-current-single-repo-alias --type change --strict`.
- [x] 3.4 Run `openspec validate --specs`.

## 4. Cleanup

- [x] 4.1 Commit the change with a Lore commit message.
- [x] 4.2 Run `gx branch finish --branch agent/codex/scope-gx-doctor-current-to-current-repo-2026-04-22-13-13 --via-pr --wait-for-merge --cleanup`.
- [x] 4.3 Record the PR URL and final merge state (`MERGED`) in the completion handoff.
- [x] 4.4 Confirm the sandbox worktree and branch refs are gone after cleanup.

Completion handoff: PR https://github.com/recodeee/gitguardex/pull/298 state=`MERGED` merged_at=`2026-04-22T11:39:44Z`; `git worktree list` no longer shows `.omx/agent-worktrees/agent__codex__scope-gx-doctor-current-to-current-repo-2026-04-22-13-13`; `git branch -a --list 'agent/codex/scope-gx-doctor-current-to-current-repo-2026-04-22-13-13' 'origin/agent/codex/scope-gx-doctor-current-to-current-repo-2026-04-22-13-13'` returns no refs after `git fetch --prune origin`.
