# Build 16 Reliability and Visual Hierarchy Implementation Plan

**Goal:** Remove remaining UI stalls and ambiguity, then refine Habitat and all
twenty-four Codex themes around a shared, testable visual hierarchy.

**Architecture:** Keep `HabitatAppModel` as the local source of truth, move
external helper work behind bounded asynchronous coordinators, preserve AppKit
pointer ownership during panel animation, make image caches revision-aware and
concurrent, and place a shared family surface recipe in `HabitatCore` for both
the SwiftUI preview and static CSS compiler.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Swift Testing, Foundation/ImageIO,
typed static CSS, offline Playwright fixtures, macOS screenshot QA, ad-hoc
application packaging and DMG verification.

## Working and Safety Rules

- Use test-driven development for every production change: observe RED before
  implementation, then GREEN and focused verification.
- Use systematic debugging for every unexpected failure; do not stack guesses.
- Commit each task atomically and preserve user-owned untracked files.
- Never run Theme Bridge live apply/start/watch/enable/restore in development or
  automated QA. Never quit, restart, or modify Codex.
- Use only the offline fixture for Codex theme screenshots. Record real CDP
  acceptance as a remaining manual step.

### Task 1: Make launch and Bridge refresh non-blocking and bounded

**Files:**
- Modify `Sources/CodexHabitatApp/CodexHabitatApp.swift`
- Modify `Sources/CodexHabitatApp/Integrations/ThemeBridgeIntegrationModel.swift`
- Modify `Tests/CodexHabitatAppTests/ThemeBridgeIntegrationModelTests.swift`
- Modify `Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift`

**RED:** Add tests for helper timeout, refresh coalescing, stale-generation
rejection, and the launch contract that presents settings before Bridge status
completion. Run:

```bash
swift test --filter ThemeBridgeIntegrationModelTests
swift test --filter SettingsWindowControllerTests
```

**GREEN:** Add a bounded process runner and one in-flight refresh task. Present
the settings window after local load/bind, then refresh asynchronously. Resume
an already-authorized watcher only outside test/visual-QA modes and only after
the bounded refresh. Do not launch any Bridge command during tests.

**Verify and commit:** Re-run both suites and commit as
`fix: make Bridge refresh nonblocking`.

### Task 2: Preserve pet click and drag intent through panel animation

**Files:**
- Modify `Sources/OverlayHost/Window/OverlayController.swift`
- Modify `Sources/CodexHabitatApp/Desktop/HabitatDesktopController.swift`
- Modify `Sources/CodexHabitatApp/Desktop/PetSpriteView.swift`
- Modify `Tests/OverlayHostTests/OverlayControllerTests.swift`
- Modify `Tests/CodexHabitatAppTests/HabitatDesktopControllerTests.swift`
- Modify or create focused pet sprite driver tests in
  `Tests/CodexHabitatAppTests`

**RED:** Prove that animation-owned resize does not cancel pointer interaction,
external resize still does, drag cancels pending expansion frames, the right
edge stays fixed, and renderer/row/clock changes rebuild the sprite driver.

```bash
swift test --filter OverlayControllerTests
swift test --filter HabitatDesktopControllerTests
swift test --filter PetSprite
```

**GREEN:** Add an explicit pointer-preservation resize mode used only by internal
animation. Make drag start stop expansion and derive subsequent frames from
current state rather than a stale captured edge. Extend sprite-driver identity
to every playback-defining input.

**Verify and commit:** Re-run the three focused suites and commit as
`fix: keep pet interaction responsive during resize`.

### Task 3: Make preview caches revision-aware and concurrent

**Files:**
- Modify `Sources/CodexHabitatApp/Settings/PetsSettingsView.swift`
- Modify `Sources/CodexHabitatApp/Settings/ThemesSettingsView.swift`
- Modify `Tests/CodexHabitatAppTests/PetThumbnailStoreTests.swift`
- Modify `Tests/CodexHabitatAppTests/ThemePreviewStoreTests.swift`

**RED:** Add pure request-key tests showing that in-place file replacement,
pixel size, and atlas rows change task identity. Add concurrency tests proving
different theme URLs decode in parallel and identical requests deduplicate.

```bash
swift test --filter PetThumbnailStoreTests
swift test --filter ThemePreviewStoreTests
```

**GREEN:** Introduce stable revision request keys for every `.task(id:)`. Move
theme decoding outside the actor and retain one in-flight task per key. Keep the
last successful preview visible while replacement work is pending.

**Verify and commit:** Re-run both suites and commit as
`fix: refresh previews without blocking the gallery`.

### Task 4: Clarify native hierarchy and theme ownership

**Files:**
- Modify `Sources/CodexHabitatApp/Design/HabitatDesignSystem.swift`
- Modify `Sources/CodexHabitatApp/Settings/SettingsRootView.swift`
- Modify `Sources/CodexHabitatApp/Settings/HabitatSettingsView.swift`
- Modify `Sources/CodexHabitatApp/Settings/ThemesSettingsView.swift`
- Modify `Sources/CodexHabitatApp/App/HabitatAppModel.swift` if a dedicated local
  theme command is required
- Modify `Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings`
- Modify `Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings`
- Modify focused design, library, settings, and localization tests

**RED:** Require system-owned native tint, deterministic high-contrast command
foregrounds, accessible slider labels, adaptive two/three-column gallery
metrics, compact action layout, and a local theme command that cannot call the
Bridge.

