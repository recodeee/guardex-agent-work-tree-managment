## Why

- The VS Code extension details page for `GitGuardex Active Agents` still shows the default placeholder icon even though the repo already ships a root `logo.png`.
- The current Active Agents implementation already covers more of the user's requested runtime behavior than the brief assumes, so execution needs a delta-only plan instead of a rewrite.
- We need one scoped follow-up change that ties branding, install packaging, duplicated extension sources, runtime polish audit, docs, tests, and finish-flow verification together.

## What Changes

- Add a branded extension-icon lane that packages a copy of the repo `logo.png` inside the installable extension payload and wires the manifest to it.
- Audit the shipped Active Agents companion against the requested runtime brief and only implement still-missing deltas after that audit.
- Keep `vscode/guardex-active-agents/*`, `templates/vscode/guardex-active-agents/*`, install behavior, README guidance, and focused regression coverage aligned.

## Impact

- Affected surfaces: `logo.png`, `vscode/guardex-active-agents/*`, `templates/vscode/guardex-active-agents/*`, `scripts/install-vscode-active-agents-extension.js`, `test/vscode-active-agents-session-state.test.js`, and README surfaces that describe local install/use.
- Primary risk is duplicate work: grouped state sections, repo `CHANGES`, lock-aware decorations, and `AGENT.lock` fallback already exist, so the implementation lane must prove any runtime gap before editing provider logic.
- Packaging risk is narrow but real: the extension icon must resolve from inside the installed extension directory, not from the repo root.
