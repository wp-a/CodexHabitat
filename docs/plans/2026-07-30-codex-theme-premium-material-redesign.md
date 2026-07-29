# Codex Theme Premium Material Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the 24 built-in Codex themes' heavy accent-driven skin treatment with a shared semantic material shell, bounded art calibration, and nine polished host-owned family recipes.

**Architecture:** Keep the existing typed theme protocol and compatibility-profile selectors. Add bounded art-calibration values to `HabitatThemeAppearance`, compile semantic material tokens once in `ThemeCompiler`, and let each `HabitatThemeStyleFamily` vary only geometry, material, and selected-state details. Verify the production compiler against the offline Codex fixture across all 144 theme, route, and viewport scenes without applying anything to a live Codex process.

**Tech Stack:** Swift 6.2, Swift Testing, Foundation, SwiftUI preview models, strict JSON Schema, host-owned CSS templates, Node.js, Playwright, local bitmap fixtures, shell release tooling.

**Safety boundary:** Never invoke Theme Bridge `apply`, `start`, `watch`, `enable`, or `restore`; never restart or quit Codex; never modify the official Codex bundle, configuration, or signature. Real CDP visual acceptance remains a manual user step and must not be claimed as passed.

---

### Task 1: Add bounded artwork calibration to the typed theme model

**Files:**
- Modify: `Sources/HabitatCore/Theme/HabitatThemeAppearance.swift`
- Modify: `Sources/HabitatCore/Theme/BuiltInThemeCatalog.swift`
- Modify: `Sources/ResourceKit/Manifest/ManifestDecoder.swift`
- Modify: `Sources/ResourceKit/Validation/ManifestValidator.swift`
- Modify: `Sources/ResourceKit/Creation/ThemePackageBuilder.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ThemeStudioModel.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ThemeTreatmentPreview.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Modify: `Schemas/habitat-pack-v1.schema.json`
- Modify: `Tests/HabitatCoreTests/BuiltInThemeCatalogTests.swift`
- Modify: `Tests/ResourceKitTests/ManifestValidatorTests.swift`
- Modify: `Tests/ResourceKitTests/ThemePackageBuilderTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`
- Modify: `Tests/CodexHabitatAppTests/ThemeStudioModelTests.swift`

**Step 1: Write failing model and protocol tests**

Add tests requiring four optional values with conservative defaults:

```swift
#expect(appearance.resolvedArtSaturation == 0.92)
#expect(appearance.resolvedArtContrast == 0.96)
#expect(appearance.resolvedArtExposure == 0.98)
#expect(appearance.resolvedLocalizedScrimStrength == appearance.resolvedVignetteStrength)
```

Require explicit values to survive manifest decoding, Theme Studio edit round trips, package export, bridge decoding, and compiler token generation. Add strict lower and upper bound cases:

```swift
let invalidCases: [(String, Double)] = [
    ("artSaturation", 0.59), ("artSaturation", 1.21),
    ("artContrast", 0.79), ("artContrast", 1.16),
    ("artExposure", 0.79), ("artExposure", 1.16),
    ("localizedScrimStrength", -0.01), ("localizedScrimStrength", 0.71),
]
```

**Step 2: Run the focused tests and verify RED**

Run:

```bash
swift test --filter 'BuiltInThemeCatalogTests|ManifestValidatorTests|ThemePackageBuilderTests|ThemeStudioModelTests|ThemeCompilerTests'
```

Expected: compilation fails because the four calibration properties and resolved accessors do not exist.

**Step 3: Implement the minimal typed model**

Add optional properties to `HabitatThemeAppearance`:

```swift
public let artSaturation: Double?
public let artContrast: Double?
public let artExposure: Double?
public let localizedScrimStrength: Double?

