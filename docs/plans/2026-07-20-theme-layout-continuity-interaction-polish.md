# Theme Layout Continuity and Interaction Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Preserve Codex's centered native home geometry while making all twenty-four themes continuous across the sidebar and more responsive to hover, press, focus, and reduced-motion preferences.

**Architecture:** Keep the existing strongly typed theme manifests and compatibility-profile selectors. Change only host-owned compiler/template CSS: `safeSide` continues to drive artwork scrims, while Codex owns layout geometry; the app-shell scene stays fixed beneath translucent route-aware chrome; interaction feedback targets existing controls without JavaScript or layout-changing declarations.

**Tech Stack:** Swift 6, Swift Testing, typed theme compiler, static CSS templates, offline HTML fixtures, macOS ad-hoc signing and release verification.

---

## Hard Safety Boundary

- Do not run helper `apply`, `start`, `watch`, or `restore` during development.
- Do not restart, quit, or modify Codex.
- Do not modify the official Codex app, `app.asar`, configuration, signature, or preferences.
- The currently running Habitat owns an active theme session. Do not quit or replace the running `/Applications/Codex Habitat.app` until the user manually restores the official appearance and the helper reports `inactive`.
- All automated visual work must use offline fixtures. Live Codex acceptance remains user initiated.

### Task 1: Preserve Native Home Geometry

**Files:**
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`

**Step 1: Write the failing geometry contract**

Replace the side-inset expectation with a test that compiles every built-in theme and inspects the rule for the complete home `[role="main"]` selector:

```swift
@Test
func everyThemePreservesHostOwnedHomeGeometry() throws {
    let profile = try currentCompleteSurfaceProfile()
    let homeContent = try #require(profile.selectors.homeContent)
    let selector = "html[data-codex-habitat-theme=\"1\"][data-codex-habitat-route=\"home\"] \(homeContent)"

    for themeID in BuiltInThemeCatalog.all.map(\.id) {
        let theme = try #require(BridgeTheme.builtIn(id: themeID))
        let css = try ThemeCompiler.bundled().compile(theme: theme, profile: profile)
        for body in try cssRuleBodies(selector: selector, in: css) {
            #expect(!body.contains("max-width:"), "\(themeID) overrides host width")
            #expect(!body.contains("margin-inline"), "\(themeID) offsets host content")
            #expect(!body.contains("translate"), "\(themeID) translates host content")
        }
    }
}
```

Also assert the generated CSS no longer contains Habitat-owned `@media` rules that change the complete home surface width.

**Step 2: Run the test to verify RED**

Run:

```bash
swift test --filter everyThemePreservesHostOwnedHomeGeometry
```

Expected: FAIL because `surfaceTreatment` currently emits `max-width` and asymmetric `margin-inline` declarations.

**Step 3: Remove Habitat-owned home geometry**

In `ThemeCompiler.surfaceTreatment`, retain color/background treatment for `homeContent` but remove:

- `max-width: min(...)`;
- `homeContentLayout(for:)` output;
- the 1180px and 900px geometry media queries.

Delete the now-unused `homeContentLayout(for:)` helper. Keep `safeSide` usage in scrim generation and artwork composition.

**Step 4: Run GREEN verification**

Run:

```bash
swift test --filter everyThemePreservesHostOwnedHomeGeometry
swift test --filter ThemeCompilerTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift
git commit -m "fix: preserve Codex home geometry"
```

### Task 2: Continue the Scene Through the Sidebar

**Files:**
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Resources/codex-theme-template.css`

**Step 1: Write failing sidebar-continuity tests**

Add a test that compiles all built-ins and verifies the base, home, and task sidebar rules:

```swift
@Test
func everyThemeKeepsTheSceneVisibleThroughRouteAwareSidebarWashes() throws {
    let profile = try currentCompleteSurfaceProfile()
    let sidebar = profile.selectors.sidebar
    for themeID in BuiltInThemeCatalog.all.map(\.id) {
        let css = try ThemeCompiler.bundled().compile(
            theme: try #require(BridgeTheme.builtIn(id: themeID)),
            profile: profile
        )
        let base = try cssRuleBody(
            selector: "html[data-codex-habitat-theme=\"1\"] \(sidebar)",
            in: css
        )
        #expect(base.contains("background-color: transparent"))
        #expect(base.contains("background-image: linear-gradient"))
        #expect(base.contains("backdrop-filter: none"))
        #expect(!base.contains("blur("))
        #expect(css.contains("--habitat-task-sidebar-opacity"))
    }
}
```

Add an assertion that the app-shell scene remains `position: fixed`, `inset: 0`, and uses one `var(--habitat-art-background)` source rather than a separately repeated sidebar image.

**Step 2: Run the tests to verify RED**

Run:

