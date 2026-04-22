# ExecPlan: agent-codex-vscode-active-agents-canonical-source-pl-2026-04-22-17-59

This ExecPlan is a living document. Keep `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` current as work proceeds.

Follow repository guidance in `AGENTS.md` and keep this plan workspace as the execution source of truth.

## Purpose / Big Picture

After this plan lands, the Active Agents companion has one authored source of truth. Operators still install the same companion and see the same Source Control behavior, but Guardex setup/doctor/install all pull from a single canonical extension surface, including bundled assets like `icon.png`, so future extension work stops paying a manual twin-tree sync tax.

## Progress

- [x] (2026-04-22 16:02Z) Audit current `main` and compare the latest Active Agents notes against shipped behavior.
- [x] (2026-04-22 16:04Z) Draft architecture/tradeoff plan for canonical-source migration and downstream asset propagation.
- [x] (2026-04-22 16:06Z) Publish an execution-ready continuation board with planner/architect/critic checkpoints closed.

## Surprises & Discoveries

- Observation: The recent icon-size and bugfix notes are stale against `main`; stop-session routing, diff opening, versioning, and inspect/runtime work already shipped.
  Evidence: `vscode/guardex-active-agents/extension.js`, `vscode/guardex-active-agents/package.json`, `test/vscode-active-agents-session-state.test.js`
- Observation: The install helper already treats `vscode/guardex-active-agents/` as the primary source, while setup/doctor still materialize managed files from `templates/vscode/guardex-active-agents/*`.
  Evidence: `scripts/install-vscode-active-agents-extension.js`, `src/context.js`
- Observation: The managed-file copy path is text-only today, which is fine for JS/JSON/Markdown but incorrect for `icon.png`.
  Evidence: `src/scaffold/index.js`, `src/context.js`
- Observation: Current parity tests prevent drift by requiring live/template JS equality instead of removing the duplicated authored surface.
  Evidence: `test/metadata.test.js`

## Decision Log

- Decision: Use OpenSpec plan workspace as source of truth for this planning cycle.
  Rationale: Keeps planning artifacts in-repo and reviewable.
  Date/Author: 2026-04-22 / codex
- Decision: Keep `vscode/guardex-active-agents/` as the authored canonical source.
  Rationale: The local install helper, focused tests, README references, and runtime imports already anchor on `vscode/`, so moving the canonical source elsewhere would widen churn without fixing the real drift.
  Date/Author: 2026-04-22 / codex
- Decision: Treat setup/doctor materialization as the migration seam, not the runtime/UI layer.
  Rationale: The remaining defect is source-of-truth and asset propagation drift, not missing Active Agents behavior.
  Date/Author: 2026-04-22 / codex
- Decision: Execute the actual migration on a fresh implementation branch from `main`.
  Rationale: This branch is reserved for planning artifacts; keeping code edits on a separate execution lane preserves a clean handoff and truthful cleanup evidence.
  Date/Author: 2026-04-22 / codex

## Outcomes & Retrospective

Planning now isolates one real next step: canonicalize the authored extension surface and make downstream materialization truthful. The plan deliberately rejects another runtime/UI feature pass until a concrete missing behavior is proven.

## Completion Criteria For This Plan

- `summary.md`, `phases.md`, `checkpoints.md`, and the role `tasks.md` files agree on the same canonical-source scope.
- The execution lane names the concrete files/contracts that must move together.
- The acceptance criteria are testable without repo-wide noise.

## Context and Orientation

- `vscode/guardex-active-agents/`: current live companion source used by the install script, README references, and focused tests.
- `templates/vscode/guardex-active-agents/`: duplicate source tree still used by Guardex managed-repo scaffolding and parity tests.
- `scripts/install-vscode-active-agents-extension.js`: local install helper; currently resolves `vscode/` first and only falls back to `templates/`.
- `src/context.js`: declares the managed template file list for setup/doctor and currently lists only the text Active Agents files, not `icon.png`.
- `src/scaffold/index.js`: copies managed files from `TEMPLATE_ROOT` using UTF-8 reads/writes today.
- `src/doctor/index.js`: consumes the managed file contract and therefore must stay aligned with any source-path changes.
- `test/vscode-active-agents-session-state.test.js`: focused regression surface for install payload, manifest/version rules, runtime wiring, and extension activation.
- `test/metadata.test.js`: currently enforces direct equality between the live/template JS sources.

