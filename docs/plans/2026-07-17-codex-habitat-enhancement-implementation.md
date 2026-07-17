# Codex Habitat Enhancement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver a smooth, draggable, Simplified-Chinese macOS Habitat with useful Codex Token/speed widgets and a visible, reversible CDP deep-theme workflow.

**Architecture:** Keep the native companion, metrics reader, and theme helper separated. The overlay receives one immutable `HabitatSnapshot`; a pet-specific AppKit renderer advances sprite frames without invalidating the SwiftUI tree. A bounded local JSONL reader extracts only Token events, while the existing read-only connector continues to provide exact rate limits when available. The helper owns verified CDP lifecycle and host-compiled styles.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit/Core Animation, Swift Testing, Swift Package Manager, Codex app-server JSON-RPC, Chrome DevTools Protocol.

---

### Task 1: Remove SwiftUI animation update loops

**Files:**
- Create: `Sources/CodexHabitatApp/Overlay/PetSpriteView.swift`
- Modify: `Sources/CodexHabitatApp/Overlay/PetView.swift`
- Modify: `Sources/CodexHabitatApp/Overlay/HabitatOverlayView.swift`
- Modify: `Sources/PetRuntime/Animation/PetAnimator.swift`
- Test: `Tests/CodexHabitatAppTests/HabitatOverlayModelTests.swift`
- Test: `Tests/PerformanceTests/HabitatPerformanceTests.swift`

**Step 1: Write the failing tests**

Add tests proving that frame lookup can run from an isolated driver without
publishing the overlay model, and that inactive/Reduce Motion states install no
timer. Add a performance assertion for one immutable renderer update per tick.

**Step 2: Run the focused tests and verify RED**

Run:

```bash
swift test --filter HabitatOverlayModelTests
swift test --filter HabitatPerformanceTests
```

Expected: FAIL because the isolated sprite driver does not exist.

**Step 3: Implement the minimal renderer**

Create an `NSViewRepresentable` backed by a layer-hosting `NSView`. The
coordinator owns `PetAnimator`, a bounded 8 Hz timer, and pre-rendered frame
images. A tick updates only `layer.contents`; `PetView.body` must not call a
mutating model method or use `TimelineView`.

The coordinator stops its timer for resting, offline, hidden, and Reduce Motion
states and invalidates it in `dismantleNSView`.

**Step 4: Run focused tests and verify GREEN**

Run the two focused commands again. Expected: PASS with no warnings.

**Step 5: Commit**

```bash
git add Sources/CodexHabitatApp/Overlay Sources/PetRuntime/Animation Tests/CodexHabitatAppTests/HabitatOverlayModelTests.swift Tests/PerformanceTests/HabitatPerformanceTests.swift
git commit -m "fix: isolate pet animation rendering"
```

### Task 2: Make the pet reliably movable

**Files:**
- Modify: `Sources/OverlayHost/Window/OverlayController.swift`
- Modify: `Sources/OverlayHost/Window/HabitatPanel.swift`
- Modify: `Sources/CodexHabitatApp/Overlay/HabitatDesktopController.swift`
- Modify: `Sources/CodexHabitatApp/CodexHabitatApp.swift`
- Test: `Tests/OverlayHostTests/HabitatPanelTests.swift`
- Test: `Tests/CodexHabitatAppTests/HabitatDesktopControllerTests.swift`
- Test: `Tests/CodexHabitatAppTests/HabitatMenuBarTests.swift`

**Step 1: Write the failing tests**

Test that the drag region covers the pet frame rather than a 28-point strip,
that the widget rail remains outside the drag hit area, and that temporary move
mode overrides click-through without changing the stored preference.

**Step 2: Run focused tests and verify RED**

```bash
swift test --filter OverlayHostTests
swift test --filter HabitatDesktopControllerTests
swift test --filter HabitatMenuBarTests
```

Expected: FAIL on drag geometry and temporary move mode.

**Step 3: Implement full-pet dragging**

