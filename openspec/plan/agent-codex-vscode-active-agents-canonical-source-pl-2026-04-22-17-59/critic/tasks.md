# critic tasks

## 1. Spec

- [x] 1.1 Validate principle-driver-option consistency across the plan.
- [x] 1.2 Validate risks, consequences, and mitigation clarity, including idempotency expectations.

## 2. Tests

- [x] 2.1 Validate testability and measurability of all acceptance criteria.
- [x] 2.2 Validate that verification steps are concrete and reproducible.

## 3. Implementation

- [x] 3.1 Produce verdict `APPROVE` with actionable feedback.
- [x] 3.2 Confirm the revised drafts resolve the main failure mode: planning the wrong stale runtime notes instead of the real source-of-truth debt.
- [x] 3.3 Publish final quality/risk sign-off notes.

## 4. Checkpoints

- [x] [C1] READY - Quality gate checkpoint

### C1 Acceptance Criteria

- [x] The plan rejects stale runtime/icon follow-ups in favor of the real remaining debt.
- [x] Every acceptance criterion maps to a concrete proof surface.
- [x] The plan does not hide the binary-asset/setup risk behind generic “keep parity” wording.

### C1 Verification Evidence

- [x] `checkpoints.md` records an `APPROVE` verdict.
- [x] `summary.md`, `phases.md`, and `planner/plan.md` all preserve the same canonical-source scope.
- [x] The root change proposal/spec/tasks reflect the same testable boundaries.

## 5. Collaboration

- [x] 5.1 Owner recorded this lane before edits.
- [x] 5.2 N/A - solo planning lane.

## 6. Cleanup

- [ ] 6.1 Finish the planning branch after validation with `gx branch finish --branch agent/codex/continue-vscode-extension-collab-plan-2026-04-22-17-59 --base main --via-pr --wait-for-merge --cleanup`.
- [ ] 6.2 Record PR URL + final `MERGED` state in the handoff.
- [ ] 6.3 Confirm sandbox cleanup (`git worktree list`, `git branch -a`) or append `BLOCKED:` and stop.
