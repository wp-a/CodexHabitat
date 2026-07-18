# macOS v1 QA Checklist

Last updated: 2026-07-18 on macOS 26.4, arm64, Xcode 26.6.

Legend: `[x]` verified, `[ ]` still requires release hardware, credentials, or
explicit user action.

## Automated and packaged

- [x] Full Swift test suite passes: 275 tests including versioned CDP profiles, fail-closed target validation, pre-injection main-renderer health filtering, theme protocol, image bounds, thumbnail cache invalidation, theme-navigation resource isolation, pet-renderer reuse, localization, lifecycle, and performance budgets.
- [x] Production Swift build completes without warnings.
- [x] Ad-hoc `.app` passes strict/deep signature and hardened-runtime checks.
- [x] Sparkle 2.9.4 framework, XPC services, updater, and autoupdate signatures validate.
- [x] Main app contains no CDP flags; helper contains loopback-only CDP flags.
- [x] Finder-safe Codex CLI discovery covers explicit, official app, standalone, and PATH locations.
- [x] App and helper contain no developer home path or development rpath.
- [x] Standard `Contents/Resources` load works without `.build` fallback.
- [x] Packaged `en` and `zh-Hans` localization catalogs are declared and copied into the main app resources.
- [x] DMG mounts read-only, contains the app and `/Applications` link, and runs the packaged version command.
- [x] Final build 6 `Codex-Habitat-0.1.0.dmg` mounts read-only and passes mounted-bundle `verify-release` plus strict/deep signature checks; SHA-256 is `f9b39db281157a71636eadda0690f05bb1995b2f100059dd5f4a1f4b647d56a8`.
- [x] Ad-hoc builds disable network updates and use a local-only library-validation exception.
- [ ] Developer ID build, Apple notarization, stapling, and Gatekeeper acceptance with production credentials.

## UI and accessibility

- [x] Onboarding completes in exactly three steps without an account.
- [x] Settings minimum window is 760 x 520 and all pages scroll without overlap.
- [x] Build 6 is a standard visible macOS app with no `LSUIElement`; a normal cold launch from `/Applications/Codex Habitat.app` opens Settings with `background only = false` while login-item presentation remains covered by Apple-event policy tests.
- [x] Integrations apply confirmation shows restart, debugging-port, and unsaved-text risk.
- [x] Privacy diagnostics upper and lower regions fit without clipping.
- [x] All 24 bundled theme packages have unique IDs and hashes, validated 1600 x 1000 backgrounds, 800 x 500 previews, and nine materially distinct host-owned style families.
- [x] All, Nostalgia, Anime, and Custom gallery filters plus Theme Studio at narrow and wide settings widths pass native screenshot review without blank previews, clipping, or overlap.
- [x] Installed Pets and Themes pages pass native screenshot review with decoded thumbnails/previews, stable card geometry, and no blank or overlapping content.
- [x] Theme Studio accepts only local single-frame PNG/JPEG/WebP input and typed controls; it re-encodes bounded art and installs/exports through the validated package path with a user-content rights notice.
- [x] Overlay does not activate the app and can be made click-through.
- [x] Menu-bar connection state and Pomodoro/countdown controls render without clipping and share live timer state with the overlay.
- [x] Simplified Chinese settings and the default status/latest-request Token/context/recent-60-second-output/quota overlay pass native screenshot review without overlap.
- [x] At 100% scale the physical overlay is 136 x 144 collapsed and 324 x 144 expanded; the right edge remains fixed and the collapsed window has no transparent mouse-blocking rail.
- [x] Resource packs support validated import, explicit replacement, export, and uninstall from native settings.
- [x] Whole-pet live dragging moved the packaged overlay from `+1138,+481` to `+948,+319`; position lock and per-display relative placement persist through settings schema v4.
- [x] Launch-at-login uses `SMAppService.mainApp`; registration, rollback, and stored-state reconciliation are covered by tests.
- [x] Reduce Motion removes the pet refresh timer.
- [x] Hiding Habitat pauses local session polling and the pet refresh timer; showing it resumes both.
- [ ] Toggle the packaged login item on a disposable account and verify the post-login launch.
- [ ] Increased Contrast and large text review on a dedicated accessibility test account.

## Performance budgets

- [x] 10,000 animation frame calculations use one clock read per calculation plus initialization.
- [x] A 100-package library scan is deterministic and returns every fixture.
- [x] A 100-update snapshot burst coalesces to the newest buffered value.
- [x] Pet refresh is capped at 8 Hz active; resting, offline, and Reduce Motion are static.
- [x] Sprite frames are cropped once and reused by subsequent redraws.
- [x] Pet sprites decode only the requested thumbnail frame off the main thread and cache both successful and missing results.
- [x] Theme previews downsample to at most 480 px off the main thread, cache successful and missing results, and invalidate when local file size or modification time changes.
- [x] Build 6 native Settings runs measured Integrations -> Themes at 0.145-0.156 s after removing the appearance-time full resource refresh; theme-card clicks measured 0.168-0.225 s, and a concurrent sample contained zero pet asset resolution or sprite-frame precropping stacks.
- [x] Packaged idle CPU averaged 0.191% over 150 two-second `top` samples; 144/150 were below 1%.
- [x] Ad-hoc release physical footprint was 23 MB after sampling, with a 39.6 MB observed peak.
- [x] Post-enhancement static regression averaged 0.037% CPU over 30 one-second samples; all samples were below 1% and final memory was 21 MB.
- [x] Post-enhancement active pet, Token polling, overlay, and settings averaged 0.820% CPU over 20 one-second samples; final sampled memory was 53 MB.
- [x] Final expanded overlay averaged 0.58% CPU over five post-warmup samples and approximately 54 MB; collapsed averaged 0.42% CPU and approximately 53 MB under the same fixture.
- [ ] Memory, wakeups, and energy-impact baseline from the notarized build.

## Privacy and recovery

- [x] Diagnostic events accept fixed enums, numeric versions, and timestamps only.
- [x] Export removes unknown path, user, thread, and token fields and writes mode 0600.
- [x] Diagnostics rotate after seven days and can be cleared independently of settings/resources.
- [x] Petdex is opt-in; HTTPS host, redirects, size, license, hash, and content ID are checked.
- [x] Invalid packages, symlinks, active content, and archive traversal fail before publication.
- [x] Official Codex bundle verification is read-only and passes for `26.715.31925` arm64; its narrow profile selectors, official `initialRoute` main-page query, and auxiliary pet renderer were confirmed from a read-only `app.asar` extraction before enabling automated main-renderer health-gate coverage.
- [x] Session fallback reads file metadata only and exposes an explicit `Local activity estimate` state.
- [x] Installed Codex `26.707.91948` contains the `codex-theme-v1` Import/Copy shape; Habitat's clipboard encoder matches its required local schema.
- [x] API-key mode exposes real local latest-request Token/context/recent-output values and labels unavailable account quota as `API Key` rather than a fabricated percentage.
- [x] Salted active-thread selection keeps Token metrics on the matching session during parallel tasks, expires recent output after 60 seconds, and expires the complete metric summary after five minutes without a matching event.
- [ ] Paste a Habitat-generated native theme into Codex Appearance and visually confirm both light and dark variants with user approval.
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

The live CDP item must be initiated from the packaged Habitat UI. Running the
helper from inside this Codex task is not a valid test because closing Codex
also terminates its own task shell before injection can finish. The attempted
in-app-host run failed closed: session status remained inactive and no CDP
listener or helper process remained.
