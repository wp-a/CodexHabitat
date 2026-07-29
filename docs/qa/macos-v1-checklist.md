# macOS v1 QA Checklist

Last updated: 2026-07-29 on macOS 26.4, arm64, Xcode 26.6.

Legend: `[x]` verified, `[ ]` still requires release hardware, credentials, or
explicit user action.

## Automated and packaged

- [x] Full committed Swift test suite passes: 543 tests in 6 suites, including versioned CDP profiles, fail-closed target validation, bounded route-aware theme updates and complete bootstrap cleanup, pre-injection main-renderer health filtering, theme protocol, strict single-frame image-container validation, bounded thumbnail-cache eviction and invalidation, theme-navigation resource isolation, serialized off-main pet renderer construction, future-settings-schema read-only behavior, complete explicit localization-key coverage, gated visual-QA launch controls, lifecycle, performance budgets, protected-product display-name checks, Home action viewport insets, computed Task reading scrims, independently readable request cards, and monotonic release-build verification.
- [x] Production Swift build completes without warnings.
- [x] Ad-hoc `.app` passes strict/deep signature and hardened-runtime checks.
- [x] Sparkle 2.9.4 framework, XPC services, updater, and autoupdate signatures validate.
- [x] Main app contains no CDP flags; helper contains loopback-only CDP flags.
- [x] Finder-safe Codex CLI discovery covers explicit, official app, standalone, and PATH locations.
- [x] App and helper contain no developer home path or development rpath.
- [x] Standard `Contents/Resources` load works without `.build` fallback.
- [x] Packaged `en` and `zh-Hans` localization catalogs are declared and copied into the main app resources.
- [x] DMG mounts read-only, contains the app and `/Applications` link, and runs the packaged version command.
- [x] Final Build 16 `Codex-Habitat-0.1.0.dmg` mounts with both media and volume read-only flags, contains the app and `/Applications` link, reports `Codex Habitat 0.1.0` build 16, and passes mounted-bundle `verify-release` plus strict/deep signature checks; SHA-256 is `daf9dcc68fea8ecaa16cc9f8538bf0122399151728760229bdb59fd619f48ad5`.
- [x] Ad-hoc builds disable network updates and use a local-only library-validation exception.
- [ ] Developer ID build, Apple notarization, stapling, and Gatekeeper acceptance with production credentials.

## UI and accessibility

