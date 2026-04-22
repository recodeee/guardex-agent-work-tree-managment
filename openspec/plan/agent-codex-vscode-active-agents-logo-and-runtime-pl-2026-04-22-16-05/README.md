# Plan Workspace: agent-codex-vscode-active-agents-logo-and-runtime-pl-2026-04-22-16-05

This folder stores durable planning artifacts before implementation changes.

## Role folders
- `planner/`
- `architect/`
- `critic/`
- `executor/`
- `writer/`
- `verifier/`

Each role folder contains OpenSpec-style artifacts:
- `.openspec.yaml`
- `proposal.md`
- `tasks.md` (Spec / Tests / Implementation / Checkpoints checklists)
- `specs/<role>/spec.md`
Planner also gets `plan.md`; executor also gets `checkpoints.md`.
Planner plans should follow `openspec/plan/PLANS.md`.
