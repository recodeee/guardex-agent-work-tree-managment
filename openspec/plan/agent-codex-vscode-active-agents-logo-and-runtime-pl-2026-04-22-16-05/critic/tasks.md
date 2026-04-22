# critic tasks

## 1. Spec

- [ ] 1.1 Validate that the plan stays delta-based and does not reopen already-landed Active Agents features without evidence.
- [ ] 1.2 Validate that risks, consequences, and mitigations are explicit for asset packaging, mirrored sources, and finish-flow cleanup.

## 2. Tests

- [ ] 2.1 Validate that every acceptance criterion maps to a concrete proof surface: installed asset, focused tests, OpenSpec validation, or merge evidence.
- [ ] 2.2 Validate that the verification steps are concrete and reproducible from the sandbox worktree.

## 3. Implementation

- [ ] 3.1 Produce a verdict (`APPROVE`, `ITERATE`, or `REJECT`) on the plan and call out any unnecessary runtime work.
- [ ] 3.2 Confirm revised drafts resolve prior findings before approval.
- [ ] 3.3 Publish final quality/risk sign-off notes.

## 4. Checkpoints

- [ ] [C1] READY - Quality gate checkpoint

## 5. Collaboration

- [ ] 5.1 Owner recorded this lane before edits.
- [ ] 5.2 Record joined agents / handoffs, or mark `N/A` when solo.

## 6. Cleanup

- [ ] 6.1 If this lane owns finalization, run `gx branch finish --branch agent/codex/vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05 --base main --via-pr --wait-for-merge --cleanup`.
- [ ] 6.2 Record PR URL + final `MERGED` state in the handoff.
- [ ] 6.3 Confirm sandbox cleanup (`git worktree list`, `git branch -a`) or append `BLOCKED:` and stop.
