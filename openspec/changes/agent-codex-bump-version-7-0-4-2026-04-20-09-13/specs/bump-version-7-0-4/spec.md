## ADDED Requirements

### Requirement: Publish version must advance past last published release
When a publish attempt fails due to an already published package version, the repository SHALL advance to the next patch version before retrying publish.

#### Scenario: Duplicate publish version is detected
- **WHEN** `npm publish` reports that the current version already exists on npm
- **THEN** package metadata is updated to the next patch version
- **AND** the new version is present in package metadata before the next publish attempt.

### Requirement: Version bumps must include README release notes
Any change that updates publish/version metadata SHALL include a matching release-note entry in `README.md`.

#### Scenario: Patch bump prepared for publish
- **WHEN** the package version is incremented for publish
- **THEN** `README.md` contains a release-note section for that exact version in the same change.
