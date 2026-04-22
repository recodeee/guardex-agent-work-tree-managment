# Plan Summary: agent-codex-vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05

- **Mode:** ralplan
- **Status:** draft ready for execution

## Context

- User request: create the plan and markdown task files now for the GitGuardex Active Agents extension follow-up.
- Observed branding gap: the VS Code extension details page still shows the default placeholder icon, while the repo already has a root `logo.png`.
- Current implementation reality: grouped state buckets, repo `CHANGES`, lock-aware rows, and `AGENT.lock` fallback already exist in the extension code and prior change specs.
- Packaging constraint: `scripts/install-vscode-active-agents-extension.js` copies only `vscode/guardex-active-agents/` (falling back to `templates/vscode/guardex-active-agents/`), so any icon must live inside the copied extension tree.

## Desired Outcome

- Produce one execution-ready board that ships the branded icon, audits the requested runtime brief against current behavior, and limits code changes to missing deltas.

## Scope Boundaries

- In scope: extension icon packaging, `package.json` icon metadata, mirrored extension-source parity, runtime delta audit, focused docs/tests, OpenSpec validation, and finish-flow cleanup.
- Out of scope until audit proves otherwise: rewriting the tree provider, re-adding already-landed group/change/lock features, or broad repo-wide test churn.
