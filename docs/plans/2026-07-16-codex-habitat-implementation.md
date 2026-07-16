# Codex Habitat Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native macOS menu-bar companion that renders existing Codex pets and compact widgets from read-only Codex state, supports safe portable resource packs, and offers an isolated optional CDP theme bridge.

**Architecture:** A Swift 6 package contains small library targets for state, Codex transport, pets, widgets, resources, and AppKit overlay behavior, plus GUI and theme-helper executable targets. The GUI consumes immutable snapshots from a single actor; the Codex connector drops sensitive payloads at the decode boundary; all third-party resources remain static data. The theme helper is a separate process and is never on the critical path for pets or widgets.

**Tech Stack:** Swift 6.3, SwiftUI, AppKit, Foundation, Network, CryptoKit, Swift Testing/XCTest, ZIPFoundation, Sparkle 2, Swift Package Manager, Xcode 26.

---

## Working Rules

- Work from a dedicated worktree created from `main`.
- Use strict Swift concurrency and macOS 14 as the deployment baseline.
- Run the narrow test first, then `swift test` before every task commit.
- Keep app-server methods on an explicit read allowlist. Do not add write-capable
  Codex methods while implementing this plan.
- Never copy source from a repository without a compatible license. Keep
  attribution in `THIRD_PARTY_NOTICES.md` when code or assets are incorporated.
- Do not use personal pets under `~/.codex/pets` as committed fixtures.

## Milestone A: Native Shell and Read-Only State

### Task 1: Create the Swift package and target boundaries

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/HabitatCore/HabitatCore.swift`
- Create: `Sources/CodexConnector/CodexConnector.swift`
- Create: `Sources/PetRuntime/PetRuntime.swift`
- Create: `Sources/WidgetRuntime/WidgetRuntime.swift`
- Create: `Sources/ResourceKit/ResourceKit.swift`
- Create: `Sources/OverlayHost/OverlayHost.swift`
- Create: `Sources/CodexHabitatApp/CodexHabitatApp.swift`
- Create: `Sources/CodexHabitatThemeBridge/main.swift`
- Create: `Tests/HabitatCoreTests/PackageSmokeTests.swift`

**Step 1: Write the failing package smoke test**

```swift
import Testing
@testable import HabitatCore

