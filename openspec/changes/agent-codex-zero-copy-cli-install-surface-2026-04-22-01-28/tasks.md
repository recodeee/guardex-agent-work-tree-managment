## 1. Spec

- [x] 1.1 Capture the zero-copy repo footprint and direct-CLI workflow requirements in `specs/zero-copy-cli-install-surface/spec.md`.
- [x] 1.2 Record the rationale, migration posture, and doctor simplification target in `proposal.md`.

## 2. Tests

- [x] 2.1 Update install/setup/doctor/status coverage so zero-copy repos stay healthy without any Guardex-managed workflow shims under `scripts/`.
- [x] 2.2 Add regression coverage proving direct CLI commands (`gx branch ...`, `gx locks ...`, `gx finish`, `gx cleanup`, `gx migrate`) work without repo-local workflow shims present.
- [x] 2.3 Add migration coverage that removes leftover `scripts/*` command shims while preserving hook shims, AGENTS, `.omx/.omc`, lock registry, and managed `.gitignore`.

## 3. Implementation

- [x] 3.1 Remove repo-local workflow command shims from the managed install/repair footprint (`SCRIPT_SHIMS`, related required-path lists, critical-path lists, and docs/templates).
- [x] 3.2 Remove CLI runtime checks that still require repo-local workflow shims to exist before `gx finish`, `gx merge`, `gx cleanup`, or related direct commands run.
- [x] 3.3 Update `gx migrate` cleanup to delete leftover workflow command shims by default and keep only the zero-copy footprint.
- [x] 3.4 Simplify status/doctor/install output and drift detection so missing repo-local workflow shims no longer trigger repair noise.
- [x] 3.5 Update README, managed AGENTS guidance, and skill/prompt references to teach `gx ...` as the only workflow command surface.

## 4. Verification

- [x] 4.1 Run `node --check bin/multiagent-safety.js`. Result: passed on `2026-04-22`.
- [x] 4.2 Run the focused install/migrate/status suite: `node --test test/install.test.js`. Result: passed `135/135` on `2026-04-22`.
- [x] 4.3 Run `openspec validate agent-codex-zero-copy-cli-install-surface-2026-04-22-01-28 --type change --strict`.
- [x] 4.4 Run `openspec validate --specs`.

## 5. Cleanup

- [x] 5.1 Reconcile the shipped README/install docs with the zero-copy repo footprint and note any intentional compatibility leftovers. README now documents the hook-only install footprint and notes that `gx migrate` removes leftover workflow shims while the CLI still honors repo-local `scripts/review-bot-watch.sh` / `scripts/codex-agent.sh` during migration.
- [x] 5.2 Finish the agent branch via PR merge + cleanup (`gx finish --via-pr --wait-for-merge --cleanup` or `bash scripts/agent-branch-finish.sh --branch <agent-branch> --base <base-branch> --via-pr --wait-for-merge --cleanup`).
- [x] 5.3 Record PR URL + final `MERGED` evidence in the completion handoff.

Completion note: PR #271 (`https://github.com/recodeee/gitguardex/pull/271`) reached `MERGED` at `2026-04-22T07:16:58Z` with merge commit `7c5bd067ec2376464b82caf20dadf04938448a82` (`7c5bd06`). In the nested `gitguardex` repo, `git branch -a --list '*zero-copy-cli-install-surface-2026-04-22-01-28*'` returns no remaining source branch, and `git worktree list` shows no leftover zero-copy task worktree.
