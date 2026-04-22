## ADDED Requirements

### Requirement: Setup installs only repo-local state plus hook shims

`gx setup` and `gx doctor` SHALL keep the managed repo footprint limited to repo-specific state, guidance, and hook dispatch shims.

#### Scenario: setup installs the zero-copy footprint

- **GIVEN** a repo opts into Guardex
- **WHEN** `gx setup` runs
- **THEN** it installs the managed AGENTS block, `.githooks/*` dispatch shims, `.omx/.omc` scaffold, lock registry state, and the managed `.gitignore` block
- **AND** it does not install repo-local workflow command shims under `scripts/`
- **AND** it does not copy workflow implementations, repo-local Codex/Claude skills, or inject Guardex-managed `agent:*` helper scripts into `package.json`

#### Scenario: doctor repairs the zero-copy footprint without restoring workflow shims

- **GIVEN** a repo already uses the zero-copy Guardex surface
- **WHEN** `gx doctor` repairs drift
- **THEN** it restores the managed AGENTS block, hook shims, lock registry, `.omx/.omc` scaffold, and managed `.gitignore` entries as needed
- **AND** it does not recreate repo-local workflow command shims, copied workflow implementations, repo-local skills, or Guardex-managed `agent:*` package scripts

### Requirement: Workflow commands run directly from the CLI

The CLI SHALL expose the Guardex workflow directly without requiring repo-local command shims to exist.

#### Scenario: direct CLI workflow commands succeed in a zero-copy repo

- **GIVEN** a repo with the zero-copy Guardex install surface
- **WHEN** a user runs `gx branch start`, `gx branch finish`, `gx branch merge`, `gx locks claim`, `gx worktree prune`, `gx finish`, or `gx cleanup`
- **THEN** the command executes using package-owned logic
- **AND** it does not require `scripts/agent-branch-*.sh`, `scripts/agent-file-locks.py`, `scripts/review-bot-watch.sh`, `scripts/codex-agent.sh`, or `scripts/openspec/*.sh` to exist in the repo

### Requirement: Hook shims remain tiny dispatchers

Installed repo hooks SHALL continue delegating to CLI-owned hook logic instead of embedding guard behavior inline.

#### Scenario: pre-commit hook is a shim

- **GIVEN** `gx setup` installed repo hooks
- **WHEN** `.githooks/pre-commit` is inspected or executed
- **THEN** it delegates to `gx hook run pre-commit`
- **AND** the guarded pre-commit behavior still enforces the same branch and lock rules

### Requirement: Migration removes repo-local workflow shims

The CLI SHALL provide a migration path from the partial CLI-owned surface to the zero-copy surface.

#### Scenario: migrate removes leftover workflow shims

- **GIVEN** a repo still contains Guardex-managed workflow command shims under `scripts/`, copied repo-local skills, or injected `agent:*` package scripts
- **WHEN** `gx migrate` runs
- **THEN** it replaces hooks with dispatch shims when needed
- **AND** it removes the leftover repo-local workflow command shims and managed `agent:*` script injections
- **AND** it removes repo-local Guardex skill copies when matching user-level installs are present
- **AND** it leaves the AGENTS block, `.omx/.omc` scaffold, lock registry, and managed `.gitignore` in the zero-copy form

### Requirement: Status and doctor ignore removed workflow shims

Guardex health checks SHALL treat the zero-copy footprint as authoritative.

#### Scenario: status reports healthy without repo-local workflow shims

- **GIVEN** a repo is fully migrated to the zero-copy Guardex surface
- **WHEN** `gx status --strict` or `gx doctor` inspects the repo
- **THEN** missing repo-local workflow command shims do not count as drift
- **AND** health reporting focuses on the managed AGENTS block, hook shims, `.omx/.omc` scaffold, lock registry, and managed `.gitignore`