@Test func packageExposesVersion() {
    #expect(HabitatCore.version == "0.1.0-dev")
}
```

**Step 2: Declare the package targets**

Create a macOS 14 package with the six library targets, two executable targets,
and corresponding test targets. Enable Swift 6 language mode. Keep third-party
dependencies empty in this task.

**Step 3: Run the test and verify the expected failure**

Run: `swift test --filter PackageSmokeTests`

Expected: FAIL because `HabitatCore.version` does not exist.

**Step 4: Add the minimal version API and executable entry points**

```swift
public enum HabitatCore {
    public static let version = "0.1.0-dev"
}
```

The GUI executable should contain only a SwiftUI `@main` app with a placeholder
`Settings` scene and menu-bar extra. The theme helper should print its version
for `--version` and exit.

**Step 5: Verify the package**

Run: `swift test`

Expected: all tests PASS.

Run: `swift run CodexHabitatThemeBridge --version`

Expected: `Codex Habitat Theme Bridge 0.1.0-dev`.

**Step 6: Commit**

```bash
git add Package.swift .gitignore Sources Tests
git commit -m "build: scaffold native Codex Habitat package"
```

### Task 2: Define the sanitized Habitat state model

**Files:**
- Create: `Sources/HabitatCore/State/AgentActivity.swift`
- Create: `Sources/HabitatCore/State/HabitatSnapshot.swift`
- Create: `Sources/HabitatCore/State/HabitatState.swift`
- Test: `Tests/HabitatCoreTests/HabitatStateTests.swift`

**Step 1: Write failing state-transition tests**

Cover these inputs and outputs:

```swift
#expect(AgentActivity.codexStatus(.active) == .working)
#expect(AgentActivity.codexStatus(.idle) == .resting)
#expect(AgentActivity.codexStatus(.systemError) == .failed)
```

Also verify that `.completed` briefly publishes `.succeeded` before returning to
`.resting` when a test clock advances.

**Step 2: Run the narrow test**

Run: `swift test --filter HabitatStateTests`

Expected: FAIL because the state types do not exist.

**Step 3: Implement immutable snapshots and the actor**

Define `AgentActivity` as `resting`, `working`, `attention`, `succeeded`,
`failed`, and `offline`. `HabitatSnapshot` contains only activity, a hashed
thread identifier, event timestamp, connection health, rate-limit summaries,
and timer summaries. Implement `HabitatState` as an actor that yields snapshots
through `AsyncStream`.

**Step 4: Verify behavior**

Run: `swift test --filter HabitatStateTests`

Expected: PASS.

Run: `swift test`

Expected: all tests PASS.

**Step 5: Commit**

```bash
git add Sources/HabitatCore/State Tests/HabitatCoreTests/HabitatStateTests.swift
git commit -m "feat: add sanitized Habitat state model"
```

### Task 3: Add settings and privacy-preserving persistence

**Files:**
- Create: `Sources/HabitatCore/Settings/HabitatSettings.swift`
- Create: `Sources/HabitatCore/Settings/SettingsStore.swift`
- Create: `Sources/HabitatCore/Storage/AppDirectories.swift`
- Test: `Tests/HabitatCoreTests/SettingsStoreTests.swift`

**Step 1: Write failing round-trip and migration tests**

Verify default settings, JSON round-trip, unknown-field tolerance, schema
migration, and an application-support root supplied by the test rather than the
real home directory.

```swift
let store = SettingsStore(root: temporaryDirectory)
try await store.save(.default)
#expect(try await store.load() == .default)
```

**Step 2: Run the test**

Run: `swift test --filter SettingsStoreTests`

Expected: FAIL because the settings store does not exist.

**Step 3: Implement settings and directories**

Settings include selected pet ID, selected theme ID, widget order, overlay
position per display, scale, click-through, launch-at-login preference, Reduce
Motion override, and a disabled-by-default theme bridge. Write JSON atomically
with restrictive file permissions. Do not store Codex tokens or raw events.

**Step 4: Verify**

Run: `swift test --filter SettingsStoreTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/HabitatCore/Settings Sources/HabitatCore/Storage Tests/HabitatCoreTests/SettingsStoreTests.swift
git commit -m "feat: persist Habitat settings safely"
```

### Task 4: Implement JSON-RPC and WebSocket stream codecs

`codex app-server proxy` exposes the running app's Unix control socket through
stdin/stdout, but the proxied bytes still contain an HTTP WebSocket upgrade and
RFC 6455 frames. Do not treat proxy output as JSONL.

**Files:**
- Create: `Sources/CodexConnector/Transport/WebSocketFrameCodec.swift`
- Create: `Sources/CodexConnector/Transport/WebSocketHandshake.swift`
- Create: `Sources/CodexConnector/Protocol/JSONRPCMessage.swift`
- Create: `Sources/CodexConnector/Protocol/JSONRPCCodec.swift`
- Test: `Tests/CodexConnectorTests/WebSocketFrameCodecTests.swift`
- Test: `Tests/CodexConnectorTests/JSONRPCCodecTests.swift`

**Step 1: Write failing codec tests**

Use fixed byte fixtures to verify:

- client text frames are masked;
- server text frames decode without masking;
- 16-bit and 64-bit payload lengths;
- fragmented text reassembly;
- ping produces pong;
- close is surfaced;
- invalid RSV bits and oversized frames are rejected;
- JSON-RPC request, response, notification, and server request decoding.

**Step 2: Run tests**

Run: `swift test --filter WebSocketFrameCodecTests`

Expected: FAIL because the codec is missing.

**Step 3: Implement bounded codecs**

Use `CryptoKit.Insecure.SHA1` for `Sec-WebSocket-Accept`, a secure random
four-byte mask for client frames, and a 1 MiB maximum control-plane message.
Decode JSON-RPC into typed envelopes with a raw `JSONValue` payload.

**Step 4: Verify**

Run: `swift test --filter 'WebSocketFrameCodecTests|JSONRPCCodecTests'`

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/CodexConnector/Transport Sources/CodexConnector/Protocol Tests/CodexConnectorTests
git commit -m "feat: add Codex control socket codecs"
```

### Task 5: Sanitize Codex events at the decode boundary

**Files:**
- Create: `Sources/CodexConnector/Protocol/CodexReadEvent.swift`
- Create: `Sources/CodexConnector/Protocol/CodexEventSanitizer.swift`
- Create: `Tests/CodexConnectorTests/Fixtures/active-thread.json`
- Create: `Tests/CodexConnectorTests/Fixtures/sensitive-item.json`
- Test: `Tests/CodexConnectorTests/CodexEventSanitizerTests.swift`

**Step 1: Add redacted fixtures and failing tests**

Fixtures must use invented paths and text. Assert that decoded public events
contain status, timestamp, event category, and SHA-256 thread hash, but expose no
properties for message text, command text, CWD, file path, reasoning, or output.

**Step 2: Run the sanitizer tests**

Run: `swift test --filter CodexEventSanitizerTests`

Expected: FAIL.

**Step 3: Implement an allowlist sanitizer**

Handle `thread/started`, `thread/status/changed`, `turn/started`,
`turn/completed`, server requests that mean attention, `error`, and
`account/rateLimits/updated`. Ignore every unrecognized method. Hash thread IDs
with an app-local salt stored in settings support, never with a fixed public
salt.

**Step 4: Verify privacy assertions**

Run: `swift test --filter CodexEventSanitizerTests`

Expected: PASS.

Run: `rg -n '(/Users/|command|prompt|reasoning)' Tests/CodexConnectorTests/Fixtures`

