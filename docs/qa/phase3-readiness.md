# Phase 3 Readiness

Last updated: 2026-07-27 on macOS 26.4, arm64, Xcode 26.6.

Build 15 is ready for user-owned local installation and manual live-CDP
acceptance. It is not yet a notarized public release.

## Verified

- `swift test --skip 'tempRender(SettingsSurfaces|CurrentUISurfaces)'`: 486
  committed tests in 6 suites passed with zero failures. The two skipped local
  snapshot-render helpers are untracked QA artifacts, not release tests.
- Offline Codex fixture: 144 checks passed across 24 themes, home/task routes,
  and wide/narrow/compact viewports; 24 interaction matrices covered hover,
  active, focus-visible, composer focus-within, and reduced motion with zero
  external requests.
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
- Ad-hoc `Codex Habitat 0.1.0` Build 15 passed `verify-release`, arm64 main/helper
  inspection, strict/deep signature checks, 24-resource verification, and DMG
  checksum validation. The DMG mounted with read-only media and volume flags,
  contained the `/Applications` symlink, and detached cleanly.
- DMG SHA-256:
  `d18fb78cf85019e5520b841ed8077cd230b9d09fbc2b24b8cedb0a56ee130863`.
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
was not quit, restarted, or modified, and no live theme bridge helper ran.