public var resolvedArtSaturation: Double { artSaturation ?? 0.92 }
public var resolvedArtContrast: Double { artContrast ?? 0.96 }
public var resolvedArtExposure: Double { artExposure ?? 0.98 }
public var resolvedLocalizedScrimStrength: Double {
    localizedScrimStrength ?? resolvedVignetteStrength
}
```

Use protocol bounds of `0.60...1.20`, `0.80...1.15`, `0.80...1.15`, and `0.00...0.70`. Add the keys to strict manifest and bridge allowlists, JSON Schema, package builder output, and Theme Studio's non-visual draft state so editing an existing package preserves values without adding new UI controls.

Extend `BuiltInThemeTreatment` and the catalog helper with defaults, then give each built-in a restrained calibration based on its artwork. Saturated arcade and anime themes use lower saturation and contrast; pale nostalgia and cozy themes retain slightly more color. Do not modify the bitmap files.

**Step 4: Run the focused tests and verify GREEN**

Run:

```bash
swift test --filter 'BuiltInThemeCatalogTests|ManifestValidatorTests|ThemePackageBuilderTests|ThemeStudioModelTests|ThemeCompilerTests'
```

Expected: all focused tests pass, old manifests decode through defaults, and unknown theme keys still fail closed.

**Step 5: Commit**

```bash
git add Sources/HabitatCore Sources/ResourceKit Sources/CodexHabitatApp/Settings Sources/CodexHabitatThemeBridge/Themes Schemas Tests/HabitatCoreTests Tests/ResourceKitTests Tests/CodexHabitatAppTests/ThemeStudioModelTests.swift Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift
git commit -m "feat: add bounded theme artwork calibration"
```

### Task 2: Rebuild the shared semantic material shell

**Files:**
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Resources/codex-theme-template.css`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeVisualHierarchyTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeSidebarContinuityTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeHomeGeometryTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`

**Step 1: Write failing semantic-material tests**

Require every compiled theme to emit these semantic tokens:

```swift
let requiredTokens = [
    "--habitat-stage-scrim:", "--habitat-sidebar-chrome:",
    "--habitat-header-chrome:", "--habitat-action-fill:",
    "--habitat-composer-fill:", "--habitat-popover-fill:",
    "--habitat-divider:", "--habitat-selected-fill:",
    "--habitat-focus-ring:", "--habitat-ambient-shadow:",
]
```

Parse the generated rules and require that idle home actions, composer, header, and sidebar do not use `var(--habitat-accent)` for borders, outlines, or outer box-shadow halos. Require one fixed art consumer whose rule contains bounded `saturate`, `contrast`, and `brightness` filters.

Add route hierarchy assertions rather than one impossible global alpha value:

- title bar alpha remains at or below `0.20` on immersive home routes;
- sidebar is more opaque than the title bar on every route;
- task sidebar and task header are at least as opaque as their home equivalents;
- composer is more opaque than the home content actions;
- main stage background remains transparent so the full-window art layer is visible.

**Step 2: Run the bridge tests and verify RED**

Run:

```bash
swift test --filter 'ThemeVisualHierarchyTests|ThemeSidebarContinuityTests|ThemeHomeGeometryTests|ThemeCompilerTests'
```

Expected: failures report missing semantic tokens, accent-owned idle boundaries, and the current `workbench` sidebar hierarchy mismatch.

**Step 3: Compile the shared semantic token layer**

Derive opaque neutral anchors and bounded material values once in `ThemeCompiler`. Decorative accent is reserved for selected indicator, focus, and submit. Repeated idle actions use a neutral divider mixed from `panelAlt` and `text`. Tint ambient shadows toward `surface`, never pure black.

Replace template-level ad hoc `color-mix` expressions with semantic variables. Move saturation, contrast, and exposure to the fixed non-interactive artwork pseudo-element. Use a safe-side localized scrim on a second non-interactive pseudo-element; do not draw the bitmap again.

The shared shell must implement:

```css
background-color: var(--habitat-action-fill);
border: 1px solid var(--habitat-divider);
box-shadow: inset 0 1px 0 var(--habitat-inner-highlight);
```

The composer may add one tinted ambient shadow. No idle surface may add a `0 0 0 2px` halo or a permanent accent rail.

**Step 4: Run the bridge tests and verify GREEN**

Run:

```bash
swift test --filter 'ThemeVisualHierarchyTests|ThemeSidebarContinuityTests|ThemeHomeGeometryTests|ThemeCompilerTests'
```

Expected: all focused tests pass for 24 themes and the compiler still rejects unsafe templates and art URLs.

**Step 5: Commit**

```bash
git add Sources/CodexHabitatThemeBridge Tests/CodexHabitatThemeBridgeTests
git commit -m "feat: rebuild Codex theme material shell"
```

### Task 3: Refine all nine host-owned family recipes

**Files:**
- Modify: `Sources/HabitatCore/Theme/HabitatThemeSurfaceRecipe.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Modify: `Tests/HabitatCoreTests/BuiltInThemeCatalogTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeVisualHierarchyTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeInteractionPolishTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`

**Step 1: Write failing family-quality tests**

Require nine unique structural signatures and bounded geometry:

