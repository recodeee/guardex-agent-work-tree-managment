## Definition of Done

This change is complete only when **all** of the following are true:

- Every checkbox below is checked.
- The agent branch reaches `MERGED` state on `origin` and the PR URL + state are recorded in the completion handoff.
- If any step blocks (test failure, conflict, ambiguous result), append a `BLOCKED:` line under section 4 explaining the blocker and **STOP**. Do not tick remaining cleanup boxes; do not silently skip the cleanup pipeline.

Handoff: 2026-04-23 15:11Z codex owns `vscode/guardex-active-agents/*`, `templates/vscode/guardex-active-agents/*`, `test/vscode-active-agents-session-state.test.js`, and this change workspace to replace the low-value `Open Diff` inline action with terminal-first runtime controls.

## 1. Specification

- [x] 1.1 Finalize proposal scope and acceptance criteria for `agent-codex-active-agents-terminal-controls-2026-04-23-17-11`.
- [x] 1.2 Define normative requirements in `specs/vscode-active-agents-extension/spec.md`.

## 2. Implementation

- [x] 2.1 Replace the session-row `Open Diff` inline action with `Show Terminal` in the live/template Active Agents manifests.
- [x] 2.2 Reveal the matching integrated terminal for a session when the stored session `pid` matches a VS Code terminal `processId`, and open a worktree terminal when no live match exists.
- [x] 2.3 Update `Stop` to send `Ctrl+C` to the matched session terminal first and keep `gx agents stop --pid` as the no-terminal fallback.
- [x] 2.4 Refresh focused tests plus mock terminal plumbing for the new terminal-first behavior.

## 3. Verification

- [x] 3.1 Run `node --test test/vscode-active-agents-session-state.test.js`.
- [x] 3.2 Run `openspec validate agent-codex-active-agents-terminal-controls-2026-04-23-17-11 --type change --strict`.
- [x] 3.3 Run `openspec validate --specs`.

Verification notes:
- `node --test test/vscode-active-agents-session-state.test.js` passed `52/52`.
- `openspec validate agent-codex-active-agents-terminal-controls-2026-04-23-17-11 --type change --strict` returned `Change 'agent-codex-active-agents-terminal-controls-2026-04-23-17-11' is valid`.
- `openspec validate --specs` returned `No items found to validate.` in this checkout.

## 4. Cleanup

- [ ] 4.1 Run `gx branch finish --branch "agent/codex/active-agents-terminal-controls-2026-04-23-17-11" --base main --via-pr --wait-for-merge --cleanup`.
- [ ] 4.2 Record the PR URL and final merge state (`MERGED`) in the completion handoff.
- [ ] 4.3 Confirm the sandbox worktree is gone (`git worktree list` no longer shows the agent path; `git branch -a` shows no surviving local/remote refs for the branch).
