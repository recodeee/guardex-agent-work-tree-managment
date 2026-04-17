## 1. Specification

- [x] 1.1 Confirm restore scope includes guardex hooks/scripts/AGENTS plus related docs needed for merge safety.
- [x] 1.2 Confirm release bump scope is the next patch version for npm publish (`5.0.17`).

## 2. Implementation

- [x] 2.1 Carry restored guardex workflow changes onto this branch and keep them committed.
- [x] 2.2 Restore publishable guardex package manifest fields and set package version to `5.0.17`.
- [x] 2.3 Add release note entry for `v5.0.17`.

## 3. Verification

- [x] 3.1 Validate shell scripts/hooks syntax with `bash -n`.
- [x] 3.2 Validate package metadata with `node -p "require('./package.json').version"`.
- [x] 3.3 Validate publish packaging with `npm pack --dry-run`.

## 4. Cleanup

- [x] 4.1 Branch is ready for `agent-branch-finish` merge flow to `main`.
