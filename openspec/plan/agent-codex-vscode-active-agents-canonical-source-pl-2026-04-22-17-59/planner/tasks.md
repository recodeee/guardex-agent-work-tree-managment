# planner tasks

## 1. Spec

- [x] 1.1 Define planning principles, decision drivers, and viable options for `agent-codex-vscode-active-agents-canonical-source-pl-2026-04-22-17-59`.
- [x] 1.2 Capture the stale-note audit, canonical-source scope, and acceptance criteria in `summary.md`, `planner/plan.md`, and the change spec.

## 2. Tests

- [x] 2.1 Define the focused planning proof surface: strict change validation, artifact-consistency checks, and the future execution proof surface around `test/vscode-active-agents-session-state.test.js` and `test/metadata.test.js`.
- [x] 2.2 Validate that this branch stays planning-only and leaves runtime/setup verification for the fresh implementation lane.

## 3. Implementation

- [x] 3.1 Publish the initial stale-note audit and freeze the real remaining issue: duplicate authored extension sources plus text-only managed-file copying.
- [x] 3.2 Integrate Architect/Critic conclusions into the canonical-source direction and execution boundaries.
- [x] 3.3 Publish the final execution-ready continuation board for the canonical-source migration.

## 4. Checkpoints

- [x] [P1] READY - Canonical-source planning checkpoint

### P1 Acceptance Criteria

- [x] The plan rejects stale runtime/icon follow-ups in favor of the real source-of-truth debt.
- [x] The canonical authored source is fixed to `vscode/guardex-active-agents/`.
- [x] The plan names the concrete migration seams and focused proof surface.

### P1 Verification Evidence

- [x] `summary.md`, `phases.md`, and `planner/plan.md` isolate the same canonical-source scope.
- [x] The root change proposal/spec/tasks reflect the same boundaries.
- [x] `checkpoints.md` records the planner checkpoint and downstream implementation handoff.

## 5. Collaboration

- [x] 5.1 Owner recorded this lane before edits.
- [x] 5.2 N/A - solo planning lane.

## 6. Cleanup

- [ ] 6.1 Finish the planning branch with `gx branch finish --branch agent/codex/continue-vscode-extension-collab-plan-2026-04-22-17-59 --base main --via-pr --wait-for-merge --cleanup`.
- [ ] 6.2 Record PR URL + final `MERGED` state in the handoff.
- [ ] 6.3 Confirm sandbox cleanup (`git worktree list`, `git branch -a`) or append `BLOCKED:` and stop.
