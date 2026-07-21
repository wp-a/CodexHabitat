# Apple-Inspired Visual and Interaction Reconstruction Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reconstruct the native Habitat application, pet interaction, and all twenty-four Codex themes around a cohesive, responsive, Apple-inspired design system while preserving all existing safety and privacy boundaries.

**Architecture:** Add a small native design-token and interaction layer above existing SwiftUI/AppKit surfaces, then rebuild the settings workflows around explicit view state and asynchronous previews. Keep the strongly typed theme protocol and compatibility profiles; strengthen the host-owned compiler so one stable Codex shell and nine complete style-family treatments control visuals without moving functional geometry or accepting package CSS/JavaScript.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Swift Testing, Foundation/ImageIO, typed static CSS compilation, offline Playwright fixtures, macOS screenshot QA, ad-hoc application and DMG packaging.

---

## Hard Safety Boundary

- Never run Theme Bridge `apply`, `start`, `watch`, `enable`, or `restore` in development or automated QA.
- Never quit, restart, or modify Codex or its app bundle, `app.asar`, configuration, preferences, signature, or launch state.
- Use only the offline Codex fixture for automated theme rendering.
- Keep custom imports data-only. Reject CSS, JavaScript, selectors, commands, URLs, executables, symbolic links, and undeclared content.
- Launch or restart only isolated Codex Habitat QA processes when native screenshots require it.
- Record real CDP visual acceptance as a remaining user-manual step.

## Working Rules

- Use @test-driven-development for every production change.
- Use @systematic-debugging for any unexpected failure or interaction stall.
- Complete each task as RED, GREEN, focused verification, and one atomic commit.
- Use @screenshot for native visual QA and inspect original pixels.
- Use @verification-before-completion before release claims.
- Do not regenerate the twenty-four background images; this plan improves their presentation and interface shell.

### Task 1: Establish native visual tokens and interaction primitives

**Files:**
- Create: `Sources/CodexHabitatApp/Design/HabitatDesignSystem.swift`
- Create: `Sources/CodexHabitatApp/Design/HabitatInteractionStyles.swift`
- Create: `Tests/CodexHabitatAppTests/HabitatDesignSystemTests.swift`
- Modify: `Sources/CodexHabitatApp/Settings/SettingsRootView.swift`

**Step 1: Write the failing token tests**

Add tests for stable spacing, radius, control-height, and motion contracts. The
testable model should expose numeric values without requiring view inspection:

```swift
@Test
func designMetricsRemainCompactAndDeliberate() {
    #expect(HabitatDesignMetrics.spacing == [4, 8, 12, 16, 20, 24, 32])
    #expect(HabitatDesignMetrics.cardRadius <= 8)
    #expect(HabitatDesignMetrics.standardControlHeight == 32)
    #expect(HabitatMotion.panelResponse >= 0.30)
    #expect(HabitatMotion.panelResponse <= 0.40)
}
```

Require reduced-motion resolution and derived accent contrast to be
deterministic.

**Step 2: Run RED**

```bash
swift test --filter HabitatDesignSystemTests
```

Expected: FAIL because the design-system types do not exist.

**Step 3: Implement the minimal design layer**

Add:

- `HabitatDesignMetrics` constants;
- `HabitatMotion` values and a reduced-motion resolver;
- `HabitatMaterialRole` and semantic surface helpers;
- reusable press, hover, selected, and focus styles that do not change layout;
- environment values for bounded theme accent and secondary colors.

Use system fonts and SF Symbols. Do not add a third-party UI or animation
dependency. Apply only the shared environment and page background in
`SettingsRootView`; screen reconstruction belongs to later tasks.

**Step 4: Run GREEN**

```bash
swift test --filter HabitatDesignSystemTests
swift test --filter CodexHabitatAppTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/CodexHabitatApp/Design Sources/CodexHabitatApp/Settings/SettingsRootView.swift Tests/CodexHabitatAppTests/HabitatDesignSystemTests.swift
git commit -m "feat: add native Habitat design system"
```

### Task 2: Rebuild the settings shell and useful Habitat overview

**Files:**
- Create: `Sources/CodexHabitatApp/Settings/HabitatOverviewState.swift`
- Create: `Tests/CodexHabitatAppTests/HabitatOverviewStateTests.swift`
- Modify: `Sources/CodexHabitatApp/Settings/SettingsRootView.swift`
- Modify: `Sources/CodexHabitatApp/Settings/HabitatSettingsView.swift`
- Modify: `Sources/CodexHabitatApp/App/HabitatSettingsWindowController.swift`
- Modify: `Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift`
- Modify: `Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings`

