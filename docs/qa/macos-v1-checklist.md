# macOS v1 QA Checklist

Last updated: 2026-07-17 on macOS 26.4, arm64, Xcode 26.6.

Legend: `[x]` verified, `[ ]` still requires release hardware, credentials, or
explicit user action.

## Automated and packaged

- [x] Full Swift test suite passes, including security and performance budgets.
- [x] Production Swift build completes without warnings.
- [x] Ad-hoc `.app` passes strict/deep signature and hardened-runtime checks.
- [x] Sparkle 2.9.4 framework, XPC services, updater, and autoupdate signatures validate.
- [x] Main app contains no CDP flags; helper contains loopback-only CDP flags.
- [x] Finder-safe Codex CLI discovery covers explicit, official app, standalone, and PATH locations.
- [x] App and helper contain no developer home path or development rpath.
- [x] Standard `Contents/Resources` load works without `.build` fallback.
- [x] DMG mounts read-only, contains the app and `/Applications` link, and runs the packaged version command.
- [x] Ad-hoc builds disable network updates and use a local-only library-validation exception.
- [ ] Developer ID build, Apple notarization, stapling, and Gatekeeper acceptance with production credentials.

## UI and accessibility

- [x] Onboarding completes in exactly three steps without an account.
- [x] Settings minimum window is 760 x 520 and all pages scroll without overlap.
- [x] Integrations apply confirmation shows restart, debugging-port, and unsaved-text risk.
- [x] Privacy diagnostics upper and lower regions fit without clipping.
- [x] Workbench, Night Shift, Arcade Signal, and Quiet Garden references contain no blank sprites or layout shifts.
- [x] Overlay does not activate the app and can be made click-through.
- [x] Reduce Motion removes the pet refresh timer.
- [ ] Increased Contrast and large text review on a dedicated accessibility test account.

## Performance budgets

- [x] 10,000 animation frame calculations use one clock read per calculation plus initialization.
- [x] A 100-package library scan is deterministic and returns every fixture.
- [x] A 100-update snapshot burst coalesces to the newest buffered value.
- [x] Pet refresh is capped at 8 Hz active; resting, offline, and Reduce Motion are static.
- [x] Sprite frames are cropped once and reused by subsequent redraws.
- [x] Packaged idle CPU averaged 0.191% over 150 two-second `top` samples; 144/150 were below 1%.
- [x] Ad-hoc release physical footprint was 23 MB after sampling, with a 39.6 MB observed peak.
- [ ] Memory, wakeups, and energy-impact baseline from the notarized build.

## Privacy and recovery

- [x] Diagnostic events accept fixed enums, numeric versions, and timestamps only.
- [x] Export removes unknown path, user, thread, and token fields and writes mode 0600.
- [x] Diagnostics rotate after seven days and can be cleared independently of settings/resources.
- [x] Petdex is opt-in; HTTPS host, redirects, size, license, hash, and content ID are checked.
- [x] Invalid packages, symlinks, active content, and archive traversal fail before publication.
- [x] Official Codex bundle verification is read-only and passes for `26.707.91948` arm64.
- [x] Session fallback reads file metadata only and exposes an explicit `Local activity estimate` state.
- [ ] Exact control-socket activity on Codex `26.707.91948`; this build does not publish the proxy socket.
- [ ] Live CDP apply, screenshot health review, helper crash, and official-appearance restore with fresh user confirmation.
- [ ] Confirm the CDP listener closes after the live restore.
- [ ] Delete the app and app-owned support directory on a disposable account; confirm Codex threads and `~/.codex/pets` remain unchanged.

## macOS behavior matrix

- [x] Single Retina display, normal desktop, native settings, and overlay launch.
- [x] Saved placement math covers visible frames, scaling changes, edge snapping, and display removal.
- [x] Spaces/full-screen collection behavior is set and covered by AppKit tests.
- [ ] Two physical displays with mixed scale factors.
- [ ] Manual Spaces/full-screen interaction with unrelated foreground apps.
- [ ] Sleep/wake while Codex is working and while disconnected.
- [ ] Physical display disconnect/reconnect while the overlay is visible.
- [ ] Codex update across a compatibility-profile boundary.

No unchecked item may be reported as passed in release notes. Public beta
acceptance additionally requires every credential-dependent and live CDP item.