## Plan of Work

1. Audit every place that still assumes the Active Agents template copy is authored directly.
   Freeze the source-of-truth map across installer, setup/doctor contracts, metadata tests, and README/OpenSpec guidance before code edits.
2. Introduce a canonical-source materialization path.
   Prefer a small explicit mapping layer that lets setup/doctor copy the managed companion from `vscode/guardex-active-agents/` into downstream repos, including binary assets, instead of hardcoding `TEMPLATE_ROOT` for this surface.
3. Remove or demote manual duplicate authorship.
   Either delete `templates/vscode/guardex-active-agents/*` or convert it into a generated/materialized mirror that is never the primary edit surface.
4. Update docs and focused proofs.
   Replace live/template parity policing with checks that the canonical source, managed repo copy, and installed payload remain aligned.
5. Validate on a fresh execution lane and finish there.
   The implementation branch should run focused Node tests plus OpenSpec validation, then close with `gx branch finish --via-pr --wait-for-merge --cleanup`.

## Concrete Steps

List exact commands with working directory and short expected outcomes.

    cd /home/deadpool/Documents/recodee/gitguardex/.omx/agent-worktrees/<fresh-implementation-worktree>
    rg -n "guardex-active-agents|icon.png|TEMPLATE_FILES|copyTemplateFile|resolveExtensionSource" src scripts test vscode templates
    # Freeze every source-of-truth touchpoint before editing.

    cd /home/deadpool/Documents/recodee/gitguardex/.omx/agent-worktrees/<fresh-implementation-worktree>
    node --test test/vscode-active-agents-session-state.test.js test/metadata.test.js
    # Focused extension/install/setup proof surface.

    cd /home/deadpool/Documents/recodee/gitguardex/.omx/agent-worktrees/<fresh-implementation-worktree>
    openspec validate agent-codex-vscode-active-agents-canonical-source-pl-2026-04-22-17-59 --type change --strict
    openspec validate --specs
    # Validate the change artifacts and repo specs.

    cd /home/deadpool/Documents/recodee/gitguardex/.omx/agent-worktrees/<fresh-implementation-worktree>
    gx branch finish --branch <implementation-branch> --base main --via-pr --wait-for-merge --cleanup
    # Finalize the implementation branch after focused verification.

## Validation and Acceptance

- The Active Agents authored files live in one canonical source tree.
- `gx setup` / `gx doctor` still materialize a working `vscode/guardex-active-agents/` folder in downstream repos, including `icon.png`.
- The local install helper still produces a valid installed payload with the existing commands, activation events, and runtime behavior.
- Focused tests prove the canonical source and downstream materialization stay aligned without depending on long-lived manual live/template duplication.

## Idempotence and Recovery

- Re-running setup/doctor after the migration should deterministically rewrite the managed companion from the same canonical source.
- If a full duplicate-tree removal is too risky in one cut, keep a generated/materialized mirror for one lane only, but do not leave both trees as manually edited peers.
- If binary asset copying destabilizes setup/doctor, pause and restore a minimal derived mirror rather than reintroducing silent manual drift.

## Artifacts and Notes

- Evidence pointers:
  - `scripts/install-vscode-active-agents-extension.js` resolves `vscode/guardex-active-agents/` before `templates/vscode/guardex-active-agents/`.
  - `src/context.js` still defines the managed template contract around text Active Agents files.
  - `src/scaffold/index.js` copies managed files with UTF-8 reads/writes.
  - `test/metadata.test.js` currently enforces live/template JS equality.
  - `test/vscode-active-agents-session-state.test.js` imports the live `vscode/` extension files and validates the installed payload from there.

## Interfaces and Dependencies

- `resolveExtensionSource(repoRoot)` in `scripts/install-vscode-active-agents-extension.js` must keep returning an installable extension directory.
- `TEMPLATE_FILES` / managed-file destinations in `src/context.js` define what setup/doctor expect to materialize.
- `copyTemplateFile()` and related scaffold helpers in `src/scaffold/index.js` currently assume UTF-8 text content and therefore need an asset-safe path for `icon.png`.
- `test/vscode-active-agents-session-state.test.js` and `test/metadata.test.js` are the minimal regression surface for this change.

## Revision Note

- 2026-04-22 16:06Z: Replaced the scaffold with an execution-ready continuation plan for canonicalizing the Active Agents authored source and downstream asset materialization.
