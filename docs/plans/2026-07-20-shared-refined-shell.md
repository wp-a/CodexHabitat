# Shared Refined Shell Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Apply a reference-led, refined desktop shell to all twenty-four Codex themes while preserving their original artwork, palettes, and family identities.

**Architecture:** Keep the strongly typed theme protocol and host-owned compiler. Replace competing family border stacks with a small shared material contract plus bounded family modifiers. Extend the offline Playwright fixture so layout, title-bar continuity, final-pixel contrast, dense sidebar behavior, and sub-900px geometry are tested without touching live Codex.

**Tech Stack:** Swift 6, Swift Testing, static CSS templates, Playwright, Node fixture contracts, macOS ad-hoc signing and DMG verification.

---

## Hard Safety Boundary

- Do not call helper `apply`, `start`, `watch`, or `restore`.
- Do not quit, restart, or modify Codex or its official bundle/configuration/signature.
- Use only offline fixture rendering for automated visual work.
- Keep resource packs data-only and preserve the existing network/selector/command safety boundary.
- Leave the active installed Build 12 untouched until the user manually restores official appearance and the helper reports `inactive`.

### Task 1: Establish the shared refined material contract

**Files:**
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeVisualHierarchyTests.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Resources/codex-theme-template.css`

**Step 1: Write the failing tests**

Add RED assertions for every built-in family that require:

- idle home actions to use a single low-intensity border owner;
- composer and shared stage surfaces to avoid competing outer and inset outlines;
- the sidebar/main shared edge to have at most one visible structural boundary;
- selected/focus states to be stronger than idle states;
- no family to emit more than one outer outline for the same home action.

Run:

```bash
swift test --filter ThemeVisualHierarchyTests
```

Expected: FAIL for the current arcade, green chat, anime, fantasy, pixel, and classic border stacks.

**Step 2: Implement the minimal shared shell**

In `ThemeCompiler.styleTreatment`, replace family-specific idle border declarations with a shared low-contrast base and keep family modifiers limited to radius, inner highlight, or one accent edge. Remove duplicate stage/sidebar boundary ownership. Keep family-specific selected and focus treatment separate from idle treatment.

In the template CSS, keep the sidebar translucent and the app scene fixed. Do not add layout declarations, blur to large surfaces, or new background URLs.

**Step 3: Verify GREEN**

```bash
swift test --filter ThemeVisualHierarchyTests
swift test --filter ThemeCompilerTests
```

**Step 4: Commit**

```bash
git add Sources/CodexHabitatThemeBridge Tests/CodexHabitatThemeBridgeTests/ThemeVisualHierarchyTests.swift
git commit -m "feat: unify refined theme shell materials"
```

### Task 2: Protect reading surfaces and final-pixel contrast

**Files:**
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeVisualHierarchyTests.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Modify: `Tests/VisualFixtures/CodexWindow/render.mjs`
- Modify: `Tests/VisualFixtures/CodexWindow/styles.css`

**Step 1: Write the failing tests**

Add fixture assertions that sample composited text/background pairs for primary and secondary text on home, sidebar, task, code, and composer surfaces. Require 4.5:1 for normal text and 3:1 for large text or essential controls. Add a regression assertion that high-frequency artwork does not remain visible through the core task reading surface beyond the bounded threshold.

Run:

```bash
swift test --filter ThemeVisualHierarchyTests
scripts/render-codex-theme-fixtures.sh --check
```

Expected: RED for the light-theme secondary text and high-detail task surfaces.

**Step 2: Implement bounded reading materials**

Add a host-owned semantic reading wash for core text/code/task content. Keep it local to content surfaces, preserve the scene around the work area, and avoid making the entire main surface opaque. Adjust only built-in appearance tokens and semantic muted colors needed to meet the contrast contract; custom protocol bounds remain unchanged.

**Step 3: Verify GREEN**

```bash
swift test --filter ThemeVisualHierarchyTests
scripts/render-codex-theme-fixtures.sh --check
```

**Step 4: Commit**

```bash
git add Sources/CodexHabitatThemeBridge Tests/CodexHabitatThemeBridgeTests/ThemeVisualHierarchyTests.swift Tests/VisualFixtures/CodexWindow
git commit -m "fix: strengthen themed reading surfaces"
```

### Task 3: Expand geometry and dense-workspace fixture coverage

**Files:**
- Modify: `Tests/VisualFixtures/CodexWindow/fixture-contract.mjs`
- Modify: `Tests/VisualFixtures/CodexWindow/render.mjs`
- Modify: `Tests/VisualFixtures/CodexWindow/fixture.html`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`