Expected: no real paths or sensitive fixture content.

**Step 5: Commit**

```bash
git add Sources/CodexConnector/Protocol Tests/CodexConnectorTests
git commit -m "feat: sanitize Codex events at ingestion"
```

### Task 6: Connect read-only to the running Codex app server

**Files:**
- Create: `Sources/CodexConnector/Transport/ProcessTransport.swift`
- Create: `Sources/CodexConnector/Client/CodexControlClient.swift`
- Create: `Sources/CodexConnector/Client/ReadMethodAllowlist.swift`
- Create: `Sources/CodexConnector/Client/ReconnectPolicy.swift`
- Test: `Tests/CodexConnectorTests/CodexControlClientTests.swift`
- Create: `Tests/CodexConnectorTests/Support/FakeByteTransport.swift`

**Step 1: Write failing client tests**

Verify HTTP upgrade, initialize/initialized ordering, `thread/loaded/list`,
metadata-only thread reads/subscriptions, `account/rateLimits/read`, ping/pong,
process exit, and exponential backoff with jitter. Assert that attempts to call
`turn/start`, approval responses, filesystem methods, or process methods are
rejected locally before transport.

**Step 2: Run the tests**

Run: `swift test --filter CodexControlClientTests`

Expected: FAIL.

**Step 3: Implement the proxy process and client**

Launch `/usr/bin/env codex app-server proxy` with `Process`, pipe stdin/stdout,
perform the WebSocket upgrade, initialize with a Habitat client descriptor, and
send only allowlisted read requests. Decode notifications through
`CodexEventSanitizer` before publishing them.

**Step 4: Add a manual read-only smoke command**

Add `Sources/CodexHabitatApp/Diagnostics/CodexDoctor.swift` so a debug build can
initialize, list loaded thread IDs, request rate limits, print counts/statuses
only, and disconnect. It must not print raw IDs or payloads.

**Step 5: Verify**

Run: `swift test --filter CodexControlClientTests`

Expected: PASS.

Run with Codex open: `swift run CodexHabitatApp --doctor-codex`

Expected: connection status, loaded-thread count, and rate-limit availability;
no messages, commands, paths, or raw thread IDs.

**Step 6: Commit**

```bash
git add Sources/CodexConnector Sources/CodexHabitatApp/Diagnostics Tests/CodexConnectorTests
git commit -m "feat: connect to Codex read-only control plane"
```

## Milestone B: Pets, Overlay, and Widgets

### Task 7: Discover and validate existing Codex pets

**Files:**
- Create: `Sources/PetRuntime/Model/PetManifest.swift`
- Create: `Sources/PetRuntime/Library/PetLibrary.swift`
- Create: `Sources/PetRuntime/Validation/PetValidator.swift`
- Create: `Tests/PetRuntimeTests/Fixtures/valid-pet/pet.json`
- Create: `Tests/PetRuntimeTests/Fixtures/invalid-pet/pet.json`
- Test: `Tests/PetRuntimeTests/PetLibraryTests.swift`

**Step 1: Create original test fixtures and failing tests**

Use a tiny generated test atlas committed under `Tests`, not a community pet.
Verify `CODEX_HOME` precedence, default `~/.codex/pets`, invalid manifest
isolation, duplicate ID handling, and no writes to source pet directories.

**Step 2: Run tests**

Run: `swift test --filter PetLibraryTests`

Expected: FAIL.

**Step 3: Implement discovery and validation**

Accept the official manifest fields and require a local spritesheet whose width
is divisible by 8 and height by 9. Return library entries with validation status
instead of throwing away the whole scan when one pet is damaged.

**Step 4: Verify against the user's library without mutation**

Run: `swift run CodexHabitatApp --doctor-pets`

Expected on the reference machine: discovers the existing pet library and
prints counts only. Confirm `git status` remains clean and pet mtimes are
unchanged.

**Step 5: Commit**

```bash
git add Sources/PetRuntime Tests/PetRuntimeTests Sources/CodexHabitatApp/Diagnostics
git commit -m "feat: discover existing Codex pets"
```

### Task 8: Build the deterministic pet animation engine

**Files:**
- Create: `Sources/PetRuntime/Animation/PetAnimation.swift`
- Create: `Sources/PetRuntime/Animation/AnimationClock.swift`
- Create: `Sources/PetRuntime/Animation/PetAnimator.swift`
- Create: `Sources/PetRuntime/Rendering/PetRenderMode.swift`
- Test: `Tests/PetRuntimeTests/PetAnimatorTests.swift`

**Step 1: Write failing deterministic timing tests**

Test all official rows, frame wrapping, last-frame duration, state transitions,
idle fallback, success one-shot behavior, Reduce Motion behavior, and `auto`
versus `pixelated` rendering selection.

**Step 2: Run tests**

Run: `swift test --filter PetAnimatorTests`

Expected: FAIL.

**Step 3: Implement the animation state machine**

