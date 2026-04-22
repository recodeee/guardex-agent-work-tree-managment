# writer tasks

## 1. Spec

- [ ] 1.1 Validate the docs audience: operators running `gx setup` / `gx doctor` and maintainers editing the Active Agents companion.
- [ ] 1.2 Validate consistency between plan terminology, README guidance, and OpenSpec artifacts.

## 2. Tests

- [ ] 2.1 Define the documentation verification checklist for canonical-source behavior, setup/doctor guidance, and install expectations.
- [ ] 2.2 Validate command/help text examples against actual workflow behavior after the migration.

## 3. Implementation

- [ ] 3.1 Update README/OpenSpec guidance so the canonical extension source and downstream materialization path are explicit.
- [ ] 3.2 Add or refine operator expectations for setup, doctor repair, and local install after canonicalization.
- [ ] 3.3 Publish the final docs change summary with references.

## 4. Checkpoints

- [ ] [W1] READY - Docs update checkpoint

### W1 Acceptance Criteria

- [ ] Docs describe one authored source of truth instead of manual live/template parity.
- [ ] Setup/doctor/install examples reflect the actual file flow after canonicalization.
- [ ] Docs do not imply new runtime/UI behavior that this lane does not ship.

### W1 Verification Evidence

- [ ] The updated README/OpenSpec copy matches the implementation result.
- [ ] The docs surface references the same commands used in executor/verifier tasks.
- [ ] Writer notes capture any downstream operator caveats.

## 5. Collaboration

- [ ] 5.1 Owner recorded the docs lane before edits.
- [ ] 5.2 Record joined agents / handoffs, or mark `N/A` when solo.

## 6. Cleanup

- [ ] 6.1 Finish the implementation branch with `gx branch finish --branch <implementation-branch> --base main --via-pr --wait-for-merge --cleanup`.
- [ ] 6.2 Record PR URL + final `MERGED` state in the handoff.
- [ ] 6.3 Confirm sandbox cleanup (`git worktree list`, `git branch -a`) or append `BLOCKED:` and stop.