**Step 1: Write failing state and window tests**

Add pure tests that derive the three overview bands from existing model state:

```swift
@Test
func overviewSeparatesHabitatCodexAndAppearanceState() {
    let state = HabitatOverviewState.fixture()
    #expect(state.sections.map(\.kind) == [.habitat, .codex, .appearance])
    #expect(state.sections.allSatisfy { !$0.primaryValue.isEmpty })
}
```

Update the window contract to require a default content size around 1040 x 680,
bounded by the available display, while retaining the existing compact minimum.
Test that sidebar selection remains local and immediate.

**Step 2: Run RED**

```bash
swift test --filter HabitatOverviewStateTests
swift test --filter SettingsWindowControllerTests
```

Expected: FAIL for the missing overview and old default size.

**Step 3: Implement the shell and overview**

- use a stable macOS split view with a 184-208 point sidebar;
- give sidebar rows stable 32 point geometry and explicit hover/selected states;
- replace oversized detail headings with compact headers;
- implement three un-nested overview bands using current visibility, pet, lock,
  metrics, theme, bridge, and restore state;
- keep advanced settings below the overview;
- use direct labels in English and Simplified Chinese.

Do not add new Codex reads or bridge actions.

**Step 4: Run GREEN**

```bash
swift test --filter HabitatOverviewStateTests
swift test --filter SettingsWindowControllerTests
swift test --filter LocalizationTests
```

**Step 5: Commit**

```bash
git add Sources/CodexHabitatApp/Settings Sources/CodexHabitatApp/App/HabitatSettingsWindowController.swift Sources/CodexHabitatApp/Resources Tests/CodexHabitatAppTests
git commit -m "feat: rebuild Habitat settings overview"
```

### Task 3: Build the theme gallery, inspector, favorites, and recents

**Files:**
- Create: `Sources/CodexHabitatApp/Settings/ThemeLibraryState.swift`
- Create: `Tests/CodexHabitatAppTests/ThemeLibraryStateTests.swift`
- Modify: `Sources/HabitatCore/Settings/HabitatSettings.swift`
- Modify: `Tests/HabitatCoreTests/SettingsStoreTests.swift`
- Modify: `Sources/CodexHabitatApp/App/HabitatAppModel.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ThemeGalleryQuery.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ThemesSettingsView.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ThemeTreatmentPreview.swift`
- Modify: `Tests/CodexHabitatAppTests/ThemeGalleryFilterTests.swift`
- Modify: `Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings`

**Step 1: Write failing settings and gallery tests**

Require backward-compatible defaults and bounded metadata:

```swift
@Test
func oldSettingsDecodeWithEmptyThemeLibraryMetadata() throws {
    let settings = try decodeLegacySettingsFixture()
    #expect(settings.favoriteThemeIDs.isEmpty)
    #expect(settings.recentThemeIDs.isEmpty)
}

@Test
func selectingThemeUpdatesPreviewAndRecentsWithoutRequestingApply() {
    var state = ThemeLibraryState()
    state.select("quiet-garden")
    #expect(state.previewedThemeID == "quiet-garden")
    #expect(state.pendingApplyThemeID == nil)
}
```

Test stable favorite ordering, recent deduplication, maximum recent count, and
search/filter composition.

**Step 2: Run RED**

```bash
swift test --filter SettingsStoreTests
swift test --filter ThemeLibraryStateTests
swift test --filter ThemeGalleryFilterTests
```

Expected: FAIL for missing metadata and selection state.

**Step 3: Implement data and gallery behavior**

- add backward-compatible favorite and recent identifiers to local settings;
- bound recents to twelve valid identifiers and drop missing resources;
- make card click select and preview only;
- move apply to an explicit inspector action;
- add All, Favorites, Recent, category, and Custom filtering;
- place search/import/create/refresh in a compact toolbar;
- render a gallery plus selected-theme inspector with home/task preview modes;
- keep preview loading actor-backed and show stable placeholders on failure;
- clearly distinguish selected, active, unsupported, applying, failed, and
  restorable bridge states.

Do not invoke bridge enable in tests or visual QA.

**Step 4: Run GREEN**

```bash
swift test --filter SettingsStoreTests
swift test --filter ThemeLibraryStateTests
swift test --filter ThemeGalleryFilterTests
swift test --filter ThemePreviewStoreTests
swift test --filter LocalizationTests
```

