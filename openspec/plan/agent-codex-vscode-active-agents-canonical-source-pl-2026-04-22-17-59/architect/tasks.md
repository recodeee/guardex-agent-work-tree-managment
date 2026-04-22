# architect tasks

## 1. Spec

- [x] 1.1 Define ownership boundaries, interfaces, and artifact responsibilities for `agent-codex-vscode-active-agents-canonical-source-pl-2026-04-22-17-59`.
- [x] 1.2 Validate architecture constraints and non-functional requirements coverage.

## 2. Tests

- [x] 2.1 Define architectural verification checkpoints around source-path ownership, binary-safe asset copying, and managed-repo compatibility.
- [x] 2.2 Validate that acceptance criteria map to concrete architecture decisions.

## 3. Implementation

- [x] 3.1 Review the plan for the main tradeoff tension: canonicalize to `vscode/` vs keep templates as the authored source.
- [x] 3.2 Propose the synthesis path: keep `vscode/` authored, move setup/doctor/materialization to it, and demote any remaining template copy to derived output only.
- [x] 3.3 Record architecture sign-off notes for downstream execution.

## 4. Checkpoints

- [x] [A1] READY - Architecture review checkpoint

### A1 Acceptance Criteria

- [x] The canonical source location is fixed to `vscode/guardex-active-agents/`.
- [x] The plan names the managed-file/materialization seam instead of reopening runtime/UI behavior.
- [x] Binary asset handling for `icon.png` is treated as a first-class migration requirement.

### A1 Verification Evidence

- [x] `planner/plan.md` documents the chosen direction and rejected alternatives.
- [x] `phases.md` marks the architecture phase complete with the canonical-source decision.
- [x] `checkpoints.md` records the architecture checkpoint and downstream risk.

## 5. Collaboration

- [x] 5.1 Owner recorded this lane before edits.
- [x] 5.2 N/A - solo planning lane.

## 6. Cleanup

- [ ] 6.1 Finish the planning branch after validation with `gx branch finish --branch agent/codex/continue-vscode-extension-collab-plan-2026-04-22-17-59 --base main --via-pr --wait-for-merge --cleanup`.
- [ ] 6.2 Record PR URL + final `MERGED` state in the handoff.
- [ ] 6.3 Confirm sandbox cleanup (`git worktree list`, `git branch -a`) or append `BLOCKED:` and stop.
