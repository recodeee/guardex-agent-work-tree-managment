## Why

- The VS Code companion already ships bundled semantic icons for OpenSpec workflow files, but the Active Agents raw tree still falls back to generic folder/file icons for those same nodes.
- Operators scanning live agent lanes inside Active Agents cannot quickly distinguish `proposal.md`, `tasks.md`, `spec.md`, or OpenSpec folders without switching back to Explorer.

## What Changes

- Reuse the bundled file-icon manifest to resolve semantic SVG icons for Active Agents folder/file tree items when no higher-priority icon override is already set.
- Mirror the same behavior into the template extension source so fresh installs and workspace copies stay aligned.
- Add focused regression coverage for OpenSpec folder/file nodes in the Active Agents raw tree.

## Impact

- Affected surfaces: `vscode/guardex-active-agents/extension.js`, `templates/vscode/guardex-active-agents/extension.js`, and `test/vscode-active-agents-session-state.test.js`.
- Risk stays narrow: presentation-only behavior inside the VS Code Active Agents tree, with warning/lock icon overrides preserved.
