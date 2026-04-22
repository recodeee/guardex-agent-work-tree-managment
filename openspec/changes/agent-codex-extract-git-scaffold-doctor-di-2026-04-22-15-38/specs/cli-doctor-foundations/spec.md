## MODIFIED Requirements

### Requirement: Typed protected-main doctor sandbox lifecycle
The system SHALL keep the protected-main `gx doctor` sandbox path behaviorally equivalent while moving the lifecycle sequencing out of `src/cli/main.js` and into a dedicated doctor module.

#### Scenario: Protected-main doctor lifecycle is extracted without behavior drift
- **GIVEN** `gx doctor` runs on a protected local base branch
- **WHEN** the protected-main doctor flow creates a sandbox, runs nested doctor, auto-commits repairs, and finishes through the PR path
- **THEN** `src/cli/main.js` delegates that lifecycle to `src/doctor/index.js`
- **AND** the observable output and success/failure behavior remain unchanged
- **AND** the existing protected-main doctor regression tests still pass.
