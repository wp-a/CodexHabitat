# Game Themes, Compact Overlay, and Token Metrics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship twelve high-saturation original game themes, a genuinely compact pet-only overlay, and Token widgets whose labels match Codex's raw telemetry semantics.

**Architecture:** Move built-in theme identity and rich palette metadata into `HabitatCore` so the native app and CDP helper share one allowlisted catalog. Keep visual assets in the packaged app, extend the host compiler to load bounded local JPEG/PNG/WebP art, and keep resource-pack color additions optional for schema compatibility. Make overlay panel size mutable in `OverlayHost`, with Habitat owning the expanded/collapsed geometry and right-edge anchor. Derive the primary Token value from `last_token_usage` while retaining cumulative task totals as secondary help text.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Core Graphics, JSON Schema, Swift Testing, local CDP CSS injection, imagegen bitmap assets, macOS screenshot QA.

---

### Task 1: Add a shared rich built-in theme catalog

**Files:**
- Create: `Sources/HabitatCore/Theme/BuiltInThemeCatalog.swift`
- Modify: `Sources/ResourceKit/Manifest/HabitatManifest.swift`
- Modify: `Sources/ResourceKit/Manifest/ManifestDecoder.swift`
- Modify: `Sources/ResourceKit/Validation/ManifestValidator.swift`
- Modify: `Schemas/habitat-pack-v1.schema.json`
- Modify: `Tests/ResourceKitTests/ManifestValidatorTests.swift`
- Modify: `Tests/ResourceKitTests/Fixtures/valid-pack/habitat.json`
- Create: `Tests/HabitatCoreTests/BuiltInThemeCatalogTests.swift`

**Step 1: Write the failing rich-token compatibility tests**

Add a test proving old five-color manifests still decode and derive optional fields, plus a test proving explicit rich fields decode and invalid values fail:

```swift
@Test
func optionalRichColorsRemainBackwardCompatible() throws {
    let legacy = try ManifestDecoder(runtimeVersion: "1.0.0").decode(validManifestData())
    #expect(legacy.colors.panel == nil)

    let rich = try ManifestDecoder(runtimeVersion: "1.0.0").decode(
        try mutatedValidManifest {
            var colors = $0["colors"] as! [String: Any]
            colors["panel"] = "#15102B"
            colors["panelAlt"] = "#241A44"
            colors["mutedText"] = "#B9A8D8"
            colors["secondary"] = "#FF2D95"
            colors["highlight"] = "#FFE14D"
            $0["colors"] = colors
        }
    )
    #expect(rich.colors.panel == "#15102B")
    #expect(rich.colors.secondary == "#FF2D95")
}
```

Add a catalog test expecting exactly these stable IDs:

```swift
#expect(BuiltInThemeCatalog.all.map(\.id) == [
    "workbench", "night-shift", "arcade-signal", "quiet-garden",
    "neon-drift", "solar-raid", "toxic-lab", "candy-combo",
    "crimson-mecha", "aurora-boss", "gold-rush", "aqua-pulse",
])
```

**Step 2: Run tests to verify RED**

Run:

```bash
swift test --filter 'optionalRichColorsRemainBackwardCompatible|builtInCatalogHasTwelveStableGameThemes'
```

Expected: compilation fails because the optional fields and `BuiltInThemeCatalog` do not exist.

**Step 3: Implement the shared catalog and optional manifest fields**

Define shared value types in `HabitatCore`:

```swift
public struct HabitatThemePalette: Codable, Equatable, Sendable {
    public let surface: String
    public let panel: String
    public let panelAlt: String
    public let text: String
    public let mutedText: String
    public let accent: String
    public let secondary: String
    public let highlight: String
    public let attention: String
    public let error: String
}

public struct BuiltInThemeDefinition: Equatable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let symbol: String
    public let palette: HabitatThemePalette
    public let artFocusX: Double
    public let artFocusY: Double
    public let safeSide: HabitatThemeSafeSide
}
```

