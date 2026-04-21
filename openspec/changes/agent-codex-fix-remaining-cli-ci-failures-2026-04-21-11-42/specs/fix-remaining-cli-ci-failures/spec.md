## ADDED Requirements

### Requirement: branch finish honors stored agent base metadata
Guardex SHALL use the stored `branch.<agent-branch>.guardexBase` value when finishing an agent branch unless the caller explicitly overrides `--base`.

#### Scenario: finish runs in a main-only repo
- **GIVEN** an agent branch created from `main`
- **AND** Guardex stored `branch.<agent-branch>.guardexBase=main`
- **WHEN** `scripts/agent-branch-finish.sh --branch <agent-branch>` runs without an explicit `--base`
- **THEN** Guardex SHALL finish against `main`
- **AND** it SHALL NOT fall back to `dev`.

### Requirement: branch start prints the resolved finish base
Guardex SHALL print the actual resolved base branch in the suggested finish command emitted by `agent-branch-start`.

#### Scenario: protected base is main
- **GIVEN** an agent branch created from `main`
- **WHEN** `scripts/agent-branch-start.sh` prints next steps
- **THEN** the suggested finish command SHALL include `--base main`
- **AND** it SHALL match the stored `guardexBase` metadata.

### Requirement: CI regression tests track current Guardex CLI output
Focused CI coverage SHALL match the current Guardex naming and reporting contract for doctor/setup/self-update/codex-agent flows.

#### Scenario: current naming contract is exercised
- **WHEN** the doctor and codex-agent regression tests run
- **THEN** they SHALL expect current `agent/codex/...` branch names and `agent__codex__...` worktree paths
- **AND** they SHALL match the current `gitguardex` output strings rather than deprecated `guardex` or older role-specific naming.