Expose `setDragFrame(_:)` on `OverlayController`; constrain the AppKit drag view
to `HabitatOverlayLayout.petFrame`. Keep the widget rail above it. Add a
menu-bar **Move Habitat** action that temporarily calls `setInteractive(true)`
when click-through is enabled and exits after placement or cancellation.

**Step 4: Run focused tests and verify GREEN**

Run the commands from Step 2. Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/OverlayHost Sources/CodexHabitatApp/Overlay Sources/CodexHabitatApp/CodexHabitatApp.swift Tests/OverlayHostTests Tests/CodexHabitatAppTests
git commit -m "fix: make the Habitat pet draggable"
```

### Task 3: Add privacy-bounded Token metrics

**Files:**
- Create: `Sources/CodexConnector/Metrics/CodexTokenMetrics.swift`
- Create: `Sources/CodexConnector/Metrics/CodexTokenEventParser.swift`
- Create: `Sources/CodexConnector/Metrics/SessionTokenMetricsMonitor.swift`
- Modify: `Sources/HabitatCore/State/HabitatSnapshot.swift`
- Modify: `Sources/HabitatCore/State/HabitatState.swift`
- Modify: `Sources/CodexHabitatApp/Runtime/HabitatRuntimeService.swift`
- Create: `Tests/CodexConnectorTests/Fixtures/token-events-mixed.jsonl`
- Create: `Tests/CodexConnectorTests/CodexTokenEventParserTests.swift`
- Create: `Tests/CodexConnectorTests/SessionTokenMetricsMonitorTests.swift`
- Modify: `Tests/HabitatCoreTests/HabitatStateTests.swift`

**Step 1: Write the failing parser tests**

Cover:

- accepted `event_msg` / `token_count` records;
- rejection of prompt, response, command, tool, and unknown records;
- malformed and truncated JSON tails;
- total/input/cached/output/reasoning fields;
- context-window percentage;
- output-token speed over a bounded recent window;
- reset when the active session file changes.

The public API should be shaped like:

```swift
public struct CodexTokenMetrics: Codable, Equatable, Sendable {
    public let inputTokens: Int
    public let cachedInputTokens: Int
    public let outputTokens: Int
    public let reasoningOutputTokens: Int
    public let totalTokens: Int
    public let modelContextWindow: Int?
    public let outputTokensPerMinute: Double?
    public let updatedAt: Date
}
```

**Step 2: Run focused tests and verify RED**

```bash
swift test --filter CodexTokenEventParserTests
swift test --filter SessionTokenMetricsMonitorTests
```

Expected: compile failure because the metrics types do not exist.

**Step 3: Implement the bounded incremental reader**

Read only appended bytes from the most recently active session file. Split on
newlines with a bounded carry buffer. Inspect the minimal envelope first and
decode metrics only after both accepted type fields match. Never expose a raw
line, thread ID, session path, prompt, response, or command through the public
API or diagnostics.

Publish metrics into a single `HabitatSnapshot` update. Keep exact rate-limit
data from the existing connector when available; absence remains `nil`.

**Step 4: Run focused tests and verify GREEN**

Run the tests from Step 2 plus:

```bash
swift test --filter HabitatStateTests
swift test --filter HabitatRuntimeServiceTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/CodexConnector/Metrics Sources/HabitatCore/State Sources/CodexHabitatApp/Runtime Tests/CodexConnectorTests Tests/HabitatCoreTests Tests/CodexHabitatAppTests/HabitatRuntimeServiceTests.swift
git commit -m "feat: add private local Token metrics"
```

### Task 4: Replace default widgets with useful Codex metrics

**Files:**
- Modify: `Sources/HabitatCore/Settings/HabitatSettings.swift`
- Modify: `Sources/WidgetRuntime/Registry/WidgetRegistry.swift`
- Create: `Sources/WidgetRuntime/Widgets/TokenWidget.swift`
- Create: `Sources/WidgetRuntime/Widgets/ContextWidget.swift`
- Create: `Sources/WidgetRuntime/Widgets/SpeedWidget.swift`
- Modify: `Sources/CodexHabitatApp/Overlay/WidgetRailView.swift`
- Modify: `Sources/CodexHabitatApp/Settings/WidgetsSettingsView.swift`
- Modify: `Sources/ResourceKit/Manifest/HabitatManifest.swift`
- Modify: `Sources/ResourceKit/Validation/ManifestValidator.swift`
- Modify: `Schemas/habitat-pack-v1.schema.json`
- Test: `Tests/WidgetRuntimeTests/WidgetRegistryTests.swift`
- Create: `Tests/WidgetRuntimeTests/TokenMetricTests.swift`
- Modify: `Tests/CodexHabitatAppTests/HabitatOverlayLayoutTests.swift`
- Modify: `Tests/CodexHabitatAppTests/SettingsModelTests.swift`
- Modify: `Tests/ResourceKitTests/ManifestValidatorTests.swift`

**Step 1: Write failing widget and migration tests**

Add `codex.tokens`, `codex.context`, and `codex.speed`. Test compact number
formatting, missing-data states, context clamping, speed formatting, and the
new default order. Test decoding schema-v3 settings into schema v4 without
dropping existing explicit widget choices.

**Step 2: Run focused tests and verify RED**

```bash
swift test --filter WidgetRuntimeTests
swift test --filter SettingsModelTests
swift test --filter ManifestValidatorTests
```

Expected: FAIL because new identifiers/configurations are missing.

**Step 3: Implement the widgets and schema migration**

Default order:

```swift
[.status, .tokens, .context, .speed, .usage]
```

Keep clock, Pomodoro, and countdown registered and selectable. The usage row
must display an unavailable/API-key state instead of `0%` when no rate limit is
present. Use monospaced digits and stable row sizes.

**Step 4: Run focused tests and verify GREEN**

Run Step 2 commands. Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/HabitatCore/Settings Sources/WidgetRuntime Sources/CodexHabitatApp/Overlay/WidgetRailView.swift Sources/CodexHabitatApp/Settings/WidgetsSettingsView.swift Sources/ResourceKit Schemas Tests
git commit -m "feat: add Token context and speed widgets"
```

