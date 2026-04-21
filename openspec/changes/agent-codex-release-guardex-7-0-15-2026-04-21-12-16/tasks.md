## 1. Specification

- [x] 1.1 Finalize proposal scope and acceptance criteria for `agent-codex-release-guardex-7-0-15-2026-04-21-12-16`.
- [x] 1.2 Define normative requirements in `specs/release-version-bump/spec.md`.

## 2. Implementation

- [x] 2.1 Bump `package.json`, `package-lock.json`, and `README.md` to the next publishable Guardex release version.
- [x] 2.2 No new runtime regression coverage was added because this change only updates release metadata for already-merged behavior.

## 3. Verification

- [x] 3.1 Run `node --check bin/multiagent-safety.js`, `node --test test/metadata.test.js`, and `npm pack --dry-run` for the release-only change. The metadata suite still contains a pre-existing `Doctor/fix` expectation mismatch unrelated to this version bump.
- [x] 3.2 Run `openspec validate agent-codex-release-guardex-7-0-15-2026-04-21-12-16 --type change --strict`.
- [x] 3.3 Run `openspec validate --specs`.

## 4. Completion

- [ ] 4.1 Finish the agent branch via PR merge + cleanup (`gx finish --via-pr --wait-for-merge --cleanup` or `bash scripts/agent-branch-finish.sh --branch <agent-branch> --base <base-branch> --via-pr --wait-for-merge --cleanup`).
- [ ] 4.2 Record PR URL + final `MERGED` state in the completion handoff.
- [ ] 4.3 Confirm sandbox cleanup (`git worktree list`, `git branch -a`) or capture a `BLOCKED:` handoff if merge/cleanup is pending.