- [x] Onboarding completes in exactly three steps without an account.
- [x] Settings minimum window is 760 x 520 and all pages scroll without overlap.
- [x] Build 15 is a standard visible macOS app with no `LSUIElement`; its isolated packaged launch passed native QA without installing or replacing another Habitat build. Login-item presentation remains covered by Apple-event policy tests.
- [x] Integrations apply confirmation shows restart, debugging-port, and unsaved-text risk.
- [x] Privacy diagnostics upper and lower regions fit without clipping.
- [x] All 24 bundled theme packages have unique IDs and hashes, 800 x 500 previews, and nine materially distinct host-owned style families. Cathedral Foundry, Retro Messenger 2007, Arcade Signal, and Quiet Garden use validated 2560 x 1440 prototype backgrounds; the other twenty retain validated 1600 x 1000 backgrounds.
- [x] The exact supported Codex profile renders all 24 themes across home/task and wide/narrow/compact states in 144 offline full-window scenes. The production resolver, compiler, and installer were used with zero external requests; every scene passed route mutation, semantic foreground, computed reading-material, request-card, interaction-state, reduced-motion, control-bound, hit-target, popover, overflow, artwork-decode, visible-art, and centering checks. Minimum measured body contrast is 4.502:1 and minimum control contrast is 3.207:1. This is offline evidence and not live Codex acceptance.
- [x] All, Nostalgia, Anime, and Custom gallery filters plus Theme Studio at narrow and wide settings widths pass native screenshot review without blank previews, clipping, or overlap.
- [x] Installed Pets and Themes pages pass native screenshot review with decoded thumbnails/previews, stable card geometry, and no blank or overlapping content.
- [x] Theme Studio accepts only local single-frame PNG/JPEG/WebP input (including uppercase extensions) and typed controls, including home/task treatment, safe side, chrome material, independent route strength, and sidebar/header/composer opacity; installed custom themes reopen as complete typed drafts, optional pet pairings persist, and slug collisions require explicit replacement confirmation.
- [x] Build 15 Simplified Chinese dark-mode All gallery, Pets empty state, Theme Studio, collapsed overlay, and English light-mode overview pass isolated original-resolution screenshot review; evidence is in `docs/qa/screenshots/2026-07-27-build15/`. Build 14 evidence remains in `docs/qa/screenshots/2026-07-21/`, and the earlier Build 8 filtered-gallery and advanced-control evidence remains in `docs/qa/screenshots/2026-07-18/`.
- [x] The installed Build 8 Classic filter displays the generic localized name `经典桌面工作台` without clipping while preserving the stable compatibility ID `win95-workbench`.
- [x] Overlay does not activate the app and can be made click-through.
- [x] Menu-bar connection state and Pomodoro/countdown controls render without clipping and share live timer state with the overlay.
- [x] Simplified Chinese settings and the default status/latest-request Token/context/recent-60-second-output/quota overlay pass native screenshot review without overlap.
- [x] At 100% scale the physical overlay is 136 x 144 collapsed and 324 x 144 expanded; 75% and 150% expanded bounds are 243 x 108 and 486 x 216. The Build 8 batch ended at its screen edge x=1512, while the Build 14 batch ended at its screen edge x=1488. Collapsed and expanded windows shared the right edge in both batches, and the collapsed window has no transparent mouse-blocking rail.
- [x] Resource packs support validated import, explicit replacement, export, and uninstall from native settings.
- [x] Whole-pet live dragging moved the packaged overlay from `+1138,+481` to `+948,+319`; position lock, per-display relative placement, and theme-pet pairings persist through settings schema v5.
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
- [x] Selecting a different pet builds and precrops its immutable renderer off the main actor through one serial worker, keeps the current pet visible until publication, prevents overlapping decodes during rapid switching, and discards cancelled stale results.
- [x] Theme previews downsample to at most 480 px off the main thread, cache successful and missing results within a 96 MiB / 128-entry LRU budget, and invalidate when local file size or modification time changes.
- [x] Build 6 native Settings runs measured Integrations -> Themes at 0.145-0.156 s after removing the appearance-time full resource refresh; theme-card clicks measured 0.168-0.225 s, and a concurrent sample contained zero pet asset resolution or sprite-frame precropping stacks.
- [x] Build 7 prototype gallery and narrow Theme Studio QA emitted zero “Publishing changes from within view updates”, AttributeGraph-cycle, or layout-recursion warnings.
- [x] Build 8 isolated native QA measured Themes -> Pets at 305.6 ms and Pets -> Themes at 306.1 ms including accessibility automation overhead; repeated navigation showed no multi-second stall. The final complete 96-scene offline route check measured a 0.20 ms maximum internal route mutation.
- [x] Build 8 native gallery, Studio, Pets, and 75%/100%/150% overlay QA emitted zero “Publishing changes from within view updates”, AttributeGraph-cycle, or layout-recursion warnings.
- [x] Build 15 isolated native gallery, Studio, Pets, overlay, and light/dark appearance QA emitted zero “Publishing changes from within view updates”, AttributeGraph-cycle, layout-recursion, or main-thread warnings in the filtered unified log.
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
- [x] Invalid packages, symlinks, active content, and archive traversal fail before publication. Pet imports additionally bound manifest and image bytes, text/path lengths, single-frame PNG/JPEG/WebP containers, 8192-pixel dimensions, and 32-million-pixel canvases before renderer construction.
- [x] Official Codex bundle verification is read-only and passes for exact `26.715.31925` and `26.715.52143` arm64 profiles. The updated exact build reuses only the complete statically audited surface map; profile, compiler, coordinator, and health-gate tests pass while live CDP remains unclaimed.
- [x] Session fallback reads file metadata only and exposes an explicit `Local activity estimate` state.
- [x] Installed Codex `26.707.91948` contains the `codex-theme-v1` Import/Copy shape; Habitat's clipboard encoder matches its required local schema.
- [x] API-key mode exposes real local latest-request Token/context/recent-output values and labels unavailable account quota as `API Key` rather than a fabricated percentage.
- [x] Salted active-thread selection keeps Token metrics on the matching session during parallel tasks, expires recent output after 60 seconds, and expires the complete metric summary after five minutes without a matching event.
- [x] Build 15 isolated native QA used separate `CODEX_HOME` and `CODEX_HABITAT_HOME` roots with settings schema 6 and `themeBridgeEnabled=false`; no Codex or theme-helper process was started, restarted, inspected, or modified.
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