Inject a monotonic clock. Keep animation calculation independent from SwiftUI.
Map normalized Habitat activity to the supported pet states, and fall back to
idle when a row is unavailable.

**Step 4: Verify**

Run: `swift test --filter PetAnimatorTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/PetRuntime/Animation Sources/PetRuntime/Rendering Tests/PetRuntimeTests/PetAnimatorTests.swift
git commit -m "feat: add deterministic pet animation"
```

### Task 9: Implement the nonactivating AppKit overlay

**Files:**
- Create: `Sources/OverlayHost/Window/HabitatPanel.swift`
- Create: `Sources/OverlayHost/Window/OverlayController.swift`
- Create: `Sources/OverlayHost/Layout/DisplayGeometry.swift`
- Create: `Sources/OverlayHost/Layout/EdgeSnapper.swift`
- Test: `Tests/OverlayHostTests/DisplayGeometryTests.swift`
- Test: `Tests/OverlayHostTests/EdgeSnapperTests.swift`

**Step 1: Write failing layout tests**

Cover clamping, menu-bar/dock visible frames, display removal, scale-factor
changes, saved relative positions, and snapping on all four edges.

**Step 2: Run tests**

Run: `swift test --filter 'DisplayGeometryTests|EdgeSnapperTests'`

Expected: FAIL.

**Step 3: Implement the panel and controller**

Use a borderless nonactivating `NSPanel`, clear background, `.statusBar` level,
`canJoinAllSpaces`, and `fullScreenAuxiliary`. The panel must not become key or
main. Toggle `ignoresMouseEvents` for click-through and expose a bounded drag
region only while interactive.

**Step 4: Add a debug overlay preview**

Add `--preview-overlay` to the app executable. It renders a neutral placeholder
at a fixed logical size without requiring Codex.

**Step 5: Verify**

Run: `swift test --filter OverlayHostTests`

Expected: PASS.

Run: `swift run CodexHabitatApp --preview-overlay`

Expected: panel appears without activating the app, can move/snap, and click-
through toggles from the menu bar.

**Step 6: Commit**

```bash
git add Sources/OverlayHost Tests/OverlayHostTests Sources/CodexHabitatApp
git commit -m "feat: add native Habitat overlay panel"
```

### Task 10: Render pets in the overlay

**Files:**
- Create: `Sources/PetRuntime/Rendering/SpriteSheetRenderer.swift`
- Create: `Sources/CodexHabitatApp/Overlay/PetView.swift`
- Create: `Sources/CodexHabitatApp/Overlay/HabitatOverlayView.swift`
- Test: `Tests/PetRuntimeTests/SpriteSheetRendererTests.swift`
- Test: `Tests/CodexHabitatAppTests/HabitatOverlayModelTests.swift`

**Step 1: Write failing crop and render-model tests**

Verify exact frame rectangles, Retina scale independence, transparent padding,
invalid image fallback, and activity-to-frame updates.

**Step 2: Run tests**

Run: `swift test --filter 'SpriteSheetRendererTests|HabitatOverlayModelTests'`

Expected: FAIL.

**Step 3: Implement rendering**

Crop with Core Graphics using integral source pixels. Apply SwiftUI
interpolation `.none` for pixelated pets and `.high` for smooth pets. Keep a
stable overlay frame so animation never changes panel size.

**Step 4: Verify with an installed pet**

Run: `swift run CodexHabitatApp --preview-pet pika`

Expected on the reference machine: selected local pet animates, scales cleanly,
and never modifies its source directory.

**Step 5: Commit**

```bash
git add Sources/PetRuntime/Rendering Sources/CodexHabitatApp/Overlay Tests
git commit -m "feat: render animated pets in Habitat"
```

### Task 11: Add the built-in widget registry

**Files:**
- Create: `Sources/WidgetRuntime/Model/MetricValue.swift`
- Create: `Sources/WidgetRuntime/Model/WidgetDescriptor.swift`
- Create: `Sources/WidgetRuntime/Registry/WidgetRegistry.swift`
- Create: `Sources/WidgetRuntime/Widgets/StatusWidget.swift`
- Create: `Sources/WidgetRuntime/Widgets/UsageWidget.swift`
- Create: `Sources/WidgetRuntime/Widgets/ClockWidget.swift`
- Create: `Sources/WidgetRuntime/Widgets/PomodoroWidget.swift`
- Create: `Sources/CodexHabitatApp/Overlay/WidgetRailView.swift`
- Test: `Tests/WidgetRuntimeTests/WidgetRegistryTests.swift`
- Test: `Tests/WidgetRuntimeTests/PomodoroTests.swift`

**Step 1: Write failing registry and timer tests**

Verify the fixed five widget IDs, typed configuration rejection, unavailable
metric behavior, deterministic Pomodoro start/pause/reset, and restart restore.

**Step 2: Run tests**

Run: `swift test --filter WidgetRuntimeTests`

Expected: FAIL.

