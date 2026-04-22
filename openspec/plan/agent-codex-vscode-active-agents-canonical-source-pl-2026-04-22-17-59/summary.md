# Plan Summary: agent-codex-vscode-active-agents-canonical-source-pl-2026-04-22-17-59

- **Mode:** ralplan
- **Status:** planned; `P1`, `A1`, and `C1` are ready, execution pending

## Context

- User asked to continue the VS Code extension plan rather than reopen implementation blindly.
- Current `main` already contains the recent Active Agents follow-ups: version `0.0.6`, inspect/session context, `gx`-driven stop flow, git-native diff opens, and focused tests that read the live `vscode/` source tree.
- The remaining durable issue is source-of-truth drift. The install helper resolves `vscode/guardex-active-agents/` first, but setup/doctor still depend on `templates/vscode/guardex-active-agents/*`, and the managed-file pipeline is text-only even though the extension now ships `icon.png`.

## Desired Outcome

- Publish one execution-ready continuation board that collapses manual dual editing, makes asset propagation truthful, and keeps runtime behavior unchanged.

## Scope Boundaries

- In scope: canonical-source decision, setup/doctor/scaffold source-path changes, binary-safe asset copying, duplicate-tree retirement or derivation, focused docs/tests, and finish-flow planning.
- Out of scope: new Active Agents commands, new tree grouping/inspect/runtime features, another icon redesign pass, or broad repo-wide cleanup unrelated to the extension source tree.

## Planning Evidence

- Audit closed the stale follow-up notes before planning: the icon-size and bugfix notes no longer represent real missing behavior on `main`.
- Planning gates are closed for strategy only: `P1`, `A1`, and `C1` now point at one canonical-source migration rather than another runtime/UI lane.

## Coordinator Disposition

- Wave splitting is not needed yet. The next step is one bounded implementation lane on a fresh branch from `main`.
- Preferred authored source is `vscode/guardex-active-agents/`; the duplicated template tree should be removed or reduced to a generated/materialized copy rather than manually maintained.
