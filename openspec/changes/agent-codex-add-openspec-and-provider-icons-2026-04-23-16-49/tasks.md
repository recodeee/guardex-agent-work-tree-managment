## Definition of Done

This change is complete only when all of the following are true:

- Every checkbox below is checked.
- Focused Active Agents regression coverage passes.
- Cleanup records the final PR URL plus `MERGED` evidence, or a `BLOCKED:` line explains why finish could not complete.

Handoff: 2026-04-23 codex owns branch `agent/codex/add-openspec-and-provider-icons-2026-04-23-16-49`, the Active Agents live/template tree-item icon resolver, focused tests, and this OpenSpec change for semantic OpenSpec icons inside the Active Agents raw tree.

## 1. Specification

- [x] 1.1 Finalize proposal scope for semantic OpenSpec folder/file icons inside the Active Agents raw tree.
- [x] 1.2 Define normative requirements in `specs/vscode-active-agents-provider-icons/spec.md`.

## 2. Implementation

- [x] 2.1 Resolve bundled semantic icons from the shipped file-icon manifest for Active Agents folder/file tree items when no higher-priority status icon is set.
- [x] 2.2 Mirror the same tree-item icon resolver behavior into the template extension source.
- [x] 2.3 Add focused regression coverage for `changes`, `specs`, `proposal.md`, `tasks.md`, and `spec.md` nodes in the Active Agents raw tree.

## 3. Verification

- [x] 3.1 Run `node --test test/vscode-active-agents-session-state.test.js`. Result: passed `48/48`.
- [x] 3.2 Run `openspec validate agent-codex-add-openspec-and-provider-icons-2026-04-23-16-49 --type change --strict`. Result: passed.
- [x] 3.3 Run `openspec validate --specs`. Result: exited `0` with `No items found to validate.`

## 4. Cleanup (mandatory; run before claiming completion)

- [ ] 4.1 Run `gx branch finish --branch "agent/codex/add-openspec-and-provider-icons-2026-04-23-16-49" --base main --via-pr --wait-for-merge --cleanup`.
- [ ] 4.2 Record the PR URL and final `MERGED` state in the completion handoff.
- [ ] 4.3 Confirm the sandbox worktree and branch refs are gone after cleanup.

BLOCKED: none.
