# verifier tasks

## 1. Spec

- [ ] 1.1 Define the validation matrix for icon packaging, installed payload contents, preserved tree behavior, and finish evidence.
- [ ] 1.2 Validate success/failure conditions and evidence requirements before merge.

## 2. Tests

- [ ] 2.1 Execute focused verification commands and collect outputs, including `node --test test/vscode-active-agents-session-state.test.js`.
- [ ] 2.2 Validate idempotency/re-run behavior for install and cleanup flows plus any runtime error-path handling touched by the change.

## 3. Implementation

- [ ] 3.1 Verify completed work against the acceptance criteria in `specs/vscode-active-agents-extension/spec.md`.
- [ ] 3.2 Produce pass/fail findings with concrete evidence links.
- [ ] 3.3 Publish final verification sign-off or a blocker report.

## 4. Checkpoints

- [ ] [V1] READY - Verification checkpoint

## 5. Collaboration

- [ ] 5.1 Owner recorded this lane before edits.
- [ ] 5.2 Record joined agents / handoffs, or mark `N/A` when solo.

## 6. Cleanup

- [ ] 6.1 If this lane owns finalization, run `gx branch finish --branch agent/codex/vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05 --base main --via-pr --wait-for-merge --cleanup`.
- [ ] 6.2 Record PR URL + final `MERGED` state in the handoff.
- [ ] 6.3 Confirm sandbox cleanup (`git worktree list`, `git branch -a`) or append `BLOCKED:` and stop.
