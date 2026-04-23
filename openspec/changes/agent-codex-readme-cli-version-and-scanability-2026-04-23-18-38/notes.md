# T1 Notes

- Handoff: branch=`agent/codex/readme-cli-version-and-scanability-2026-04-23-18-38`; scope=`README hero title/badges, focused metadata regression`; action=`make the README top scan like the screenshot reference by leading with GitGuardex and the live CLI version while keeping the layout GitHub-native`.
- Rework the hero into two balanced `for-the-badge` rows so CLI version, downloads, CI, license, stars, scorecard, Node floor, and support CTA scan in one glance.
- Promote the product name to the top-level heading and keep the existing install/about copy below it.
- Keep verification focused on `test/metadata.test.js` so README drift gets caught without reopening broader suites.
- Result: README hero now leads with `GitGuardex`, uses two scan-friendly badge rows, and passed `node --test test/metadata.test.js` (`24/24`); `openspec validate --specs` returned `No items found to validate.` for this notes-only lane.