**Step 3: Implement the minimal registry and widgets**

Render compact, stable-size widgets using semantic tokens. Use symbols rather
than text buttons for timer controls, with tooltips and accessibility labels.

**Step 4: Verify**

Run: `swift test --filter WidgetRuntimeTests`

Expected: PASS.

Run: `swift run CodexHabitatApp --preview-overlay`

Expected: widget rail expands without resizing or moving the pet.

**Step 5: Commit**

```bash
git add Sources/WidgetRuntime Sources/CodexHabitatApp/Overlay Tests/WidgetRuntimeTests
git commit -m "feat: add compact Habitat widgets"
```

### Task 12: Build onboarding and the settings center

**Files:**
- Create: `Sources/CodexHabitatApp/App/HabitatAppModel.swift`
- Create: `Sources/CodexHabitatApp/Onboarding/OnboardingView.swift`
- Create: `Sources/CodexHabitatApp/Settings/SettingsRootView.swift`
- Create: `Sources/CodexHabitatApp/Settings/HabitatSettingsView.swift`
- Create: `Sources/CodexHabitatApp/Settings/PetsSettingsView.swift`
- Create: `Sources/CodexHabitatApp/Settings/WidgetsSettingsView.swift`
- Create: `Sources/CodexHabitatApp/Settings/ThemesSettingsView.swift`
- Create: `Sources/CodexHabitatApp/Settings/IntegrationsSettingsView.swift`
- Create: `Sources/CodexHabitatApp/Settings/PrivacySettingsView.swift`
- Test: `Tests/CodexHabitatAppTests/OnboardingModelTests.swift`
- Test: `Tests/CodexHabitatAppTests/SettingsModelTests.swift`

**Step 1: Write failing onboarding model tests**

Verify automatic pet discovery, default Workbench selection, optional widget
selection, three-step completion, no account requirement, and persistence.

**Step 2: Run tests**

Run: `swift test --filter 'OnboardingModelTests|SettingsModelTests'`

Expected: FAIL.

**Step 3: Implement the real settings experience**

Use a native sidebar and unframed settings sections. Repeated pet/theme previews
may use compact cards; do not nest cards. Use segmented controls, toggles,
sliders, and SF Symbol icon buttons according to the approved design.

**Step 4: Add accessibility identifiers and labels**

Cover every interactive control. Ensure the longest localized placeholder text
wraps and does not overlap at the minimum window size.

**Step 5: Verify**

Run: `swift test --filter CodexHabitatAppTests`

Expected: PASS.

Run: `swift run CodexHabitatApp`

Expected: onboarding completes and settings can reopen from the menu bar.

**Step 6: Commit**

```bash
git add Sources/CodexHabitatApp Tests/CodexHabitatAppTests
git commit -m "feat: add Habitat onboarding and settings"
```

## Milestone C: Portable Resource Packs

### Task 13: Define and validate `habitat.json`

**Files:**
- Create: `Sources/ResourceKit/Manifest/HabitatManifest.swift`
- Create: `Sources/ResourceKit/Manifest/ManifestDecoder.swift`
- Create: `Sources/ResourceKit/Validation/ManifestValidator.swift`
- Create: `Schemas/habitat-pack-v1.schema.json`
- Create: `Tests/ResourceKitTests/Fixtures/valid-pack/habitat.json`
- Create: `Tests/ResourceKitTests/Fixtures/invalid-packs/`
- Test: `Tests/ResourceKitTests/ManifestValidatorTests.swift`

**Step 1: Write failing schema tests**

Cover identity, semantic version, license, local paths, color tokens, relative
layout, registered widget IDs, numeric bounds, unknown fields, and minimum
runtime version.

**Step 2: Run tests**

Run: `swift test --filter ManifestValidatorTests`

Expected: FAIL.

**Step 3: Implement versioned manifest decoding**

Use explicit tagged enums for resource and widget types. Reject absolute paths,
URLs, CSS selectors, expressions, commands, and unregistered widget IDs.

**Step 4: Verify Swift and JSON schemas agree**

Add a test that validates all committed fixtures through both the Swift decoder
and the JSON schema fixture expectations.

Run: `swift test --filter ManifestValidatorTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/ResourceKit/Manifest Sources/ResourceKit/Validation Schemas Tests/ResourceKitTests
git commit -m "feat: define portable Habitat pack schema"
```

### Task 14: Add safe archive inspection and atomic installation

**Files:**
- Modify: `Package.swift`
- Create: `Sources/ResourceKit/Archive/ArchiveInspector.swift`
- Create: `Sources/ResourceKit/Archive/PackageLimits.swift`
- Create: `Sources/ResourceKit/Installation/PackageInstaller.swift`
- Test: `Tests/ResourceKitTests/ArchiveInspectorTests.swift`
- Test: `Tests/ResourceKitTests/PackageInstallerTests.swift`

**Step 1: Add ZIPFoundation with an exact reviewed version**

