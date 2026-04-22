# writer tasks

## 1. Spec

- [ ] 1.1 Validate the docs audience: operators installing the local VS Code companion and developers maintaining the duplicated extension sources.
- [ ] 1.2 Keep terminology consistent across plan artifacts, extension README copy, and any root README changes.

## 2. Tests

- [ ] 2.1 Define a docs verification checklist covering icon packaging, install commands, reload guidance, and scope notes about runtime deltas.
- [ ] 2.2 Validate command/help text examples against the actual installer and finish flow.

## 3. Implementation

- [ ] 3.1 Update `vscode/guardex-active-agents/README.md` and any root README/install guidance touched by the branding or runtime delta.
- [ ] 3.2 Add or refine operator examples for install, reload, and expected branded result.
- [ ] 3.3 Publish a final docs change summary with references.

## 4. Checkpoints

- [ ] [W1] READY - Docs update checkpoint

## 5. Collaboration

- [ ] 5.1 Owner recorded this lane before edits.
- [ ] 5.2 Record joined agents / handoffs, or mark `N/A` when solo.

## 6. Cleanup

- [ ] 6.1 If this lane owns finalization, run `gx branch finish --branch agent/codex/vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05 --base main --via-pr --wait-for-merge --cleanup`.
- [ ] 6.2 Record PR URL + final `MERGED` state in the handoff.
- [ ] 6.3 Confirm sandbox cleanup (`git worktree list`, `git branch -a`) or append `BLOCKED:` and stop.