Populate twelve palettes with distinct hue families, not twelve variations of cyan/purple. Add optional `panel`, `panelAlt`, `mutedText`, `secondary`, and `highlight` to `HabitatColorTokens`. Validate every present field with the existing `#RRGGBB` rule and add those keys to the strict shape validator and JSON schema.

**Step 4: Run focused and schema tests**

Run:

```bash
swift test --filter 'BuiltInThemeCatalogTests|ManifestValidatorTests'
```

Expected: all focused tests pass and unknown nested color fields remain rejected.

**Step 5: Commit**

```bash
git add Sources/HabitatCore Sources/ResourceKit Schemas Tests/HabitatCoreTests Tests/ResourceKitTests
git commit -m "feat: add rich built-in theme catalog"
```

### Task 2: Generate and package twelve original game-theme backgrounds

**Files:**
- Modify: `Sources/CodexHabitatApp/Resources/Themes/workbench/*`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/night-shift/*`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/arcade-signal/*`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/quiet-garden/*`
- Create: `Sources/CodexHabitatApp/Resources/Themes/{neon-drift,solar-raid,toxic-lab,candy-combo,crimson-mecha,aurora-boss,gold-rush,aqua-pulse}/`
- Create: `docs/qa/theme-asset-provenance.md`
- Modify: `Tests/CodexHabitatAppTests/BundledThemeModelTests.swift`
- Modify: `Tests/CodexHabitatAppTests/SettingsModelTests.swift`

**Step 1: Expand the bundled-theme tests before adding assets**

Require twelve unique theme descriptors, readable `1600 x 1000` or larger `background.jpg` files, readable `800 x 500` previews, rich palette diversity, and no duplicate SHA-256 hashes.

```swift
#expect(themes.count == 12)
#expect(Set(themes.map(\.id)).count == 12)
#expect(themes.allSatisfy { $0.previewURL != nil && $0.backgroundURL != nil })
#expect(Set(themes.map(\.secondaryHex)).count >= 8)
```

**Step 2: Run tests to verify RED**

Run:

```bash
swift test --filter 'bundledThemeDescriptorsExposeValidatedTokensAndPreviews|settingsChangesUseKnownThemesWidgetsAndSafeScaleBounds'
```

Expected: failures report four themes and missing background assets.

**Step 3: Use the `imagegen` skill to create original bitmap art**

Generate twelve landscape, text-free, character-free game-interface environments. Each image must have a calm safe side for native controls and a high-saturation focal region on the opposite side. Avoid recognizable franchises, logos, UI screenshots, gradient-only compositions, bokeh, and identifiable people.

Save the normalized deliverables as `background.jpg` (`1600 x 1000`, bounded quality) and `preview.png` (`800 x 500`). Record prompt, generation date, output path, dimensions, byte size, and SHA-256 in `docs/qa/theme-asset-provenance.md`.

**Step 4: Add manifests and licenses**

Create/update each `habitat.json` with the catalog palette, existing default widget definitions, and original asset names. Copy the project MIT license notice into every new built-in theme directory. Keep built-ins host-owned; do not add executable resource entries.

**Step 5: Connect app descriptors to the shared catalog**

Replace the four-entry array in `HabitatThemeDescriptor.builtIn` with a map over `BuiltInThemeCatalog.all`. Add `panelHex`, `panelAltHex`, `mutedTextHex`, `secondaryHex`, `highlightHex`, and `backgroundURL`. Installed packs derive missing rich colors deterministically from their five required colors.

**Step 6: Verify assets and focused tests**

Run:

```bash
swift test --filter 'BundledThemeModelTests|SettingsModelTests'
find Sources/CodexHabitatApp/Resources/Themes -name background.jpg -exec sh -c 'test $(stat -f %z "$1") -le 1048576' _ {} \;
```

Expected: twelve descriptors pass, all images are unique and under 1 MiB.

**Step 7: Commit**

```bash
git add Sources/CodexHabitatApp/Resources Sources/CodexHabitatApp/App/HabitatAppModel.swift Tests/CodexHabitatAppTests docs/qa/theme-asset-provenance.md
git commit -m "feat: add twelve original game themes"
```

### Task 3: Upgrade the bounded CDP theme compiler

**Files:**
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Resources/codex-theme-template.css`
- Modify: `Sources/CodexHabitatApp/Integrations/ThemeBridgeIntegrationModel.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`
- Modify: `Tests/CodexHabitatAppTests/ThemeBridgeIntegrationModelTests.swift`

**Step 1: Write failing compiler tests**

Require all twelve IDs, all rich tokens, safe-side/focal-position CSS, route scrims, and bounded JPEG data art. Keep remote URLs, SVG, selectors, CSS, script, and unknown commands rejected.

```swift
for definition in BuiltInThemeCatalog.all {
    let theme = try #require(BridgeTheme.builtIn(id: definition.id))
    #expect(theme.tokens.secondary == definition.palette.secondary)
    #expect(theme.artDataURL?.hasPrefix("data:image/jpeg;base64,") == true)
}
```

**Step 2: Run tests to verify RED**

Run:

```bash
swift test --filter 'ThemeCompilerTests|ThemeBridgeIntegrationModelTests'
```

Expected: compilation fails on missing rich fields and the bridge rejects the eight new IDs.

**Step 3: Implement shared allowlisting and richer CSS**

Build `BridgeThemeTokens` from `HabitatThemePalette`. Replace the hard-coded four-ID switches in both the bridge and integration model with `BuiltInThemeCatalog`. Extend local art validation to exact PNG, JPEG, and WebP signatures, decoded size at most 1 MiB, and only package-relative built-in resources.

Update the template to use explicit panel layers, secondary/highlight tokens, safe-side scrims, home/conversation route treatments, visible art without `soft-light`, and native-control selectors from the compatibility profile only.

**Step 4: Run security and compiler tests**

Run:

```bash
swift test --filter 'ThemeCompilerTests|ThemeBridgeCoordinatorTests|CDPClientTests|ThemeBridgeIntegrationModelTests'
```

Expected: all theme and bridge security tests pass.

**Step 5: Commit**

```bash
git add Sources/CodexHabitatThemeBridge Sources/CodexHabitatApp/Integrations Tests/CodexHabitatThemeBridgeTests Tests/CodexHabitatAppTests/ThemeBridgeIntegrationModelTests.swift
git commit -m "feat: render rich game themes in Codex"
```

### Task 4: Make the Habitat theme gallery visibly themed

**Files:**
- Modify: `Sources/CodexHabitatApp/Settings/SettingsRootView.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ThemesSettingsView.swift`
- Modify: `Sources/CodexHabitatApp/Overlay/WidgetRailView.swift`
- Modify: `Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Tests/CodexHabitatAppTests/LocalizationTests.swift`
- Modify: `Tests/CodexHabitatAppTests/BundledThemeModelTests.swift`

**Step 1: Write failing presentation/localization tests**

Add coverage for twelve localized names/details, five-swatch palettes, and deterministic selected-theme tint values. Keep theme names short enough for the existing card width.

**Step 2: Run tests to verify RED**

Run:

```bash
swift test --filter 'LocalizationTests|BundledThemeModelTests'
```

Expected: missing new localization keys and palette properties fail.

**Step 3: Implement the themed gallery and rail**

Increase preview height enough to show the art composition while keeping at least two cards visible vertically. Use actual previews, five small color swatches, selected accent/tint, and a restrained selected-state outline. Apply the selected accent with `.tint` to settings and a low-opacity color wash behind native settings pages. Use `panelHex` and `panelAltHex` in the widget rail rather than mixing every panel from one surface color.

Do not turn settings sections into nested cards or add decorative instructions.

**Step 4: Run focused tests**

Run:

```bash
swift test --filter 'LocalizationTests|BundledThemeModelTests|HabitatOverlayLayoutTests'
```

Expected: all pass.

**Step 5: Commit**

```bash
git add Sources/CodexHabitatApp/Settings Sources/CodexHabitatApp/Overlay/WidgetRailView.swift Sources/CodexHabitatApp/Resources Tests/CodexHabitatAppTests
git commit -m "feat: theme the Habitat gallery and widgets"
```

### Task 5: Resize the overlay to its visible content

**Files:**
- Modify: `Sources/OverlayHost/Window/OverlayController.swift`
- Modify: `Sources/CodexHabitatApp/Overlay/HabitatOverlayLayout.swift`
- Modify: `Sources/CodexHabitatApp/Overlay/HabitatDesktopController.swift`
- Modify: `Sources/CodexHabitatApp/Diagnostics/OverlayPreview.swift`
- Modify: `Tests/OverlayHostTests/HabitatPanelTests.swift`
- Modify: `Tests/CodexHabitatAppTests/HabitatOverlayLayoutTests.swift`
- Modify: `Tests/CodexHabitatAppTests/HabitatDesktopControllerTests.swift`

**Step 1: Write failing geometry and controller tests**

Require exact logical geometry:

```swift
let collapsed = HabitatOverlayLayout(isWidgetRailExpanded: false)
let expanded = HabitatOverlayLayout(isWidgetRailExpanded: true)
#expect(collapsed.containerSize == CGSize(width: 136, height: 144))
#expect(expanded.containerSize == CGSize(width: 324, height: 144))
#expect(collapsed.petFrame == CGRect(x: 0, y: 0, width: 136, height: 144))
#expect(expanded.petFrame == CGRect(x: 188, y: 0, width: 136, height: 144))
```

Add an `OverlayController.resize(to:anchor:)` test that starts at a known frame, collapses, preserves `maxX`, updates content/drag bounds, and does not move outside the display clamp.

**Step 2: Run tests to verify RED**

Run:

```bash
swift test --filter 'HabitatOverlayLayoutTests|HabitatPanelTests|HabitatDesktopControllerTests'
```

Expected: fixed `360 x 180` assumptions and missing resize API fail.

**Step 3: Implement mutable bounded panel sizing**

Change `OverlayController.panelSize` to mutable private state. Add a right-edge resize anchor, update panel/content/hosting/drag frames together, clamp the resized origin to the active display, and recompute saved relative placement.

Make `HabitatOverlayLayout.containerSize` depend on expansion state. Connect `HabitatOverlayPresentation.$isWidgetRailExpanded` to the desktop controller so tapping the pet resizes the panel. Scale both sizes by the saved Habitat scale. The SwiftUI root uses the active layout and moves the pet to `x = 0` when collapsed.

**Step 4: Run geometry and interaction tests**

Run:

```bash
swift test --filter 'OverlayHostTests|HabitatOverlayLayoutTests|HabitatDesktopControllerTests'
```

Expected: panel, pet, drag region, and placement tests pass.

**Step 5: Commit**

```bash
git add Sources/OverlayHost Sources/CodexHabitatApp/Overlay Sources/CodexHabitatApp/Diagnostics Tests/OverlayHostTests Tests/CodexHabitatAppTests
git commit -m "fix: collapse Habitat to the visible pet"
```

### Task 6: Correct Token metric presentation

**Files:**
- Modify: `Sources/HabitatCore/State/TokenMetricsSummary.swift`
- Modify: `Sources/CodexHabitatApp/Overlay/WidgetRailView.swift`
- Modify: `Sources/CodexHabitatApp/Settings/WidgetsSettingsView.swift`
- Modify: `Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Tests/WidgetRuntimeTests/TokenMetricTests.swift`
- Modify: `Tests/CodexHabitatAppTests/LocalizationTests.swift`

**Step 1: Write failing metric-semantics tests**

```swift
let metrics = TokenMetricsSummary(
    inputTokens: 300_145_692,
    cachedInputTokens: 290_729_472,
    outputTokens: 879_962,
    reasoningOutputTokens: 299_563,
    totalTokens: 301_025_654,
    lastInputTokens: 248_750,
    lastOutputTokens: 457,
    modelContextWindow: 353_400,
    outputTokensPerMinute: 1_860,
    updatedAt: .now
)
#expect(metrics.latestRequestTokens == 249_207)
#expect(metrics.taskCumulativeTokens == 301_025_654)
```

Add localized presentation expectations for `Latest request`, `Task cumulative`, and `Recent 60-second output`.

**Step 2: Run tests to verify RED**

Run:

```bash
swift test --filter 'TokenMetricTests|LocalizationTests'
```

Expected: missing semantic properties and localization keys fail.

**Step 3: Implement honest labels and secondary detail**

Add overflow-safe computed properties using `addingReportingOverflow`. Change the compact Token row to display `latestRequestTokens`. Add `.help` and accessibility detail for the cumulative task value. Rename the speed row and settings description to `Recent 60-second output`; retain `/min` because the calculation remains a 60-second output delta rate.

Keep context percentage based on `lastInputTokens / modelContextWindow`. Do not estimate missing fields.

**Step 4: Run metric tests**

Run:

```bash
swift test --filter 'TokenMetricTests|SessionTokenMetricsMonitorTests|CodexTokenEventParserTests|LocalizationTests'
```

Expected: all pass.

**Step 5: Commit**

```bash
git add Sources/HabitatCore/State/TokenMetricsSummary.swift Sources/CodexHabitatApp/Overlay/WidgetRailView.swift Sources/CodexHabitatApp/Settings/WidgetsSettingsView.swift Sources/CodexHabitatApp/Resources Tests/WidgetRuntimeTests Tests/CodexHabitatAppTests/LocalizationTests.swift
git commit -m "fix: present Token metrics with accurate semantics"
```

### Task 7: Full verification, visual QA, documentation, and packaging

**Files:**
- Modify: `README.md`
- Modify: `docs/qa/macos-v1-checklist.md`
- Modify: `docs/qa/cdp-compatibility-matrix.md`

**Step 1: Run the complete automated suite**

Run:

```bash
swift test
git diff --check
```

Expected: all tests pass with zero warnings and no whitespace errors.

**Step 2: Build the packaged native app without launching it**

Run:

```bash
scripts/build-app.sh --adhoc
scripts/verify-release.sh "dist/Codex Habitat.app"
```

Expected: signatures, architecture, resources, path privacy, and CDP isolation pass.

**Step 3: Run native visual QA without invoking the theme bridge**

Launch only `Codex Habitat.app` with theme settings visible. Use the `screenshot` skill to capture:

- the twelve-theme gallery;
- expanded pet plus default metrics;
- collapsed pet-only panel.

Inspect original-resolution captures. Verify saturated art, readable text, stable right-edge pet placement, actual collapsed window bounds, no transparent mouse-blocking area, and no overlap at scales `0.75`, `1.0`, and `1.5`. Confirm Reduce Motion still stops pet animation.

Do not click `Apply Selected Theme to Codex` during development QA.

**Step 4: Measure idle and visible resource use**

Sample the packaged Habitat process with the overlay expanded and collapsed. Record CPU and memory in `docs/qa/macos-v1-checklist.md`; confirm hidden/collapsed behavior does not regress the existing polling pause rules.

**Step 5: Package and mount the DMG**

Run:

```bash
scripts/package-dmg.sh
```

Mount read-only, run `CodexHabitatApp --version`, verify the `/Applications` link, and re-run strict signature verification from the mounted image.

**Step 6: Request code review and resolve findings**

Use `requesting-code-review` for a read-only review focused on theme resource security, overlay frame transitions, Token semantics, localization, and release privacy. Fix any P1/P2 finding with a failing regression test.

**Step 7: Update documentation and commit**

Document twelve built-ins, exact Token meanings, compact panel behavior, asset provenance, test count, and the remaining user-initiated live CDP acceptance item.

```bash
git add README.md docs/qa
git commit -m "docs: record game theme and compact overlay QA"
```

**Step 8: Final clean-state check**

Run:

```bash
git status --short
git log -8 --oneline
```

Expected: clean worktree and a reviewable sequence of focused commits.
