## MODIFIED Requirements

### Requirement: Module seams mirror operational responsibility
The CLI SHALL keep git/worktree, scaffold/template, and doctor lifecycle helper ownership in their extracted `src/` modules instead of redefining those seams in `src/cli/main.js`.

#### Scenario: Git and scaffold helper seams stay single-source
- **WHEN** maintainers inspect `src/cli/main.js`
- **THEN** git/worktree helpers are imported from `src/git/index.js`
- **AND** scaffold/template/settings helpers are imported from `src/scaffold/index.js`
- **AND** `src/cli/main.js` does not redefine those helpers locally.

### Requirement: CLI module wiring is direct after extraction
The modularized CLI SHALL wire extracted modules through direct exports/imports instead of constructor-style dependency bags.

#### Scenario: Factory wrappers are removed after seam extraction
- **WHEN** maintainers inspect the runtime modules after this cleanup
- **THEN** `src/cli/main.js` does not define `getSandboxApi()`, `getToolchainApi()`, or `getFinishApi()`
- **AND** `src/sandbox/index.js`, `src/toolchain/index.js`, and `src/finish/index.js` export direct functions instead of `create*Api` factories
- **AND** require-time/syntax regressions do not occur from the factory removal.
