## Why

- `main` still fails the `CI` workflow after `7.0.14` because several unit tests no longer match the current Guardex CLI/output contract.
- One runtime path is also still wrong: `agent-branch-finish.sh` ignores `branch.<agent>.guardexBase` and falls back to `dev`, which breaks `main`-only finish flows.

## What Changes

- Make `agent-branch-finish.sh` and its install template prefer stored `guardexBase` branch metadata before falling back to repo defaults.
- Make `agent-branch-start.sh` and its install template print the resolved base branch in the suggested finish command instead of hardcoding `dev`.
- Update focused test expectations to the current Guardex naming and status/output contract (`agent/codex/...`, `scripts/*`, current self-update entrypoint behavior, and current doctor reporting text).

## Impact

- Affected runtime surfaces:
  - `scripts/agent-branch-start.sh`
  - `scripts/agent-branch-finish.sh`
  - matching template scripts
- Affected regression coverage:
  - `test/install.test.js`
  - `test/metadata.test.js`
- Risk is narrow and limited to branch-finish base resolution plus CLI/test expectation parity.