```bash
swift test --filter HabitatDesignSystemTests
swift test --filter ThemeLibraryStateTests
swift test --filter SettingsWindowControllerTests
swift test --filter LocalizationTests
```

**GREEN:** Restrict selected-theme accent to theme content, use native system
tint for controls/focus, make the gallery consume available width beside a
bounded inspector, and add explicit `Use in Habitat` and `Apply to Codex`
commands. Card clicks remain preview-only. Make compact actions wrap without
clipping and add slider accessibility names and values.

**Verify and commit:** Re-run focused tests and commit as
`feat: clarify Habitat theme actions and hierarchy`.

### Task 5: Finish the Theme Studio first-use flow

**Files:**
- Modify `Sources/CodexHabitatApp/Settings/ThemeStudioModel.swift`
- Modify `Sources/CodexHabitatApp/Settings/ThemeStudioView.swift`
- Modify `Tests/CodexHabitatAppTests/ThemeStudioModelTests.swift`
- Modify `Tests/CodexHabitatAppTests/ThemeStudioHistoryTests.swift`
- Modify both localization tables and localization tests

**RED:** Require a pure `canPersistDraft` contract, validation before export
destination selection, a real empty-canvas import action, persistent labels,
and one unambiguous sheet-dismiss command.

```bash
swift test --filter ThemeStudioModelTests
swift test --filter ThemeStudioHistoryTests
swift test --filter LocalizationTests
```

**GREEN:** Turn the artwork canvas into the import command, use native labeled
controls, disable Save/Export until minimum input is valid, surface field-level
errors before opening a chooser, keep Undo/Redo in the toolbar, and remove the
duplicate top close command.

**Verify and commit:** Re-run focused tests and commit as
`feat: refine Theme Studio authoring flow`.

### Task 6: Share family recipes between preview and compiler

**Files:**
- Create `Sources/HabitatCore/Theme/HabitatThemeSurfaceRecipe.swift`
- Create `Tests/HabitatCoreTests/HabitatThemeSurfaceRecipeTests.swift`
- Modify `Sources/CodexHabitatApp/Settings/ThemeTreatmentPreview.swift`
- Modify `Tests/CodexHabitatAppTests/ThemeTreatmentPreviewTests.swift`
- Modify `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Modify compiler, visual hierarchy, interaction, and continuity tests

**RED:** Require nine unique shared recipe signatures and assert that preview
and compiled CSS express the same header, action, reading, composer, selected,
focus, density, and shadow contracts. Reject family differences that only move
host geometry. Require one bounded text shadow rather than a three-layer stack.

```bash
swift test --filter HabitatThemeSurfaceRecipeTests
swift test --filter ThemeTreatmentPreviewTests
swift test --filter ThemeCompilerTests
swift test --filter ThemeVisualHierarchyTests
swift test --filter ThemeInteractionPolishTests
```

**GREEN:** Implement the shared recipe in `HabitatCore`, remove preview-only
family geometry, and compile the same safe treatment values into static CSS.
Preserve Codex-owned sidebar, home, composer, and route geometry. Use route
scrims/materials for readability and one short text shadow.

**Verify and commit:** Re-run all focused suites and commit as
`feat: align theme preview and compiler families`.

### Task 7: Raise offline visual coverage and release metadata

**Files:**
- Modify offline fixture renderer and theme visual tests as required
- Modify resource manifests or palettes only when contrast tests prove it is
  necessary; do not regenerate artwork
- Modify build metadata, release documentation, and QA records
- Add Build 16 screenshots under `docs/qa/screenshots/2026-07-27-build16`

**RED:** Add task/composer, compact-home, family-crop, hover, selected, focus,
and focus-visible fixture assertions. Set minimum normal text contrast to 5:1
and controls to 4.5:1.

**GREEN:** Adjust compiler-owned scrims, materials, and bounded palette values
until all twenty-four themes pass without layout overflow or external requests.
Capture isolated Habitat screenshots with the screenshot workflow at compact
and wide sizes in English and Simplified Chinese. Bump Build 16 metadata and
record provenance unchanged for existing bitmaps.

```bash
./scripts/render-codex-theme-fixtures.sh --write /tmp/codex-habitat-build16-fixtures
swift test --filter OfflineThemeFixtureTests
swift test --filter ThemeVisualHierarchyTests
swift test --filter ThemeInteractionPolishTests
swift test --filter LocalizationTests
```

**Verify and commit:** Inspect original-pixel contact sheets and native
screenshots, then commit as `test: complete Build 16 visual QA`.

### Task 8: Complete release verification and read-only review

Preserve the two user-owned temporary snapshot test sources. Run the repository
test command in a way that excludes them if they are not part of the package's
stable suite, then perform:

```bash
swift test
./scripts/build-app.sh --configuration release --adhoc
./scripts/verify-release.sh
./scripts/build-dmg.sh
```

Mount the generated DMG read-only, confirm the app bundle, helper, resources,
localizations, signatures, and launch metadata, then unmount it. Review the
complete diff for safety, async ownership, race conditions, accessibility,
localization, package boundaries, and visual regressions. Fix any finding using
another RED/GREEN/commit loop.

The completion report must list exact verification results and explicitly leave
real CDP visual acceptance to the user. Do not trigger live apply, Codex restart,
or Codex exit.
