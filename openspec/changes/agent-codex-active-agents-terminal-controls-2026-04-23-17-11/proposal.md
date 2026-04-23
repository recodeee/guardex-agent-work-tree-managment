## Why

The VS Code Active Agents tree already exposes session-scoped inline actions, but the current mix still forces the user back into raw repo surfaces for the most common runtime operation: jump straight to the terminal where the agent is running. The inline `Open Diff` action is lower-value in this operator loop, and the current `Stop` action runs a background stop command instead of signaling the live terminal first.

## What Changes

- Replace the session-row `Open Diff` inline action with a `Show Terminal` action that reveals the matching integrated terminal for the selected session when one is available.
- Fallback to opening a worktree-scoped terminal when no live integrated terminal can be matched to the session yet.
- Update the `Stop` action so it sends `Ctrl+C` to the matching session terminal first and only falls back to `gx agents stop --pid` when no live terminal can be found.
- Refresh the focused Active Agents tests and extension manifests for the new terminal-first operator flow.

## Impact

- Affected surfaces: `vscode/guardex-active-agents/*`, `templates/vscode/guardex-active-agents/*`, `test/vscode-active-agents-session-state.test.js`, and this change workspace.
- No Active Agents session-schema changes are required; the extension can match live terminals from the existing session `pid`.
