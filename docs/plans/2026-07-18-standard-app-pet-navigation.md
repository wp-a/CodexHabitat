# Standard App Launch and Responsive Pet Navigation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Codex Habitat a normally visible macOS application while keeping login launches quiet, and make the Settings -> Pets transition responsive without SwiftUI publication warnings.

**Architecture:** Detect login-item launches from the documented Apple-event marker and derive a small launch presentation policy before opening the existing settings window. Keep settings navigation in local SwiftUI state. Move pet thumbnail decoding out of view layout into an actor-backed cache that uses a new single-frame sprite decoder.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, CoreGraphics/ImageIO, ServiceManagement, Swift Testing, bash release scripts.

---

### Task 1: Add single-frame sprite decoding

**Files:**
- Modify: `Sources/PetRuntime/Rendering/SpriteSheetRenderer.swift`
- Modify: `Tests/PetRuntimeTests/SpriteSheetRendererTests.swift`

**Step 1: Write the failing test**

Add `singleFrameLoadingReturnsOnlyTheRequestedNormalizedCell()` using the
existing synthetic atlas image fixture. Call the wished-for API:

```swift
let frame = SpriteSheetRenderer.frame(
    contentsOf: imageURL,
    atlas: atlas,
    row: 0,
    column: 1
)
#expect(frame?.width == atlas.cellWidth)
#expect(frame?.height == atlas.cellHeight)
#expect(firstPixel(in: try #require(frame)) == expectedSecondCellPixel)
```

Also assert that invalid row/column values and mismatched image dimensions
return `nil`.

**Step 2: Run the test to verify RED**

Run:

```bash
swift test --filter singleFrameLoadingReturnsOnlyTheRequestedNormalizedCell
```

Expected: compilation fails because the static single-frame API does not exist.

**Step 3: Implement the minimal decoder**

Add this public API to `SpriteSheetRenderer`:

```swift
public static func frame(
    contentsOf url: URL,
    atlas: PetAtlasMetadata,
    row: Int,
    column: Int
) -> CGImage?
```

Load one source image with ImageIO, validate atlas dimensions and indices, crop
only the requested cell, and normalize it into an RGBA `CGContext`. Extract a
private `normalizedFrame(image:rect:atlas:)` helper and reuse it from
`precroppedFrames` so animation behavior stays unchanged.

**Step 4: Run GREEN and related tests**

Run:

```bash
swift test --filter 'SpriteSheetRendererTests|PetAnimatorTests'
```

Expected: all selected tests pass.

**Step 5: Commit**

```bash
git add Sources/PetRuntime/Rendering/SpriteSheetRenderer.swift Tests/PetRuntimeTests/SpriteSheetRendererTests.swift
git commit -m "perf: decode pet thumbnails as single frames"
```

### Task 2: Cache thumbnails and isolate settings navigation state

**Files:**
- Modify: `Sources/CodexHabitatApp/Settings/PetsSettingsView.swift`
- Modify: `Sources/CodexHabitatApp/Settings/SettingsRootView.swift`
- Modify: `Sources/CodexHabitatApp/App/HabitatAppModel.swift`
- Create: `Tests/CodexHabitatAppTests/PetThumbnailStoreTests.swift`
- Modify: `Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift`

**Step 1: Write failing thumbnail-cache tests**

Create `PetThumbnailStoreTests.swift`. Construct one `PetLibraryEntry`, inject a
counting loader that returns a tiny real `CGImage`, request the same entry twice,
and assert both images exist while the loader ran once. Add a second test proving
an invalid result is cached as missing instead of retried during layout.

Wished-for API:

```swift
let store = PetThumbnailStore(loader: countingLoader)
_ = await store.image(for: pet)
_ = await store.image(for: pet)
#expect(counter.value == 1)
```

**Step 2: Write the failing navigation-state test**

In `SettingsWindowControllerTests.swift`, set
`model.selectedSettingsSection = .integrations`, construct the wished-for
`SettingsNavigationState(model:)`, mutate its local selection to `.pets`, and
assert the application model remains `.integrations`.

**Step 3: Run RED**

Run:

```bash
swift test --filter 'PetThumbnailStoreTests|settingsNavigationUsesLocalSelectionState'
```

Expected: compilation fails because the store and local navigation state do not
exist.

**Step 4: Implement the actor cache and asynchronous view task**

Add internal `PetThumbnailStore` as an actor with a production `shared` instance,
a cache key derived from spritesheet URL plus atlas geometry, and a loader closure.
Production calls `SpriteSheetRenderer.frame(contentsOf:atlas:row:column:)` for
idle row 0, column 0. Cache both images and missing results.

Change `PetThumbnail` to hold `@State private var idleFrame: CGImage?`. Its body
must only render the state or placeholder. Attach:

```swift
.task(id: pet.packageURL) {
    idleFrame = await PetThumbnailStore.shared.image(for: pet)
}
```

No renderer construction or file I/O may remain in `body` or a computed property
read by `body`.

**Step 5: Implement local sidebar state**

Add a small value-type `SettingsNavigationState` initialized from the model.
Store it with `@State` in `SettingsRootView`. Bind both the `List` and detail
switch to this local state. Change `HabitatAppModel.selectedSettingsSection` from
`@Published` to a plain main-actor property; it remains the cold-launch deep-link
input only.

**Step 6: Run GREEN and settings tests**

Run:

```bash
swift test --filter 'PetThumbnailStoreTests|SettingsWindowControllerTests|BundledResourcesTests'
```

Expected: all selected tests pass.

**Step 7: Commit**

