## ADDED Requirements

### Requirement: `gx doctor` keeps recursive progress visible
The human-readable `gx doctor` workflow SHALL keep progress visible while recursive child doctor runs execute, so large nested workspaces do not appear frozen.

#### Scenario: nested doctor targets stream visible progress
- **GIVEN** `gx doctor` is running recursively across multiple git repos
- **WHEN** a nested repo doctor run starts and then completes
- **THEN** the CLI SHALL print a target line for that repo before the child run
- **AND** it SHALL print a completion line with the same target plus elapsed time after that repo finishes

### Requirement: doctor sweep respects `--no-wait-for-merge`
The doctor auto-finish sweep SHALL honor the doctor wait mode when it delegates to `scripts/agent-branch-finish.sh`.

#### Scenario: no-wait mode is forwarded into ready-branch cleanup
- **GIVEN** a ready local `agent/*` branch exists during `gx doctor --no-wait-for-merge`
- **WHEN** doctor invokes the auto-finish sweep for that branch
- **THEN** it SHALL call the finish script with `--no-wait-for-merge`
- **AND** it SHALL not silently fall back to `--wait-for-merge`

### Requirement: doctor sweep output stays compact by default
The human-readable auto-finish sweep SHALL show concise actionable branch results by default and SHALL preserve the raw failure text behind an explicit verbose flag.

#### Scenario: default doctor output summarizes a long finish failure
- **GIVEN** an auto-finish failure emits a long rebase-conflict command trace
- **WHEN** `gx doctor` runs without `--verbose-auto-finish`
- **THEN** the default branch detail line SHALL summarize the actionable reason instead of dumping the full `git -C ... rebase --continue` command

#### Scenario: verbose doctor output keeps the raw finish failure text
- **GIVEN** the same auto-finish failure
- **WHEN** `gx doctor --verbose-auto-finish` runs
- **THEN** the printed branch detail SHALL include the original failure text
