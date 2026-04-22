## Definition of Done

This change is complete only when **all** of the following are true:

- Every checkbox below is checked.
- The agent branch reaches `MERGED` state on `origin` and the PR URL + state are recorded in the completion handoff.
- If any step blocks (test failure, conflict, ambiguous result), append a `BLOCKED:` line under section 5 explaining the blocker and **STOP**. Do not tick remaining cleanup boxes; do not silently skip the cleanup pipeline.

## Handoff

- Handoff: change=`agent-codex-vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05`; branch=`agent/codex/vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05`; scope=`logo.png packaging for the Active Agents extension, delta-only runtime audit, mirrored source parity, focused tests/docs`; action=`continue in this sandbox, execute the phase board in openspec/plan/agent-codex-vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05/, and finish with gx branch finish after validation`.
- Copy prompt: Continue `agent-codex-vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05` on branch `agent/codex/vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05`. Work inside the existing sandbox, review `openspec/changes/agent-codex-vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05/tasks.md`, continue from the current state instead of creating a new sandbox, and when the work is done run `gx branch finish --branch agent/codex/vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05 --base main --via-pr --wait-for-merge --cleanup`.

## 1. Specification

- [x] 1.1 Finalize proposal scope around extension branding, install payload behavior, mirrored extension-source parity, and delta-only runtime follow-up.
- [x] 1.2 Define normative requirements in `specs/vscode-active-agents-extension/spec.md`.

## 2. Planning

- [x] 2.1 Create an execution-ready plan workspace under `openspec/plan/agent-codex-vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05/`.
- [x] 2.2 Replace generic role task scaffolds with concrete lanes for planner, architect, critic, executor, writer, and verifier.
- [ ] 2.3 Fold any later architect/critic review back into the plan before code edits start.

## 3. Implementation

- [ ] 3.1 Package a branded extension icon using the existing repo `logo.png` and wire it into the installed extension manifest.
- [ ] 3.2 Audit the current Active Agents code/specs against the requested runtime brief and only land still-missing deltas.
- [ ] 3.3 Keep `vscode/guardex-active-agents/*`, `templates/vscode/guardex-active-agents/*`, docs, and focused tests aligned.

## 4. Verification

- [ ] 4.1 Run focused extension/install coverage, including `node --test test/vscode-active-agents-session-state.test.js`.
- [ ] 4.2 Run `openspec validate agent-codex-vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05 --type change --strict`.
- [ ] 4.3 Run `openspec validate --specs`.

## 5. Cleanup (mandatory; run before claiming completion)

- [ ] 5.1 Run the cleanup pipeline: `gx branch finish --branch agent/codex/vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05 --base main --via-pr --wait-for-merge --cleanup`. This handles commit -> push -> PR create -> merge wait -> worktree prune in one invocation.
- [ ] 5.2 Record the PR URL and final merge state (`MERGED`) in the completion handoff.
- [ ] 5.3 Confirm the sandbox worktree is gone (`git worktree list` no longer shows the agent path; `git branch -a` shows no surviving local/remote refs for the branch).