### Task 5: Localize the complete user interface

**Files:**
- Modify: `Package.swift`
- Modify: `Config/Info.plist`
- Create: `Sources/CodexHabitatApp/Localization/HabitatL10n.swift`
- Create: `Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings`
- Create: `Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: all user-facing files under `Sources/CodexHabitatApp/`
- Modify: `Sources/WidgetRuntime/Registry/WidgetRegistry.swift`
- Create: `Tests/CodexHabitatAppTests/LocalizationTests.swift`

**Step 1: Write the failing localization coverage test**

Load both tables and assert that every declared key exists, has a non-empty
value, and that format placeholders match between languages. Add representative
assertions for onboarding, menu bar, widgets, theme bridge, errors, and
accessibility text.

**Step 2: Run the test and verify RED**

```bash
swift test --filter LocalizationTests
```

Expected: FAIL because localization tables and the key catalog do not exist.

**Step 3: Implement localization**

Use a small typed key catalog backed by `Bundle.module`. Replace hard-coded
user-facing English strings without changing identifiers or protocol values.
Set package default localization to English and declare `zh-Hans` in the app
bundle. Use localized formatters for counts, percentages, speed, and durations.

**Step 4: Run coverage and UI tests**

```bash
swift test --filter LocalizationTests
swift test --filter CodexHabitatAppTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Package.swift Config/Info.plist Sources/CodexHabitatApp Sources/WidgetRuntime/Registry Tests/CodexHabitatAppTests
git commit -m "feat: add Simplified Chinese localization"
```

### Task 6: Make deep Codex themes visible and persistent

**Files:**
- Modify: `Sources/CodexHabitatThemeBridge/CDP/CDPClient.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Session/ThemeBridgeCoordinator.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Session/ThemeSession.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Resources/codex-theme-template.css`
- Create: `Sources/CodexHabitatThemeBridge/Themes/ThemeBackground.swift`
- Modify: `Sources/CodexHabitatThemeBridge/CodexHabitatThemeBridge.swift`
- Modify: `Sources/CodexHabitatApp/Integrations/ThemeBridgeIntegrationModel.swift`
- Modify: `Sources/CodexHabitatApp/App/HabitatAppModel.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ThemesSettingsView.swift`
- Modify: `Sources/CodexHabitatApp/Settings/IntegrationsSettingsView.swift`
- Test: `Tests/CodexHabitatThemeBridgeTests/CDPClientTests.swift`
- Test: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`
- Test: `Tests/CodexHabitatThemeBridgeTests/ThemeBridgeCoordinatorTests.swift`
- Test: `Tests/CodexHabitatAppTests/ThemeBridgeIntegrationModelTests.swift`