```swift
let recipes = HabitatThemeStyleFamily.allCases.map(\.surfaceRecipe)
#expect(Set(recipes.map(\.signature)).count == 9)
#expect(recipes.allSatisfy { (0...12).contains($0.actionRadius) })
#expect(recipes.allSatisfy { (0...12).contains($0.composerRadius) })
#expect(recipes.allSatisfy { $0.actionEdgeWidth <= 1 })
#expect(recipes.allSatisfy { $0.selectedEdgeWidth <= 2 })
```

For each family, parse the base, hover, pressed, focus, and reduced-motion rules. Require no layout properties, no transition shorthand, no repeated-action blur, no idle accent border, and no persistent glow. Require family signatures to differ through at least two of material style, radius system, header detail, selected indicator, composer shadow, or line style.

**Step 2: Run family tests and verify RED**

Run:

```bash
swift test --filter 'BuiltInThemeCatalogTests|ThemeVisualHierarchyTests|ThemeInteractionPolishTests|ThemeCompilerTests'
```

Expected: current thick selected edges, double/dashed decorative lines, and broad accent mixing violate the new bounds.

**Step 3: Implement the nine refined recipes**

Implement the approved family language:

- `retroMessenger`: compact pale glass and crisp one-pixel highlight edges;
- `greenChat`: light pane divisions and restrained selected band;
- `classicDesktop`: opaque neutral surfaces and a minimal one-pixel bevel;
- `arcade`: smoked acrylic and a small active chromatic edge;
- `gameCinematic`: calm charcoal scrims and low-radius image-led surfaces;
- `cozyWorld`: soft translucent surfaces and controlled rounded geometry;
- `animeEnergy`: clean graphic planes and a firm two-pixel selected indicator;
- `fantasyAdventure`: jewel-tinted glass and a fine inner highlight;
- `pixelWorld`: low-radius modular surfaces and precise two-step depth.

Keep hover and pressed feedback within 120-180 ms. Use transform and opacity only for movement. Disable transforms and shorten transitions under reduced motion.

**Step 4: Run family tests and verify GREEN**

Run:

```bash
swift test --filter 'BuiltInThemeCatalogTests|ThemeVisualHierarchyTests|ThemeInteractionPolishTests|ThemeCompilerTests'
```

Expected: nine distinct signatures pass, every family retains complete interaction states, and repeated actions remain neutral when idle.

**Step 5: Commit**

```bash
git add Sources/HabitatCore/Theme/HabitatThemeSurfaceRecipe.swift Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift Tests/HabitatCoreTests Tests/CodexHabitatThemeBridgeTests
git commit -m "feat: refine Codex theme family materials"
```

### Task 4: Upgrade the 144-scene offline visual contract

**Files:**
- Modify: `Tests/VisualFixtures/CodexWindow/fixture-contract.mjs`
- Modify: `Tests/VisualFixtures/CodexWindow/fixture-contract.test.mjs`
- Modify: `Tests/VisualFixtures/CodexWindow/render.mjs`
- Modify: `Tests/VisualFixtures/CodexWindow/package.json`
- Modify: `docs/qa/screenshots/2026-07-18/offline-codex-window/README.md` only if it incorrectly describes the current baseline
- Create: `docs/qa/screenshots/2026-07-30-premium-codex-themes/README.md`
- Create: `docs/qa/screenshots/2026-07-30-premium-codex-themes/metrics.json`
- Create: `docs/qa/screenshots/2026-07-30-premium-codex-themes/contact-sheets/*.png`
- Create: `docs/qa/screenshots/2026-07-30-premium-codex-themes/scenes/**/*.png`
- Create: `docs/qa/screenshots/2026-07-30-premium-codex-themes/primary/*.png`

**Step 1: Write failing fixture-contract tests**

Replace the hard-coded `0.87...0.90` sidebar assertion with the semantic route hierarchy approved in Task 2. Add metric checks for:

- all 24 themes, two routes, and three viewports;
- exactly one artwork consumer;
- no horizontal overflow or overlapping controls;
- stable action and composer bounds across hover and focus;
- minimum text contrast and nonblank artwork delta;
- task surfaces stronger than home surfaces;
- neutral idle action border and one accent maximum;
- complete wide, narrow, and compact contact sheets.

**Step 2: Run fixture unit tests and verify RED**

Run:

```bash
npm --prefix Tests/VisualFixtures/CodexWindow test
```

