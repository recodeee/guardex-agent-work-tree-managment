# executor tasks

## 1. Spec

- [ ] 1.1 Map the approved canonical-source requirements to concrete implementation work items.
- [ ] 1.2 Freeze the touched components/files before coding starts: managed-file resolution, scaffold/doctor copy path, extension source tree, docs, and focused tests.

## 2. Tests

- [ ] 2.1 Define test additions/updates required to lock canonical-source behavior, setup/doctor asset copying, and install payload truthfulness.
- [ ] 2.2 Validate the focused regression and smoke verification commands before coding.

## 3. Implementation

- [ ] 3.1 Move the authored extension source to one canonical tree and retire manual duplicate editing.
- [ ] 3.2 Update setup/doctor/materialization so downstream repos still receive a working companion, including `icon.png`.
- [ ] 3.3 Replace duplicate-tree parity plumbing with focused docs/tests and keep runtime behavior unchanged.

## 4. Checkpoints

- [ ] [E1] READY - Execution start checkpoint

### E1 Acceptance Criteria

- [ ] The execution lane starts on a fresh implementation branch from `main`, not on the planning branch.
- [ ] The touched-file list is frozen before code edits begin.
- [ ] Runtime/UI behavior remains out of scope unless the canonical-source migration proves a blocker.

### E1 Verification Evidence

- [ ] Executor notes record the frozen file list and branch choice.
- [ ] `phases.md` is advanced to the execution phase when the fresh implementation lane begins.
- [ ] The root handoff identifies the exact focused tests and finish command.

## 5. Collaboration

- [ ] 5.1 Owner recorded the fresh implementation lane before edits.
- [ ] 5.2 Record joined agents / handoffs, or mark `N/A` when solo.

## 6. Cleanup

- [ ] 6.1 Finish the implementation branch with `gx branch finish --branch <implementation-branch> --base main --via-pr --wait-for-merge --cleanup`.
- [ ] 6.2 Record PR URL + final `MERGED` state in the handoff.
- [ ] 6.3 Confirm sandbox cleanup (`git worktree list`, `git branch -a`) or append `BLOCKED:` and stop.