**Step 1: Write failing contract checks**

Add a `compact` viewport below 900px, a dense bilingual sidebar fixture, title-bar scene checks, and measurements for:

- home content center versus main-surface center;
- composer center versus main-surface center;
- left/right margin delta;
- titlebar/sidebar/main scene material continuity;
- stable row height and non-color selected affordance in the dense sidebar.

Run:

```bash
node --test Tests/VisualFixtures/CodexWindow/fixture-contract.test.mjs
scripts/render-codex-theme-fixtures.sh --check
```

Expected: RED because the current payload has only two viewports, sparse sidebar content, and no center-line metrics.

**Step 2: Implement the fixture and metrics**

Add the compact viewport, long mixed-language fixture rows, and deterministic center/contrast measurements. Keep all resources local and preserve the offline marker and network rejection checks.

**Step 3: Verify GREEN**

```bash
node --test Tests/VisualFixtures/CodexWindow/fixture-contract.test.mjs
scripts/render-codex-theme-fixtures.sh --check
```

**Step 4: Commit**

```bash
git add Tests/VisualFixtures/CodexWindow Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift
git commit -m "test: expand refined shell visual coverage"
```

### Task 4: Refine interaction hierarchy

**Files:**
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeInteractionPolishTests.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Modify: `Tests/VisualFixtures/CodexWindow/render.mjs`

**Step 1: Write failing interaction tests**

Require that idle home actions, selected navigation, keyboard focus, and composer focus-within have strictly increasing visual emphasis without changing dimensions. Add fixture checks for hover/active/focus-visible and reduced-motion computed styles.

Run:

```bash
swift test --filter ThemeInteractionPolishTests
```

Expected: RED for families whose idle borders are already as strong as focus states.

**Step 2: Implement bounded feedback**

Lower idle border alpha and shadow. Reserve saturated colors and 2px outlines for selected or focus-visible states. Keep transforms compositor-only, avoid reflow declarations, and preserve reduced-motion behavior.

**Step 3: Verify GREEN**

```bash
swift test --filter ThemeInteractionPolishTests
swift test --filter CodexHabitatThemeBridgeTests
```

**Step 4: Commit**

```bash
git add Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift Tests/CodexHabitatThemeBridgeTests/ThemeInteractionPolishTests.swift Tests/VisualFixtures/CodexWindow/render.mjs
git commit -m "feat: strengthen refined interaction hierarchy"
```

### Task 5: Offline visual QA and Build 14 packaging

**Files:**
- Modify: `Config/Info.plist`
- Modify: `Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift`
- Generated: `dist/Codex Habitat.app`
- Generated: `dist/Codex-Habitat-0.1.0.dmg`

**Step 1: Run the complete RED-to-GREEN verification set**

```bash
swift test
scripts/render-codex-theme-fixtures.sh --check
```

Render a fresh contact sheet and inspect representative high-risk and mature themes with the screenshot/viewer workflow.

**Step 2: Bump the bundle contract**

Change the build expectation from `13` to `14`, observe the focused test fail, then update `Config/Info.plist` and verify it passes.

**Step 3: Commit the build bump**

```bash
git add Config/Info.plist Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift
git commit -m "chore: bump Habitat build to 14"
```

**Step 4: Build and verify**

```bash
scripts/build-app.sh --adhoc
scripts/verify-release.sh "dist/Codex Habitat.app"
scripts/package-dmg.sh
```

Mount the DMG read-only, run `verify-release.sh` against the mounted app, verify Build 14, arm64, signatures, helper hash, 24 resources, and `/Applications` symlink, then detach.

**Step 5: Stop before live replacement**

Do not replace the active installed Build 12. Ask the user to restore official appearance and confirm the helper is `inactive`; only then may Build 14 be installed for user-initiated live screenshot QA.

**Step 6: Read-only review**

Review the complete change range for geometry, contrast, boundary ownership, family distinctness, safety, and missing tests. Address findings with a new RED → GREEN commit before claiming completion.