Record its MIT license in `THIRD_PARTY_NOTICES.md`. Do not add any executable
archive helper.

**Step 2: Write failing malicious-archive tests**

Programmatically create archives containing path traversal, absolute paths,
symlinks, duplicate normalized paths, executable extensions, HTML, remote font
references, excessive file count, excessive ratio, and excessive image size.

**Step 3: Run tests**

Run: `swift test --filter 'ArchiveInspectorTests|PackageInstallerTests'`

Expected: FAIL.

**Step 4: Implement bounded inspection and installation**

Inspect metadata before extraction. Extract to an app-owned temporary directory,
validate every declared asset and SHA-256, fsync important files, then atomically
rename into `Library`. Never follow symlinks and never overwrite an installed
version without an explicit user replacement decision.

**Step 5: Verify**

Run: `swift test --filter ResourceKitTests`

Expected: PASS.

**Step 6: Commit**

```bash
git add Package.swift Package.resolved THIRD_PARTY_NOTICES.md Sources/ResourceKit Tests/ResourceKitTests
git commit -m "feat: install Habitat packs atomically"
```

### Task 15: Add built-in themes and an original default pet

**Files:**
- Create: `Sources/CodexHabitatApp/Resources/Themes/workbench/`
- Create: `Sources/CodexHabitatApp/Resources/Themes/night-shift/`
- Create: `Sources/CodexHabitatApp/Resources/Themes/arcade-signal/`
- Create: `Sources/CodexHabitatApp/Resources/Themes/quiet-garden/`
- Create: `Sources/CodexHabitatApp/Resources/Pets/codie/`
- Create: `Tests/ResourceKitTests/BundledResourcesTests.swift`
- Create: `docs/asset-provenance.md`

**Step 1: Write a failing bundled-resource validation test**

The test loads every bundled manifest through the same validator used for
third-party packages and verifies unique IDs, previews, licenses, contrast token
pairs, and no remote assets.

**Step 2: Run the test**

Run: `swift test --filter BundledResourcesTests`

Expected: FAIL because resources do not exist.

**Step 3: Create the original pet with the Hatch Pet workflow**

Use the `@hatch-pet` skill during implementation. Produce original art, all
required animation rows, a transparent atlas, contact sheet, validation report,
and provenance record. Do not use copyrighted character art.

**Step 4: Build the four approved static themes**

Use semantic tokens and original local artwork only. Check light/dark contrast,
minimum overlay dimensions, long widget labels, and Reduce Motion variants.

**Step 5: Verify assets and rendering**

Run: `swift test --filter BundledResourcesTests`

Expected: PASS.

Run each theme through the preview command and capture reference screenshots to
`Tests/VisualReferences/`.

**Step 6: Commit**

```bash
git add Sources/CodexHabitatApp/Resources Tests/ResourceKitTests Tests/VisualReferences docs/asset-provenance.md
git commit -m "feat: add original Habitat themes and pet"
```

### Task 16: Integrate the Petdex catalog safely

**Files:**
- Create: `Sources/ResourceKit/Marketplace/PetdexClient.swift`
- Create: `Sources/ResourceKit/Marketplace/MarketplacePet.swift`
- Create: `Sources/CodexHabitatApp/Settings/PetMarketplaceView.swift`
- Test: `Tests/ResourceKitTests/PetdexClientTests.swift`
- Create: `Tests/ResourceKitTests/Fixtures/petdex-manifest.json`

**Step 1: Write failing HTTP-client tests**

Use `URLProtocol` stubs. Verify HTTPS-only requests, allowed host, timeout,
response size, manifest decoding, hash mismatch, content-ID mismatch, license
display, offline state, and cancellation.

**Step 2: Run tests**

Run: `swift test --filter PetdexClientTests`

Expected: FAIL.

**Step 3: Implement browse and explicit install**

Browsing is opt-in. Download metadata first, display author/license/source, then
require user confirmation before downloading the package. Pass every download
through `PackageInstaller`; never trust catalog metadata alone.

**Step 4: Verify**

Run: `swift test --filter PetdexClientTests`

Expected: PASS.

Test offline in the app: existing pets and themes remain fully usable.

**Step 5: Commit**

```bash
git add Sources/ResourceKit/Marketplace Sources/CodexHabitatApp/Settings/PetMarketplaceView.swift Tests/ResourceKitTests
git commit -m "feat: browse Petdex with verified installs"
```

## Milestone D: Optional Theme Bridge and Distribution

### Task 17: Verify the Codex app and own the theme session lifecycle

**Files:**
- Create: `Sources/CodexHabitatThemeBridge/Codex/CodexBundleVerifier.swift`
- Create: `Sources/CodexHabitatThemeBridge/Codex/CodexProcessInspector.swift`
- Create: `Sources/CodexHabitatThemeBridge/Session/ThemeSession.swift`
- Create: `Sources/CodexHabitatThemeBridge/Session/SessionRecord.swift`
- Test: `Tests/CodexHabitatThemeBridgeTests/CodexBundleVerifierTests.swift`
- Test: `Tests/CodexHabitatThemeBridgeTests/ThemeSessionTests.swift`