**Step 5: Commit**

```bash
git add Sources/HabitatCore Sources/CodexHabitatApp Tests/HabitatCoreTests Tests/CodexHabitatAppTests
git commit -m "feat: add refined theme library workflow"
```

### Task 4: Reconstruct Theme Studio around a live canvas

**Files:**
- Modify: `Sources/CodexHabitatApp/Settings/ThemeStudioModel.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ThemeStudioView.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ThemeTreatmentPreview.swift`
- Modify: `Tests/CodexHabitatAppTests/ThemeStudioModelTests.swift`
- Create: `Tests/CodexHabitatAppTests/ThemeStudioHistoryTests.swift`
- Modify: `Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings`

**Step 1: Write failing history and focal-point tests**

```swift
@Test
func studioUndoRestoresPreviousTypedDraft() throws {
    let model = try makeStudioModel()
    let original = model.draft
    model.setHomeStrength(0.42)
    #expect(model.canUndo)
    model.undo()
    #expect(model.draft == original)
}

@Test
func focalPointDragClampsToUnitCoordinates() {
    #expect(ThemeFocalPointMapper.unitPoint(at: .init(x: -20, y: 900),
        in: .init(x: 0, y: 0, width: 400, height: 300)) == .init(x: 0, y: 1))
}
```

Require bounded history, redo invalidation after a new edit, and preservation of
the existing validation/package output.

**Step 2: Run RED**

```bash
swift test --filter ThemeStudioHistoryTests
swift test --filter ThemeStudioModelTests
```

Expected: FAIL for missing history and mapping.

**Step 3: Implement the wide editor**

- keep an immutable typed draft snapshot history capped at fifty entries;
- coalesce continuous slider and focal-point drag updates into one undo action;
- create a left home/task canvas with optional safe-area overlay;
- implement direct, clamped focal-point dragging;
- create a right inspector with Metadata, Artwork, Palette, Scene, Material,
  Pet Pairing, and Package groups;
- expose undo, redo, cancel, export, and save in stable toolbar/footer positions;
- preserve drafts after validation errors and point to the affected control.

No raw CSS or selector editor is introduced.

**Step 4: Run GREEN**

```bash
swift test --filter ThemeStudioHistoryTests
swift test --filter ThemeStudioModelTests
swift test --filter ThemeTreatmentPreviewTests
swift test --filter ResourceKitTests
```

**Step 5: Commit**

```bash
git add Sources/CodexHabitatApp/Settings Sources/CodexHabitatApp/Resources Tests/CodexHabitatAppTests
git commit -m "feat: add live Theme Studio canvas"
```

### Task 5: Refine pet browsing and unify overlay gestures

**Files:**
- Create: `Sources/OverlayHost/Interaction/PetPointerInteraction.swift`
- Create: `Tests/OverlayHostTests/PetPointerInteractionTests.swift`
- Modify: `Sources/OverlayHost/Window/OverlayController.swift`
- Modify: `Sources/CodexHabitatApp/Overlay/HabitatDesktopController.swift`
- Modify: `Sources/CodexHabitatApp/Overlay/HabitatOverlayView.swift`
- Modify: `Sources/CodexHabitatApp/Overlay/PetView.swift`
- Modify: `Sources/CodexHabitatApp/Settings/PetsSettingsView.swift`
- Modify: `Tests/CodexHabitatAppTests/HabitatDesktopControllerTests.swift`
- Modify: `Tests/CodexHabitatAppTests/PetThumbnailStoreTests.swift`

**Step 1: Write failing pointer-state tests**

Cover click, drag threshold, grab-offset preservation, cancel, and one-command
delivery:

```swift
@Test
func clickEmitsExactlyOneToggleWithoutCrossingDragThreshold() {
    var interaction = PetPointerInteraction(dragThreshold: 6)
    interaction.pointerDown(at: .init(x: 30, y: 20))
    #expect(interaction.pointerUp(at: .init(x: 33, y: 22)) == .toggle)
    #expect(interaction.pointerUp(at: .init(x: 33, y: 22)) == nil)
}
```

Retain tests for exact 136 x 144 collapsed and 324 x 144 expanded physical
sizes and shared right edge.

**Step 2: Run RED**

```bash
swift test --filter PetPointerInteractionTests
swift test --filter HabitatDesktopControllerTests
```

