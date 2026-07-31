# Phase 3 Readiness

Last updated: 2026-08-01 on macOS 26.4, arm64, Xcode 26.6.

Build 17 is ready for user-owned local installation and manual live-CDP
acceptance. It is not yet a notarized public release.

## Verified

- `swift test --no-parallel --skip tempRender`: 549
  committed tests in 6 suites passed with zero failures. The two skipped local
  snapshot-render helpers are untracked QA artifacts, not release tests.
- Offline Codex fixture: 144 checks passed across 24 themes, home/task routes,
  and wide/narrow/compact viewports; 24 interaction matrices covered hover,
  active, focus-visible, composer focus-within, and reduced motion with zero
  external requests. Minimum text and control contrast were 6.0615:1 and
  4.5224:1, maximum task-reading artwork leak was 0.0718, and the complete
  visual evidence is archived in
  [`screenshots/2026-07-30-premium-codex-themes/`](screenshots/2026-07-30-premium-codex-themes/README.md).
- The payload-enabled pinned-browser suite passed 2 of 2 tests with no skip,
  including the explicit request-card, editorial-response, code, and tool
  surface opacity contract across the complete 144-scene matrix.
- All 24 packaged themes use original local bitmap backgrounds, recorded
  provenance, bounded manifests, and nine materially distinct host-owned style
  families. Theme packages cannot provide CSS, JavaScript, selectors, commands,
  or URLs.
- Package installation rejects mismatched PNG/JPEG/WebP signatures, multiframe
  images, oversized canvases, bad hashes, symlinks, executable content, path
  traversal, and undeclared files before publication.
- Token widgets expose latest-request input plus output as the primary value,
  `last_input / model_context` as context, recent output over 60 seconds, and
  task-cumulative totals only as secondary detail.
- The physical pet panel measured 136 x 144 collapsed and 324 x 144 expanded,
  retained the same right edge, and left no expanded transparent interaction
  window when collapsed.
- Ad-hoc `Codex Habitat 0.1.0` Build 17 passed `verify-release`, arm64 main/helper
  inspection, strict/deep signature checks, 24-resource verification, and DMG
  checksum validation. The DMG mounted with `Writable=false`,
  `WritableMedia=false`, and `WritableVolume=false`, contained the
  `/Applications` symlink, and detached cleanly.
- DMG SHA-256:
  `6d5ace41c1f366e0ba82fd8b0656bc2abc8210b730bcc1f80867167743fa01a5`.
- Build 15 native localization and layout evidence is archived in
  [`screenshots/2026-07-27-build15/`](screenshots/2026-07-27-build15/README.md).
- The exact `26.715.52143` compatibility profile passed read-only identity,
  profile, compiler, coordinator, and health-gate tests. Unknown gaps and later
  Codex versions fail closed before restart or injection.

## Not Yet Verified

- Developer ID signing, Apple notarization, stapling, Gatekeeper assessment,
  and the production Sparkle appcast require release credentials.
- Live CDP apply on Codex `26.715.52143`, visual inspection inside the real
  Codex window, official-appearance restore, helper crash recovery, and listener
  closure require explicit user initiation.
- Login-item behavior on a disposable account, increased contrast, large text,
  mixed-scale displays, sleep/wake, and display disconnect/reconnect remain
  manual hardware/accessibility checks.

The active installed Habitat was not replaced during this verification. Codex
was not quit, restarted, or modified, and no live Theme Bridge command or CDP
session ran. The helper executable was invoked only with `--version` while
verifying the packaged bundle.

## Build 17 Verification Commands

```sh
swift test --no-parallel --skip 'tempRender'
npm --prefix Tests/VisualFixtures/CodexWindow test
scripts/render-codex-theme-fixtures.sh --check
HABITAT_OFFLINE_FIXTURE_PAYLOAD=/tmp/codex-habitat-build17-browser.43Qxw8/payload.json npm --prefix Tests/VisualFixtures/CodexWindow run test:browser
HABITAT_SCRATCH_PATH=/tmp/codex-habitat-release-build17.U71VaE scripts/build-app.sh --adhoc
scripts/verify-release.sh "dist/Codex Habitat.app"
codesign --verify --deep --strict --verbose=2 "dist/Codex Habitat.app"
scripts/package-dmg.sh
hdiutil attach -readonly -nobrowse "dist/Codex-Habitat-0.1.0.dmg"
shasum -a 256 "dist/Codex-Habitat-0.1.0.dmg"
```

The first release-build attempt reused an incomplete stale SwiftPM copy of
`Sparkle.framework` in the fixed temporary scratch directory and failed at
`import Sparkle`. A fresh isolated scratch restored the complete pinned 2.9.4
binary artifact and the clean build passed; no dependency or application source
change was required. The mounted bundle was independently verified before the
volume was detached.