**Step 1: Write failing identity and lifecycle tests**

Use injected command runners and fixture metadata. Verify Bundle ID, Team ID,
strict code signature, architecture, executable path, loopback-only ports,
process ancestry, PID reuse defense, session record permissions, and refusal to
stop an unrelated process.

**Step 2: Run tests**

Run: `swift test --filter CodexHabitatThemeBridgeTests`

Expected: FAIL.

**Step 3: Implement verify/start/status/stop commands**

Use Security.framework and system process APIs. Do not modify the bundle. Start
the verified app with `--remote-debugging-address=127.0.0.1` and a selected
high port only after explicit authorization from the GUI. Persist exact process
identity and refuse ambiguous cleanup.

**Step 4: Verify against the installed app without injecting**

Run: `swift run CodexHabitatThemeBridge verify`

Expected on the reference machine: valid `com.openai.codex`/ChatGPT bundle,
OpenAI Team ID, architecture, and version; no app restart.

**Step 5: Commit**

```bash
git add Sources/CodexHabitatThemeBridge Tests/CodexHabitatThemeBridgeTests
git commit -m "feat: verify and isolate Codex theme sessions"
```

### Task 18: Add versioned CDP style injection and restoration

**Files:**
- Create: `Sources/CodexHabitatThemeBridge/CDP/CDPClient.swift`
- Create: `Sources/CodexHabitatThemeBridge/CDP/CDPTargetValidator.swift`
- Create: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Create: `Sources/CodexHabitatThemeBridge/Themes/CompatibilityProfile.swift`
- Create: `Sources/CodexHabitatThemeBridge/Resources/compatibility.json`
- Create: `Sources/CodexHabitatThemeBridge/Resources/codex-theme-template.css`
- Create: `Sources/CodexHabitatThemeBridge/Health/LayoutHealthCheck.swift`
- Test: `Tests/CodexHabitatThemeBridgeTests/CDPTargetValidatorTests.swift`
- Test: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`
- Test: `Tests/CodexHabitatThemeBridgeTests/LayoutHealthCheckTests.swift`

**Step 1: Write failing target, compiler, and health tests**

Reject non-loopback WebSockets, wrong ports, credentials, query strings,
non-`app://` pages, unknown Codex versions, remote asset URLs, `@import`, and
theme-provided selectors. Verify compiled CSS contains only approved token
values and local blob URLs.

**Step 2: Run tests**

Run: `swift test --filter CodexHabitatThemeBridgeTests`

Expected: FAIL.

**Step 3: Implement CDP and controlled compilation**

List targets from the verified loopback endpoint, validate the target, connect
with `URLSessionWebSocketTask`, and inject a host-owned style element. A theme
provides tokens and local art only. Compatibility profiles own all selectors.

**Step 4: Implement health checks and fail-closed restore**

Check sidebar, main surface, composer, pointer events, scrollability, popover
visibility, viewport bounds, and horizontal overflow. On failure remove the
style, stop the theme session, close the debugging port, and relaunch Codex
normally.

**Step 5: Run live verification with explicit user confirmation**

Run: `swift run CodexHabitatThemeBridge apply --theme workbench --screenshot /tmp/codex-habitat-theme.png`

Expected: health check PASS and screenshot shows native controls intact.

Run: `swift run CodexHabitatThemeBridge restore`

Expected: style absent, debugging port closed, normal Codex appearance restored.

**Step 6: Commit**

```bash
git add Sources/CodexHabitatThemeBridge Tests/CodexHabitatThemeBridgeTests
git commit -m "feat: add reversible Codex theme bridge"
```

### Task 19: Add diagnostics, privacy export, and recovery UI

**Files:**
- Create: `Sources/HabitatCore/Diagnostics/DiagnosticEvent.swift`
- Create: `Sources/HabitatCore/Diagnostics/DiagnosticStore.swift`
- Create: `Sources/HabitatCore/Diagnostics/DiagnosticExporter.swift`
- Create: `Sources/CodexHabitatApp/Settings/DiagnosticsView.swift`
- Test: `Tests/HabitatCoreTests/DiagnosticExporterTests.swift`

**Step 1: Write failing redaction and retention tests**

Verify seven-day rotation, restrictive permissions, path/user/thread/token
redaction, deterministic export contents, cache clearing, and official-
appearance recovery command presentation.

**Step 2: Run tests**

Run: `swift test --filter DiagnosticExporterTests`

Expected: FAIL.

**Step 3: Implement structured diagnostics**

Accept only module, stable error code, app/Codex versions, and timestamps. Do
not accept arbitrary raw strings from Codex payloads. Present connection test,
resource validation, restore, export, and clear actions in the Privacy view.

**Step 4: Verify**