Expected: FAIL for the missing unified gesture state.

**Step 3: Implement one AppKit-owned pointer path**

- centralize primary pointer down/move/up handling in OverlayHost;
- remove the duplicate SwiftUI tap toggle;
- start visual press feedback immediately through published presentation state;
- begin drag only after the tested threshold and preserve grab offset;
- use one interruptible expansion animation and keep resizing right-anchored;
- keep sprite and thumbnail decoding off the main actor;
- rebuild the pet page as preview, resource list, and behavior inspector;
- retain the previous pet until a selected asset is decoded successfully;
- use a compact actionable empty state.

**Step 4: Run GREEN**

```bash
swift test --filter PetPointerInteractionTests
swift test --filter HabitatDesktopControllerTests
swift test --filter PetThumbnailStoreTests
swift test --filter OverlayHostTests
```

**Step 5: Commit**

```bash
git add Sources/OverlayHost Sources/CodexHabitatApp/Overlay Sources/CodexHabitatApp/Settings/PetsSettingsView.swift Tests/OverlayHostTests Tests/CodexHabitatAppTests
git commit -m "fix: make pet interaction direct and responsive"
```

### Task 6: Complete the shared Codex shell and nine family treatments

**Files:**
- Modify: `Sources/CodexHabitatThemeBridge/Resources/codex-theme-template.css`
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeVisualHierarchyTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeInteractionPolishTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`
- Modify: `Tests/VisualFixtures/CodexWindow/fixture-contract.mjs`
- Modify: `Tests/VisualFixtures/CodexWindow/fixture-contract.test.mjs`
- Modify: `Tests/VisualFixtures/CodexWindow/render.mjs`
- Modify: `Tests/VisualFixtures/CodexWindow/styles.css`

**Step 1: Write failing family-completeness tests**

For every family require explicit treatment for header, stage, home action,
sidebar action, content, composer, popover, selected, focus, and density. Require
at least six material differences between every pair of family signatures:

```swift
@Test
func eachStyleFamilyOwnsACompleteDistinctSurfaceSignature() throws {
    let signatures = try HabitatThemeStyleFamily.allCases.map(compileSignature)
    #expect(Set(signatures).count == HabitatThemeStyleFamily.allCases.count)
    #expect(signatures.allSatisfy(\.isComplete))
}
```

Add fixture assertions that one fixed scene reaches titlebar, sidebar, main, and
bottom edge; home/composer centers remain within one pixel of the host main
surface; interactive states change visually without changing rects; reduced
motion has no running animation.

**Step 2: Run RED**

```bash
swift test --filter ThemeVisualHierarchyTests
swift test --filter ThemeInteractionPolishTests
node --test Tests/VisualFixtures/CodexWindow/fixture-contract.test.mjs
```

Expected: FAIL because stage treatment is currently empty and family signatures
remain too similar.

**Step 3: Implement the shared shell**

- preserve the single fixed artwork canvas and host-owned geometry;
- guarantee full titlebar/sidebar/main/bottom coverage;
- give sidebar, titlebar, reading surface, composer, and popovers exactly one
  boundary/material owner;
- make home and task route materials distinct without separate artwork sources;
- implement the nine family responsibilities from the approved design;
- keep idle states quiet and press/focus/selected states stronger;
- restrict interaction transitions to bounded paint/compositor properties;
- preserve custom-theme typed fields and all compiler validation.

Do not introduce JavaScript, arbitrary CSS input, remote URLs, or layout-moving
theme declarations.

**Step 4: Run GREEN**

```bash
swift test --filter CodexHabitatThemeBridgeTests
node --test Tests/VisualFixtures/CodexWindow/fixture-contract.test.mjs
scripts/render-codex-theme-fixtures.sh --check
```

**Step 5: Render and inspect offline contact sheets**

```bash
rm -rf /tmp/habitat-build15-fixtures
scripts/render-codex-theme-fixtures.sh --write /tmp/habitat-build15-fixtures
```

Inspect all contact sheets and at least one home/task wide/compact full-size pair
for each of the nine families. Record any issue as a failing metric or test
before correction.

**Step 6: Commit**

```bash
git add Sources/CodexHabitatThemeBridge Tests/CodexHabitatThemeBridgeTests Tests/VisualFixtures/CodexWindow
git commit -m "feat: complete nine Codex theme families"
```

### Task 7: Complete accessibility, localization, and native screenshot QA

**Files:**
- Modify: `Tests/CodexHabitatAppTests/LocalizationTests.swift`
- Modify: `Tests/CodexHabitatAppTests/HabitatVisualQALaunchOptionsTests.swift`
- Modify: `Sources/CodexHabitatApp/Diagnostics/OverlayPreview.swift`
- Modify: `Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings`
- Create: `docs/qa/screenshots/2026-07-21-build15/README.md`
- Create: native PNG screenshots under `docs/qa/screenshots/2026-07-21-build15/`

**Step 1: Write failing accessibility and localization tests**

Require all new labels in both locales, deterministic visual-QA launch states,
and resolvers for Reduced Motion, Reduced Transparency, and Increased Contrast.

**Step 2: Run RED**

```bash
swift test --filter LocalizationTests
swift test --filter HabitatVisualQALaunchOptionsTests
swift test --filter HabitatDesignSystemTests
```

Expected: FAIL for missing strings and QA states.

**Step 3: Implement and verify native states**

Add deterministic launch options for overview, gallery selection/inspector,
Theme Studio, pet library, and expanded/collapsed overlay. Ensure long English
and Simplified Chinese text wraps or truncates intentionally. Apply accessible
labels and minimum hit areas to unfamiliar icon-only controls.

**Step 4: Run native screenshot QA**

Build an isolated ad-hoc Habitat app. Capture, inspect at original resolution,
and document:

- overview, theme library, Theme Studio, pet library;
- empty/loading/error states;
- light and dark appearance;
- Simplified Chinese and English;
- standard and bounded compact window sizes;
- reduced motion/transparency and increased contrast;
- pet collapsed and expanded physical bounds.

Check unified logs for SwiftUI publication, AttributeGraph, layout recursion,
and main-thread stall warnings. Do not open, inspect, restart, or alter Codex.

**Step 5: Run GREEN**

```bash
swift test --filter CodexHabitatAppTests
scripts/render-codex-theme-fixtures.sh --check
```

**Step 6: Commit**

```bash
git add Sources/CodexHabitatApp Tests/CodexHabitatAppTests docs/qa/screenshots/2026-07-21-build15
git commit -m "test: verify reconstructed native experience"
```

### Task 8: Build 15 release verification and read-only review

**Files:**
- Modify: `Config/Info.plist`
- Modify: `Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift`
- Modify: `README.md`
- Modify: `docs/qa/macos-v1-checklist.md`
- Modify: `docs/qa/phase3-readiness.md`
- Generated: `dist/Codex Habitat.app`
- Generated: `dist/Codex-Habitat-0.1.0.dmg`

**Step 1: Bump the tested build contract RED to GREEN**

Change the test expectation from Build 14 to Build 15 and verify RED:

```bash
swift test --filter packagedAppDeclaresExpectedVersionAndBuild
```

Update `CFBundleVersion` to `15`, then rerun the focused test for GREEN.

**Step 2: Run complete verification**

```bash
swift test
node --test Tests/VisualFixtures/CodexWindow/fixture-contract.test.mjs
scripts/render-codex-theme-fixtures.sh --check
scripts/build-app.sh --adhoc
scripts/verify-release.sh "dist/Codex Habitat.app"
scripts/package-dmg.sh
```

Mount the DMG read-only, run `verify-release.sh` against the mounted app, verify
Build 15, arm64, ad-hoc signatures, helper hash, all twenty-four themes, Sparkle
framework, and the `/Applications` link, then detach.

**Step 3: Update release evidence**

Record exact test counts, visual fixture counts, application/DMG verification,
DMG SHA-256, native screenshot paths, log review, and the remaining manual CDP
acceptance step. Update README screenshots and descriptions without adding the
previously removed research/disclaimer footer.

**Step 4: Perform read-only review**

Review the complete change range for:

- main-thread work and duplicate gesture delivery;
- compatibility or bridge safety regressions;
- package-schema expansion or unsafe input;
- accessibility and localization gaps;
- layout overlap, clipping, insufficient contrast, and family sameness;
- missing tests or stale release claims.

Address every material finding with a new failing test, minimal fix, focused
verification, and separate commit.

**Step 5: Commit release evidence**

```bash
git add Config/Info.plist Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift README.md docs/qa
git commit -m "docs: record Build 15 reconstruction evidence"
```

**Step 6: Final status**

Report verified artifacts and checks. State explicitly that no live Codex apply,
restart, quit, or modification occurred and that real CDP visual acceptance is
still a manual user step.
