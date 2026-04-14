---
name: guardex
description: "Use when you need to check, repair, or bootstrap multi-agent safety guardrails in this repository."
---

# GuardeX (Codex skill)

Use this skill whenever branch safety, lock ownership, or guardrail setup may be broken.

## Fast path

1. Run `gx status`.
2. If repo safety is degraded, run `gx doctor`.
3. If issues remain, run `gx scan` and address the findings.

## Setup path

If guardrails are missing entirely, run:

```sh
gx setup
```

Then verify:

```sh
gx status
gx scan
```

## Operator notes

- Prefer `gx doctor` for one-step repair + verification.
- Keep agent work isolated (`agent/*` branches + lock claims).
- For one-command Codex sandbox startup, use `bash scripts/codex-agent.sh "<task>" "<agent-name>"`.
- Do not bypass protected branch safeguards unless explicitly required.

## Bulk merge runbook (changed agent branches)

Use this when a repo has many `agent/*` branches/worktrees with pending changes and you need them merged into the base branch quickly.

1. Confirm base and guardrails are healthy:

```sh
git status --short --branch
git pull --ff-only origin "$(git config --get multiagent.baseBranch || echo dev)"
gx scan
```

2. Run bulk finish first:

```sh
gx finish --all
```

3. If a branch fails with `already used by worktree` or stale rebase hints, clear stale state in that worktree, then retry targeted finish:

```sh
git -C "<worktree>" rebase --abort || true
gx finish --branch "<agent-branch>" --base "$(git config --get multiagent.baseBranch || echo dev)" --no-wait-for-merge --cleanup
```

4. If `gh pr merge` exits non-zero due local branch deletion but PR is already merged, verify with:

```sh
gh pr view "<pr-number>" --json state,mergedAt,url
```

5. If a branch is still ahead of base with no open PR, create and merge a follow-up PR manually:

```sh
gh pr create --base "<base-branch>" --head "<agent-branch>" --title "Auto-finish: <agent-branch>" --body "Follow-up merge for pending branch commits."
gh pr merge "<pr-number>" --squash --delete-branch
```

6. Final verification:

```sh
gh pr list --state open --search "head:agent/ base:<base-branch>"
git pull --ff-only origin "<base-branch>"
gx cleanup
gx scan
```