```bash
swift test --filter everyThemeKeepsTheSceneVisibleThroughRouteAwareSidebarWashes
```

Expected: FAIL because the sidebar currently uses a flat `background-color` slab.

**Step 3: Implement the translucent route-aware wash**

In `codex-theme-template.css`:

- set the sidebar background color to transparent;
- use a left-to-right gradient derived from `--habitat-panel`, `--habitat-panel-alt`, and `--habitat-sidebar-opacity`;
- add a stronger task-route gradient derived from `--habitat-task-sidebar-opacity`;
- end the gradient with a softer translucent edge so the fixed scene reads continuously into the main surface;
- explicitly keep `backdrop-filter: none`.

Do not add a second background image or URL to the sidebar.

**Step 4: Run GREEN verification**

Run:

```bash
swift test --filter everyThemeKeepsTheSceneVisibleThroughRouteAwareSidebarWashes
swift test --filter ThemeCompilerTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/CodexHabitatThemeBridge/Resources/codex-theme-template.css Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift
git commit -m "feat: continue theme scenes through sidebar"
```

### Task 3: Add Bounded Native Interaction Feedback

**Files:**
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`

**Step 1: Write failing interaction-contract tests**

Add tests that compile every allowlisted `styleFamily` and require:

- home action `:hover` and `:active` rules;
- sidebar actionable `:hover` and `:active` rules;
- composer `:focus-within` feedback;
- an existing `:focus-visible` keyboard rule;
- a `@media (prefers-reduced-motion: reduce)` fallback;
- transition rules limited to color, border-color, background-color, box-shadow, opacity, and transform;
- no width, height, margin, padding, position, inset, or display changes in interaction-state rule bodies.

Use exact selector strings generated from the compatibility profile rather than hard-coded unversioned selectors.

**Step 2: Run the tests to verify RED**

Run:

```bash
swift test --filter themeInteractionsProvideStableHoverPressFocusAndReducedMotionFeedback
```

Expected: FAIL because hover/active/focus-within/reduced-motion rules are incomplete.

**Step 3: Implement CSS-only feedback**

Extend `ThemeCompiler.styleTreatment` to emit:

```css
@media (hover: hover) and (pointer: fine) { /* theme-token hover feedback */ }
/* pressed feedback using compositor-only transform and opacity */
/* composer focus-within border and shadow */
@media (prefers-reduced-motion: reduce) { transition: none; transform: none; }
```

Reuse semantic theme variables and the existing style-family treatment. Do not add JavaScript, event listeners, new controls, or layout-changing declarations.

**Step 4: Run GREEN verification**

Run:

```bash
swift test --filter themeInteractionsProvideStableHoverPressFocusAndReducedMotionFeedback
swift test --filter ThemeCompilerTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift
git commit -m "feat: polish native theme interactions"
```

### Task 4: Offline Visual QA and Build 13

**Files:**
- Modify: `Config/Info.plist`
- Modify: `Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift`
- Generated: `dist/Codex Habitat.app`
- Generated: release DMG under `dist/`

**Step 1: Run all compiler and fixture checks**

Run:

```bash
swift test
scripts/render-codex-theme-fixtures.sh --check
```

Expected: all tests and all 24 x route x viewport offline scenes pass without overflow or blank artwork.

Inspect representative screenshots for centered content, continuous sidebar artwork, text contrast, hover-independent geometry, and compact wrapping. Do not use live Codex CDP.

**Step 2: Bump the build contract RED to GREEN**

Change the bundle test expectation from `12` to `13`, run the focused test and confirm failure, then update `Config/Info.plist` to `13` and confirm it passes.

Run:

```bash
swift test --filter mainBundleConfigurationDeclaresAStandardVisibleBuildThirteenApp
```

Expected after implementation: PASS.

**Step 3: Commit the build bump**

```bash
git add Config/Info.plist Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift
git commit -m "chore: bump Habitat build to 13"
```

**Step 4: Build and verify the release artifacts**

Run:

```bash
scripts/build-app.sh --adhoc
scripts/verify-release.sh "dist/Codex Habitat.app"
scripts/package-dmg.sh --adhoc
```

Mount the DMG read-only, verify the app bundle, helper, build number, architecture, signatures, resources, and absence of unsafe update/CDP paths, then unmount it.

**Step 5: Do not replace the active installed app**

Because the current Build 12 process owns an active theme session, leave Build 13 in `dist/` until the user manually restores official appearance. Confirm read-only helper `status` becomes `inactive`; only then quit/install/reopen Habitat and use the `screenshot` skill for packaged gallery QA.

**Step 6: Read-only review**

Run a final read-only code review over the commits from this plan, prioritizing geometry regressions, selector safety, contrast, reduced motion, and missing tests. Address any finding through a new RED to GREEN commit.