Run: `swift test --filter DiagnosticExporterTests`

Expected: PASS.

Inspect an exported fixture and confirm it contains no home path or raw IDs.

**Step 5: Commit**

```bash
git add Sources/HabitatCore/Diagnostics Sources/CodexHabitatApp/Settings/DiagnosticsView.swift Tests/HabitatCoreTests
git commit -m "feat: add redacted diagnostics and recovery"
```

### Task 20: Package, sign, notarize, and update outside the App Store

**Files:**
- Modify: `Package.swift`
- Create: `Config/Info.plist`
- Create: `Config/CodexHabitat.entitlements`
- Create: `Config/ThemeBridge.entitlements`
- Create: `scripts/build-app.sh`
- Create: `scripts/package-dmg.sh`
- Create: `scripts/notarize.sh`
- Create: `scripts/verify-release.sh`
- Create: `docs/releasing.md`
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/release.yml`

**Step 1: Add Sparkle 2 and record its license**

Pin a reviewed Sparkle 2 release, enable EdDSA-signed update feeds, and keep the
updater disabled in debug builds. Do not add analytics.

**Step 2: Write release smoke checks first**

`scripts/verify-release.sh` must fail until the app bundle exists and then check
bundle IDs, version, architectures, hardened runtime, signatures, entitlements,
embedded helper identity, notarization ticket, and absence of development CDP
flags.

**Step 3: Build the `.app` bundle**

Assemble the SwiftPM release products into a standard app bundle, embed the
theme helper under `Contents/Helpers`, copy resources, and sign inside-out. Keep
Developer ID identity and notarization credentials in environment variables or
Keychain, never in the repository.

**Step 4: Package and notarize the DMG**

Sign the DMG, submit with `notarytool`, wait for acceptance, staple the ticket,
and verify with Gatekeeper.

**Step 5: Verify unsigned local and signed release paths**

Run: `scripts/build-app.sh --adhoc`

Expected: local app launches on the reference Mac.

Run in release credentials environment: `scripts/package-dmg.sh && scripts/notarize.sh && scripts/verify-release.sh`

Expected: every signature/notarization check PASS.

**Step 6: Commit**

```bash
git add Package.swift Package.resolved THIRD_PARTY_NOTICES.md Config scripts docs/releasing.md .github
git commit -m "build: package notarized Codex Habitat releases"
```

### Task 21: Complete visual, performance, and recovery QA

**Files:**
- Create: `Tests/VisualReferences/README.md`
- Create: `Tests/PerformanceTests/HabitatPerformanceTests.swift`
- Create: `docs/qa/macos-v1-checklist.md`
- Create: `docs/qa/cdp-compatibility-matrix.md`
- Create: `README.md`
- Modify: `docs/asset-provenance.md`

**Step 1: Add measurable performance tests**

Test animation frame calculation, package scan of 100 fixtures, snapshot
publication, and idle timer cadence. Record thresholds without relying on wall-
clock assertions that are flaky in CI.

**Step 2: Run the full automated suite**

Run: `swift test`

Expected: all tests PASS.

Run: `swift build -c release`

Expected: build succeeds with no warnings.

Run: `scripts/verify-release.sh` against the ad-hoc app.

Expected: all non-notarization checks PASS; notarization checks explicitly SKIP
for ad-hoc mode.

**Step 3: Perform real-device visual QA**

Capture and inspect Workbench, Night Shift, Arcade Signal, and Quiet Garden in
light/dark modes at minimum and typical window sizes. Verify no overlap, clipped
text, blank sprites, layout shifts, or incoherent pointer regions.

**Step 4: Perform macOS behavior QA**

Complete the approved matrix: multiple displays/scales, Spaces, fullscreen,
sleep/wake, display disconnect, click-through, Reduce Motion, increased
contrast, Codex lifecycle, app-server reconnect, invalid packages, CDP crash,
and official-appearance restore.

**Step 5: Confirm privacy and uninstall behavior**

Inspect diagnostics, app support files, open ports, and process list. Remove the
app and its app-owned support directory; verify Codex threads and
`~/.codex/pets` are unchanged.

**Step 6: Update user documentation and commit**

README should lead with the actual app, installation, screenshots, privacy,
supported Codex versions, recovery, and resource-pack authoring links. Do not
present a marketing landing page in the app itself.

```bash
git add Tests docs README.md
git commit -m "docs: complete macOS v1 release evidence"
```

## Final Verification Gate

Run all commands from a clean checkout/worktree:

```bash
swift test
swift build -c release
scripts/build-app.sh --adhoc
scripts/verify-release.sh
git status --short
```

Expected:

- all tests pass;
- release build succeeds without warnings;
- the ad-hoc app bundle passes all applicable local checks;
- the worktree is clean;
- no Codex app bundle or `~/.codex/pets` file was modified.

For a public beta candidate, additionally run the Developer ID/notarization
pipeline and repeat the manual QA matrix against the exact stapled DMG artifact.