Expected: fixture tests fail until the new metric fields and semantic hierarchy assertions are implemented.

**Step 3: Implement fixture metrics and contract**

Measure computed background alpha and boundary color separately for stage, sidebar, header, action, task reading surface, composer, selection, and focus. Store per-scene values in `metrics.json`. Generate six contact sheets: home and task for wide, narrow, and compact.

Keep the fixture local and deterministic. Reject every network request. Continue using the production resolver, compiler, installer, and pinned compatibility profile.

**Step 4: Render the golden light and dark pair**

Render `retro-messenger` and `workbench` at all routes and viewports using a fixture filter or temporary test selection that is removed before commit. Inspect the original-resolution PNGs for background composition, sidebar continuity, content hierarchy, composer stability, and restrained accent use.

Expected: the light theme no longer looks washed out, the dark theme no longer uses four black slabs, and both share the same product hierarchy.

**Step 5: Render all 144 scenes and verify GREEN**

Run:

```bash
rm -rf /tmp/codex-habitat-premium-theme-qa
scripts/render-codex-theme-fixtures.sh --write /tmp/codex-habitat-premium-theme-qa
```

Expected: contract passes, 144 scene PNGs plus primary captures, contact sheets, and `metrics.json` are present. Inspect representative light, dark, nostalgia, cinematic, cozy, anime, fantasy, and pixel themes at original resolution.

Copy the verified output into `docs/qa/screenshots/2026-07-30-premium-codex-themes/`. Record the exact commit, command, scene count, material ranges, minimum contrast, and the explicit statement that no live Codex process was touched.

**Step 6: Commit**

```bash
git add Tests/VisualFixtures/CodexWindow docs/qa/screenshots/2026-07-30-premium-codex-themes
git commit -m "test: verify premium Codex theme scenes"
```

### Task 5: Run full release verification and package Build 17

**Files:**
- Modify: `Config/Info.plist`
- Modify: `docs/qa/macos-v1-checklist.md`
- Modify: `docs/qa/phase3-readiness.md`
- Modify: `docs/qa/codex-runtime-compatibility.md` only if compiler compatibility evidence changes

**Step 1: Increment the bundle build**

Change `CFBundleVersion` from `16` to `17`. Do not change the marketing version unless the existing release policy requires it.

**Step 2: Run complete automated verification**

Run:

```bash
swift test --no-parallel --skip 'tempRender'
npm --prefix Tests/VisualFixtures/CodexWindow test
scripts/render-codex-theme-fixtures.sh --check
git diff --check
```

Expected: every command exits zero. Record the actual Swift test and suite counts rather than copying an old number.

**Step 3: Build and verify the ad-hoc app**

Run:

```bash
scripts/build-app.sh --adhoc
scripts/verify-release.sh "dist/Codex Habitat.app"
codesign --verify --deep --strict --verbose=2 "dist/Codex Habitat.app"
```

Expected: Build 17 is created, `verify-release` passes, both executables have the current machine architecture, and strict signatures pass.

Do not launch Codex Habitat if offline fixture evidence is sufficient. Launching Habitat for native screenshots is allowed only if required and must not trigger Theme Bridge live actions.

**Step 4: Package and mount-test the DMG**

Run:

```bash
scripts/package-dmg.sh
hdiutil attach -readonly -nobrowse "dist/Codex-Habitat-0.1.0.dmg"
```

Verify the mounted volume is read-only, contains `Codex Habitat.app` and the `/Applications` symlink, reports version `0.1.0` Build `17`, and passes mounted-bundle `verify-release` plus strict signature checks. Detach the volume and calculate SHA-256.

**Step 5: Update QA records**

Record commands, test counts, visual fixture result, Build 17 identity, DMG hash, read-only mount evidence, and signature results. State clearly:

- live apply was not run;
- Codex was not restarted or quit;
- the official Codex bundle, configuration, and signature were not modified;
- real CDP visual acceptance remains manual and unverified.

**Step 6: Request a read-only code review**

Review the final diff for security boundary regressions, unsafe selector or URL acceptance, theme protocol compatibility, visual-contract blind spots, and missing tests. Address any confirmed finding with a new RED to GREEN commit.

**Step 7: Commit**

```bash
git add Config/Info.plist docs/qa
git commit -m "docs: record build 17 theme verification"
```

**Step 8: Final repository check**

Run:

```bash
git status --short
git log -8 --oneline
```

Expected: only the user's pre-existing untracked temporary render tests remain. Do not add, modify, or delete them.
