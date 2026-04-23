## ADDED Requirements

### Requirement: Active Agents raw tree uses bundled workflow icons

The Active Agents raw tree SHALL use bundled semantic workflow icons for OpenSpec folders and files when no higher-priority status icon override applies.

#### Scenario: OpenSpec folders use semantic icons in the raw tree

- **GIVEN** the Active Agents raw tree renders OpenSpec folder nodes such as `changes` and `specs`
- **WHEN** those tree items are displayed
- **THEN** `changes` uses the bundled OpenSpec icon asset
- **AND** `specs` uses the bundled spec icon asset

#### Scenario: OpenSpec files use semantic icons in the raw tree

- **GIVEN** the Active Agents raw tree renders `proposal.md`, `tasks.md`, or `spec.md` nodes without lock/warning overrides
- **WHEN** those file items are displayed
- **THEN** each node uses the bundled semantic icon asset that matches the shipped file-icon manifest

#### Scenario: Warning icons still override bundled file icons

- **GIVEN** an Active Agents change row carries an explicit warning icon or foreign-lock warning state
- **WHEN** that row is rendered
- **THEN** the warning icon remains visible instead of a bundled workflow file icon
