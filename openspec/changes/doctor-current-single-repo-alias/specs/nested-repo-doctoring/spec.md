## ADDED Requirements

### Requirement: doctor current alias limits repairs to the target repo
The system SHALL support `gx doctor --current` as a doctor-only alias for the existing single-repo repair path.

#### Scenario: current alias skips nested repo repairs
- **GIVEN** a parent repo contains a nested standalone git repo with Guardex-managed drift
- **WHEN** `gx doctor --target <parent-repo> --current` runs
- **THEN** the doctor flow SHALL repair only `<parent-repo>`
- **AND** the nested repo SHALL not be traversed or repaired during that run.
