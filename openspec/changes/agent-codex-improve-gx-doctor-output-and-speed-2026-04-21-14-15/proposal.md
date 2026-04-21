## Why

- `gx doctor` currently buffers nested child runs and then dumps a long wall of wrapped auto-finish output, which makes the command look frozen in large workspaces.
- Recursive doctor already forwards `--no-wait-for-merge` to child doctor runs, but the single-repo auto-finish sweep ignores that flag and can still block on merge waits.
- The default failure lines include full rebase commands and long worktree paths, which hide the actual branch state the user needs to act on.

## What Changes

- Stream recursive child doctor output live and annotate nested targets with lightweight progress and completion timing so long runs keep moving visibly.
- Thread the doctor `--no-wait-for-merge` flag into the auto-finish sweep so ready-branch cleanup does not stall recursive doctor runs.
- Compact auto-finish sweep detail lines by default while keeping `--verbose-auto-finish` as an opt-in escape hatch for the raw failure text.

## Impact

- Affects the maintainer/operator `gx doctor` UX, especially in repos with many nested git repos or many candidate agent branches.
- Keeps JSON output unchanged; only the human-readable doctor output and wait behavior change.
- Main risk: compacting failure text too aggressively could hide useful context, so verbose mode remains available and the default summary must keep the actionable reason.