**Step 1: Write failing bridge tests**

Cover bounded PNG/JPEG input, unsupported/oversized files, escaped data URLs,
host-owned background placement, `Page.loadEventFired` re-injection, duplicate
event idempotence, helper watch lifecycle, main-app termination restore, and
fail-closed rollback.

**Step 2: Run focused tests and verify RED**

```bash
swift test --filter CodexHabitatThemeBridgeTests
swift test --filter ThemeBridgeIntegrationModelTests
```

Expected: FAIL because background and watch-session APIs are absent.

**Step 3: Implement persistent controlled injection**

Extend the host compiler with bounded local background data and approved
composition fields. Add a helper `watch` command that verifies the recorded
process/listener, observes page targets and navigation, installs one stable
style element per document, and restores when its parent Habitat process exits.

Move the apply/restore controls into the primary theme workflow. Show the exact
state: unavailable, ready, restarting, active, restoring, or failed. Do not
report active until the health check passes.

**Step 4: Run focused tests and verify GREEN**

Run Step 2 commands. Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/CodexHabitatThemeBridge Sources/CodexHabitatApp/Integrations Sources/CodexHabitatApp/App Sources/CodexHabitatApp/Settings Tests/CodexHabitatThemeBridgeTests Tests/CodexHabitatAppTests/ThemeBridgeIntegrationModelTests.swift
git commit -m "feat: apply persistent Codex deep themes"
```

### Task 7: Full verification and release artifact

**Files:**
- Modify: `docs/qa/macos-v1-checklist.md`
- Modify: `docs/qa/cdp-compatibility-matrix.md`
- Modify: `docs/research/open-source-landscape.md`
- Modify: `README.md`

**Step 1: Run the complete suite**

```bash
swift test
swift build -c release
```

Expected: all tests pass and the release build emits no warnings.

**Step 2: Build and verify the app**

```bash
scripts/build-app.sh --adhoc
scripts/package-dmg.sh --adhoc
scripts/verify-release.sh "dist/Codex Habitat.app"
```

Expected: app, helper, resources, localizations, signatures, and DMG verify.

**Step 3: Perform UI and performance QA**

- Capture English and Simplified Chinese settings/overlay screenshots.
- Verify whole-pet drag, widget clicks, click-through temporary move, snapping,
  and persistence.
- Sample static and active CPU for at least 30 seconds each.
- Check unified logs for SwiftUI publishing faults.

Expected: no publishing faults; static average below 1%; active average below
3% on the development machine.

**Step 4: Perform live CDP apply/restore**

Against the verified installed `com.openai.codex` `26.707.91948` bundle:

- apply one built-in background theme;
- capture and inspect the real Codex screenshot;
- navigate/reload and confirm re-injection;
- quit Habitat and confirm official appearance restoration;
- confirm the recorded loopback listener is closed.

**Step 5: Update documentation with only observed results**

Mark checklist entries only when their command or manual observation passed.
Document API-key quota behavior and the token-only local metrics boundary.

**Step 6: Commit**

```bash
git add README.md docs
git commit -m "docs: record Habitat enhancement verification"
```

