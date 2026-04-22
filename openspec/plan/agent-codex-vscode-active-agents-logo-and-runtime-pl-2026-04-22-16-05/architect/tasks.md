# architect tasks

## 1. Spec

- [ ] 1.1 Decide whether this lane keeps `vscode/guardex-active-agents/` and `templates/vscode/guardex-active-agents/` mirrored or intentionally collapses them to one canonical source.
- [ ] 1.2 Lock the packaged-icon strategy: committed asset copy inside the extension tree versus any generated/install-time alternative.

## 2. Tests

- [ ] 2.1 Define compatibility checks for VS Code manifest `icon` metadata, installer payload copying, and mirrored-source parity.
- [ ] 2.2 Validate that any runtime follow-up preserves grouped `ACTIVE AGENTS` / `CHANGES`, lock-aware rows, and `AGENT.lock` fallback behavior.

## 3. Implementation

- [ ] 3.1 Compare the viable options: in-place patch, source-tree canonicalization, or installer-time asset injection.
- [ ] 3.2 Record the chosen architecture and guardrails in `planner/plan.md`.
- [ ] 3.3 Publish architecture sign-off notes for downstream execution.

## 4. Checkpoints

- [ ] [A1] READY - Architecture review checkpoint

## 5. Collaboration

- [ ] 5.1 Owner recorded this lane before edits.
- [ ] 5.2 Record joined agents / handoffs, or mark `N/A` when solo.

## 6. Cleanup

- [ ] 6.1 If this lane owns finalization, run `gx branch finish --branch agent/codex/vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05 --base main --via-pr --wait-for-merge --cleanup`.
- [ ] 6.2 Record PR URL + final `MERGED` state in the handoff.
- [ ] 6.3 Confirm sandbox cleanup (`git worktree list`, `git branch -a`) or append `BLOCKED:` and stop.
