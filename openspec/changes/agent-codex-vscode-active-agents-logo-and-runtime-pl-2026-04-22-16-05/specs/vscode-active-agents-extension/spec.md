## ADDED Requirements

### Requirement: Active Agents ships a branded extension icon
The GitGuardex Active Agents extension SHALL package a branded icon that resolves from inside the installed extension directory.

#### Scenario: Local install includes packaged icon asset
- **WHEN** `scripts/install-vscode-active-agents-extension.js` installs the extension
- **THEN** the installed extension directory contains an icon asset derived from the repo `logo.png`
- **AND** `vscode/guardex-active-agents/package.json` points its `icon` field at that packaged asset
- **AND** VS Code can show the branded icon instead of the default placeholder on the extension details page.

### Requirement: Mirrored extension sources stay consistent
User-visible Active Agents extension behavior SHALL stay aligned across the duplicated `vscode/guardex-active-agents/` and `templates/vscode/guardex-active-agents/` trees unless the change intentionally collapses them to one canonical source.

#### Scenario: Branding or runtime changes touch duplicated extension files
- **WHEN** this change updates extension packaging, manifest metadata, runtime behavior, or bundled assets
- **THEN** the same shipped behavior is present in both source trees
- **OR** the change removes one source tree and updates installer/tests to the new single source of truth in the same change
- **AND** focused regression coverage validates the shipped install payload.

### Requirement: Runtime follow-up stays delta-based
This follow-up SHALL preserve the already-shipped Active Agents grouped tree behavior and only add runtime changes that are still missing after audit.

#### Scenario: Runtime brief overlaps already-landed features
- **WHEN** the executor compares the requested runtime brief against the current extension code and prior Active Agents change specs
- **THEN** grouped `ACTIVE AGENTS` and repo `CHANGES` behavior, group ordering, lock awareness, and `AGENT.lock` fallback remain intact
- **AND** only unsatisfied deltas are added to `extension.js`, `session-schema.js`, related docs, or tests
- **AND** the change does not reimplement already-shipped behavior solely because it appeared in the user brief.
