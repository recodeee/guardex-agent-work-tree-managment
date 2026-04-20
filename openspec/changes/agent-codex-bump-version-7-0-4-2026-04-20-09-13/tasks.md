## 1. Specification

- [x] 1.1 Finalized scope and acceptance criteria for `agent-codex-bump-version-7-0-4-2026-04-20-09-13` around npm publish collision recovery and release-note sync.
- [x] 1.2 Defined normative requirements in `specs/bump-version-7-0-4/spec.md`.

## 2. Implementation

- [x] 2.1 Bumped package metadata version from `7.0.3` to `7.0.4`.
- [x] 2.2 Added `README.md` release-note entry for `v7.0.4`.

## 3. Verification

- [x] 3.1 Ran targeted verification commands (`node -p "require('./package.json').version"` and `npm pack --dry-run`) to confirm version metadata and package shape.
- [x] 3.2 Ran `openspec validate agent-codex-bump-version-7-0-4-2026-04-20-09-13 --type change --strict`.
- [x] 3.3 Ran `openspec validate --specs`.

## 4. Cleanup

- [x] 4.1 After successful merge, run `bash scripts/agent-worktree-prune.sh --base main --delete-branches --delete-remote-branches` so merged sandbox branch/worktree artifacts are removed.
