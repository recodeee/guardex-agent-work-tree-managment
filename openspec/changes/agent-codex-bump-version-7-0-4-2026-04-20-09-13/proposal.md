## Why

- `npm publish` failed because `@imdeadpool/guardex@7.0.3` is already published.
- The repo versioning rule requires release notes to be updated in README whenever publish/version metadata changes.

## What Changes

- Bump package version from `7.0.3` to `7.0.4` in package metadata.
- Add a `v7.0.4` release-note entry to README describing the publish-collision fix and release-note sync.

## Impact

- Affects npm release metadata and release-note documentation only.
- Low risk: no runtime behavior changes.
