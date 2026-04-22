# Plan Phases: agent-codex-vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05

One entry per phase. Checkbox marks map to: `x` = completed, `>` = in progress, space = pending.
Indented sub-bullets are optional metadata consumed by the Plans UI:

- `session`: which agent kind runs the phase (`codex` / `claude`).
- `checkpoints`: comma-separated role checkpoint ids delivered within the phase.
- `summary`: one short sentence rendered under the phase title.

One phase is intended to fit into a single Codex or Claude session task.

- [x] [PH01] Audit shipped Active Agents behavior and capture the follow-up scope
  - session: codex
  - checkpoints: P1
  - summary: Confirm the real gap list: root `logo.png` exists, installer copies only extension folders, and grouped state/lock fallback behavior already ships.

- [ ] [PH02] Decide icon packaging and source-of-truth rules
  - session: codex
  - checkpoints: A1, C1
  - summary: Choose whether to keep mirrored `vscode/` + `templates/` sources or collapse them, and lock the icon-asset strategy.

- [ ] [PH03] Ship branding plus only the missing runtime delta
  - session: codex
  - checkpoints: E1
  - summary: Add the branded icon first, then touch `extension.js` or `session-schema.js` only if the audit proves a requested runtime behavior is still absent.

- [ ] [PH04] Refresh docs and focused regression coverage
  - session: codex
  - checkpoints: W1, V1
  - summary: Update install/docs language, add payload/runtime tests, and collect operator-facing evidence.

- [ ] [PH05] Validate and finish the lane
  - session: codex
  - checkpoints: E1, V1
  - summary: Run focused verification, validate OpenSpec artifacts, then finish with `gx branch finish --via-pr --wait-for-merge --cleanup`.
