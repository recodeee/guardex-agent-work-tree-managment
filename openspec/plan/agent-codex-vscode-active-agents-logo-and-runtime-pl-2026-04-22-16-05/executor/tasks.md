# executor tasks

## 1. Spec

- [ ] 1.1 Audit the current extension against the requested brief and mark which behaviors already ship before editing code.
- [ ] 1.2 Freeze the touched-file list before coding starts: `logo.png`, extension asset path(s), `package.json`, installer/tests/docs, and only the runtime files that remain missing after audit.

## 2. Tests

- [ ] 2.1 Add or update focused tests for the packaged icon asset and any runtime delta that survives the audit.
- [ ] 2.2 Define the smoke path: local install, installed payload inspection, and focused Node test execution.

## 3. Implementation

- [ ] 3.1 Ship the branded icon lane first.
- [ ] 3.2 Apply runtime/provider changes only for missing deltas proven by the audit.
- [ ] 3.3 Sync mirrored sources, docs, and focused verification evidence before handoff.

## 4. Checkpoints

- [ ] [E1] READY - Execution start checkpoint

## 5. Collaboration

- [ ] 5.1 Owner recorded this lane before edits.
- [ ] 5.2 Record joined agents / handoffs, or mark `N/A` when solo.

## 6. Cleanup

- [ ] 6.1 If this lane owns finalization, run `gx branch finish --branch agent/codex/vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05 --base main --via-pr --wait-for-merge --cleanup`.
- [ ] 6.2 Record PR URL + final `MERGED` state in the handoff.
- [ ] 6.3 Confirm sandbox cleanup (`git worktree list`, `git branch -a`) or append `BLOCKED:` and stop.
