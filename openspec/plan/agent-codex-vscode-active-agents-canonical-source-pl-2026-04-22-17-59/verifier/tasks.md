# verifier tasks

## 1. Spec

- [ ] 1.1 Define the end-to-end validation matrix for `agent-codex-vscode-active-agents-canonical-source-pl-2026-04-22-17-59`.
- [ ] 1.2 Validate success/failure conditions and evidence requirements.

## 2. Tests

- [ ] 2.1 Execute the focused verification commands and collect outputs.
- [ ] 2.2 Validate idempotency/re-run behavior for setup/doctor/install flows and any binary asset copy path touched by the change.

## 3. Implementation

- [ ] 3.1 Verify the completed work against the canonical-source acceptance criteria.
- [ ] 3.2 Produce pass/fail findings with concrete evidence links.
- [ ] 3.3 Publish the final verification sign-off or blocker report.

## 4. Checkpoints

- [ ] [V1] READY - Verification checkpoint

### V1 Acceptance Criteria

- [ ] Verification proves one authored source of truth plus correct downstream materialization of `icon.png`.
- [ ] Focused tests cover install/setup/doctor truthfulness without widening into unrelated repo noise.
- [ ] Final evidence is explicit for the implementation branch merge and cleanup.

### V1 Verification Evidence

- [ ] Verifier notes record targeted test output and any manual install/setup smoke evidence.
- [ ] The final handoff includes PR URL, merge state, and cleanup proof for the implementation branch.
- [ ] `planner/plan.md` is updated with the actual implementation evidence when execution finishes.

## 5. Collaboration

- [ ] 5.1 Owner recorded the verification lane before edits.
- [ ] 5.2 Record joined agents / handoffs, or mark `N/A` when solo.

## 6. Cleanup

- [ ] 6.1 Finish the implementation branch with `gx branch finish --branch <implementation-branch> --base main --via-pr --wait-for-merge --cleanup`.
- [ ] 6.2 Record PR URL + final `MERGED` state in the handoff.
- [ ] 6.3 Confirm sandbox cleanup (`git worktree list`, `git branch -a`) or append `BLOCKED:` and stop.
