## Why

- `src/cli/main.js` is still over 5,500 lines and retains the remaining git/worktree, scaffold/template, and protected-main doctor lifecycle clusters.
- Those clusters keep the most sensitive behavior in the least reviewable file and force `src/sandbox`, `src/toolchain`, and `src/finish` to keep constructor-style dependency bags.
- The requested outcome is a payoff-first extraction pass: move the remaining helper seams to owned modules, then delete the DI wrappers so the CLI reads as direct module wiring instead of a service locator.

## What Changes

- Move the remaining git/worktree helpers from `src/cli/main.js` into `src/git/index.js`.
- Move the remaining managed-file, template, JSONC, and repo-settings helpers from `src/cli/main.js` into `src/scaffold/index.js`.
- Extract the protected-main doctor sandbox lifecycle and related protected-base sandbox helpers into `src/doctor/index.js`.
- Convert `src/sandbox/index.js`, `src/toolchain/index.js`, and `src/finish/index.js` to direct modules and remove `getSandboxApi()`, `getToolchainApi()`, and `getFinishApi()` from `src/cli/main.js`.

## Impact

- Primary surfaces: `src/cli/main.js`, `src/git/index.js`, `src/scaffold/index.js`, new `src/doctor/index.js`, `src/sandbox/index.js`, `src/toolchain/index.js`, `src/finish/index.js`, and focused CLI regression tests.
- Main risk surface is `gx doctor` on protected branches plus `gx finish` auto-commit/sync behavior, so the pass must extend behavior-lock coverage first and rerun doctor/install/finish-adjacent suites after each extraction stage.
- This is an internal cleanup only; command names, output wording, and zero-copy CLI behavior must stay stable.