```bash
git add Sources/CodexHabitatApp/Settings/PetsSettingsView.swift Sources/CodexHabitatApp/Settings/SettingsRootView.swift Sources/CodexHabitatApp/App/HabitatAppModel.swift Tests/CodexHabitatAppTests/PetThumbnailStoreTests.swift Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift
git commit -m "fix: make pet settings navigation responsive"
```

### Task 3: Make user launches visible and login launches quiet

**Files:**
- Modify: `Config/Info.plist`
- Modify: `Sources/CodexHabitatApp/CodexHabitatApp.swift`
- Modify: `Sources/CodexHabitatApp/App/HabitatSettingsWindowController.swift`
- Modify: `Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift`
- Modify: `scripts/build-app.sh`

**Step 1: Write failing launch-context tests**

In `SettingsWindowControllerTests.swift`, create a `kAEOpenApplication`
`NSAppleEventDescriptor`, attach `keyAELaunchedAsLogInItem`, and assert the
wished-for `HabitatLaunchContext(event:)` detects it. Assert an event without the
key is a normal launch.

Add table tests for the wished-for launch policy:

```swift
#expect(HabitatLaunchPresentation.shouldShowSettings(
    launchedAsLoginItem: false,
    requiresOnboarding: false,
    arguments: ["CodexHabitatApp"]
))
#expect(!HabitatLaunchPresentation.shouldShowSettings(
    launchedAsLoginItem: true,
    requiresOnboarding: false,
    arguments: ["CodexHabitatApp"]
))
```

Verify incomplete onboarding and `--show-settings` override a login launch.
Update the activation-policy test to require `.accessory -> .regular` promotion.

**Step 2: Run RED**

Run:

```bash
swift test --filter 'loginItemAppleEventIsDetected|userLaunchOpensSettingsWhileLoginLaunchStaysQuiet|settingsWindowPromotesAccessoryToRegular'
```

Expected: compilation or assertions fail because the launch types and regular
promotion do not exist.

**Step 3: Implement launch context and presentation policy**

Capture `NSAppleEventManager.shared().currentAppleEvent` during
`applicationWillFinishLaunching`. If it contains
`keyAELaunchedAsLogInItem`, set the application activation policy to `.accessory`
before async model loading.

After loading, open settings when the policy says the launch is user initiated,
onboarding is incomplete, or `--show-settings` is present. Preserve
`--show-settings-section` parsing. Update `HabitatSettingsWindowController` so
opening settings promotes `.prohibited` and `.accessory` to `.regular`.

**Step 4: Make the bundle a standard app and increment the build**

Remove `LSUIElement` from `Config/Info.plist`, change `CFBundleVersion` from 1 to
2, and change `scripts/build-app.sh` default `BUILD_NUMBER` from 1 to 2.

**Step 5: Run GREEN and the complete app test target**

Run:

```bash
swift test --filter 'SettingsWindowControllerTests|SettingsModelTests|OnboardingModelTests'
swift test --filter CodexHabitatAppTests
```

Expected: all selected tests pass.

**Step 6: Commit**

```bash
git add Config/Info.plist Sources/CodexHabitatApp/CodexHabitatApp.swift Sources/CodexHabitatApp/App/HabitatSettingsWindowController.swift Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift scripts/build-app.sh
git commit -m "feat: present Habitat as a standard macOS app"
```

### Task 4: Release, install, and native QA

**Files:**
- Modify: `docs/qa/macos-v1-checklist.md`

**Step 1: Run source verification**

Run:

```bash
swift test
git diff --check
```

Expected: the full suite passes with no diff errors.

**Step 2: Build and package without touching Codex**

Stop only the verified `CodexHabitatApp` process, then run:

```bash
scripts/build-app.sh --adhoc
scripts/package-dmg.sh
```

Never run theme live apply, restart Codex, or quit Codex.

**Step 3: Verify the final app and DMG**

Run `scripts/verify-release.sh`, strict/deep `codesign`, confirm bundle build 2
and absence of `LSUIElement`, mount the DMG read-only, rerun `verify-release`
against the mounted app, and record the final SHA-256.

**Step 4: Atomically install the verified app**

Copy the built app to a temporary bundle beside `/Applications/Codex Habitat.app`,
verify it there, move the old bundle to a temporary backup, rename the verified
bundle into place, then launch `/Applications/Codex Habitat.app`. Keep the backup
until the installed launch passes; remove it only after verification.

**Step 5: Perform native launch and navigation QA**

- Confirm a normal cold launch displays the settings window and a regular Dock
  application.
- Confirm the running executable path is `/Applications/Codex Habitat.app`.
- Measure **Integrations -> Pets** window-title transition; require less than
  500 ms on the current fixture.
- Revisit Pets several times and require no multi-second layout stall.
- Query logs from the new process start and require zero “Publishing changes
  from within view updates” and layout-recursion warnings.
- Capture the visible settings window and the Pets page with the screenshot skill.
- Do not claim a real CDP theme visual apply; leave it as a manual user step.

**Step 6: Update QA records and commit**

Update the test count, build number, installed-app checks, navigation latency,
and DMG SHA in `docs/qa/macos-v1-checklist.md`.

```bash
git add docs/qa/macos-v1-checklist.md
git commit -m "docs: record standard app release QA"
```

**Step 7: Read-only review and final verification**

Review the commits from the design base through `HEAD` for launch regressions,
main-thread I/O, cache invalidation, unsafe install behavior, and Codex boundary
violations. Rerun `swift test`, `verify-release`, mounted-DMG verification,
checksum, clean-worktree check, and installed-process/log checks before reporting
completion.
