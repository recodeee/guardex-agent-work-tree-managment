## Why

- `gx` already owns the branch, lock, hook, and cleanup behavior, but fresh installs still leave repo-local `scripts/*` workflow shims behind as a second command surface.
- That remaining shim layer keeps `doctor`, `setup`, status checks, docs, and templates coupled to files that do not hold repo-specific state.
- The result is still a distributed install model: the CLI is authoritative, but repos are treated as a file-distribution medium for command entrypoints and presence markers.

## What Changes

- Remove repo-local workflow shims from the managed install surface and make `gx` subcommands the only canonical workflow entrypoints for branch, finish, merge, lock, cleanup, review, and OpenSpec bootstrap flows.
- Keep repo-local hook shims only; each installed hook stays a tiny `gx hook run ...` dispatcher.
- Shrink the managed repo footprint to only repo-local state and guidance: managed AGENTS block, hook shims, `.omx/.omc` scaffold, lock registry, and managed `.gitignore`.
- Teach `gx migrate` to remove leftover repo-local workflow shims and legacy command-script injections while preserving real repo-local state.
- Simplify `gx doctor` and related health checks so they validate the smaller install surface and stop treating missing repo-local workflow shims as drift.

## Scope

- `bin/multiagent-safety.js`
- managed install/doctor/migrate/status logic
- hook templates and docs/templates that still mention repo-local workflow shims
- install/migrate/status tests

## Risks

- Existing repos may still rely on `scripts/*` paths in local habits, CI, or agent prompts; migration and docs need a clear deprecation path.
- `gx finish`, `gx merge`, and `gx cleanup` currently still use repo-local shim presence as an install marker; removing that check must not weaken repo-root validation.
- `doctor` can shrink materially, but protected-branch AGENTS/hook repair still needs a deliberate posture instead of silently regressing branch-safety guarantees.
