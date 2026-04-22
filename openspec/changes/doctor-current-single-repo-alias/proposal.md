## Why

- `gx doctor` recurses into nested repos by default, so users need a short explicit way to keep a repair pass scoped to the target repo only.
- `--single-repo` already provides that behavior, but `--current` is currently rejected and the recursive hint text does not advertise it.
- The user explicitly wants `gx doctor --current` to leave nested repos under the target path untouched.

## What Changes

- Accept `--current` as a doctor-only alias for `--single-repo`.
- Update the recursive doctor hint to mention `--current`.
- Add regression coverage proving a nested repo under the target path stays broken when `gx doctor --current` is used.

## Impact

- Affected surface: `src/cli/main.js`, `test/doctor.test.js`.
- Expected outcome: `gx doctor --current` scopes repairs to the target repo without mutating nested repos.
- Risk: low, because the alias is wired only inside `parseDoctorArgs()` and reuses existing single-repo behavior.
