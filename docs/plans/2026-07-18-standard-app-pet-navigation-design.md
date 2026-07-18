# Standard App Launch and Responsive Pet Navigation Design

## Problem

Codex Habitat is packaged with `LSUIElement=true`, so macOS treats it as an
agent instead of a normal foreground application. A completed installation is
therefore absent from the Dock, and a cold user launch shows only the overlay
instead of the settings platform. An older `/Applications` copy can also be
preferred or forwarded to an already-running development copy because both
bundles currently share bundle ID and build number.

The settings sidebar has a separate performance defect. Selecting **Pets** can
leave the sidebar highlight on Pets while the detail remains on the previous
section for several seconds. A live sample captured the main thread spending
about 7.4 seconds in `LazyVGrid` measurement. During that measurement,
`PetThumbnail.body` was evaluated about 7,400 times; every evaluation created a
`SpriteSheetRenderer`, decoded the spritesheet, and pre-cropped every animation
frame. The `List` selection also writes directly to an `@Published` application
model property during SwiftUI view updates, producing runtime warnings.

## Launch Behavior

The main bundle becomes a standard macOS application by removing `LSUIElement`.
On a normal user launch, Habitat loads its model and opens the existing settings
window as the primary platform. The menu-bar control and desktop overlay remain
available.

At `applicationWillFinishLaunching`, the delegate inspects the current
`kAEOpenApplication` Apple event for `keyAELaunchedAsLogInItem`. The local macOS
SDK documents this key specifically for suppressing normal document or window
presentation during login-item launches. A login-item launch changes the app to
`.accessory` and does not open settings. Incomplete onboarding and explicit
`--show-settings` arguments override the quiet launch. Opening settings later
promotes `.accessory` or `.prohibited` to `.regular`.

The bundle build number increases from 1 to 2 so LaunchServices can distinguish
the corrected package from the existing installation. The marketing version
remains 0.1.0.

## Pet Navigation

`SettingsRootView` owns sidebar selection in local `@State`, initialized from
the application model only when the window is created. The `List` and detail
switch use that state, so a navigation click no longer publishes application
state during a SwiftUI update. Existing command-line deep links still select the
initial section before the settings window is created.

Pet thumbnails load through a small actor-backed cache keyed by the immutable
spritesheet URL and atlas geometry. The view body renders either a cached frame
or a stable placeholder. A view task asks the cache for the idle frame; decoding
and cropping occur off the main actor, and only one idle frame is retained per
pet. Layout measurement never performs file I/O or constructs a full animation
renderer.

The cache loader accepts an internal image-loading closure. Production uses a
single-frame ImageIO crop, while tests count loader calls to prove repeated
requests share one result. Invalid or changed resources fail to the existing
paw placeholder without blocking navigation.

## Safety and Packaging

The change does not invoke the theme bridge, apply a Codex theme, or restart or
quit Codex. Release verification continues to require the existing bundle IDs,
signatures, helper isolation, and 24 bounded theme packages.

After tests and ad-hoc release verification, Habitat itself may be stopped and
restarted. The verified build is copied to a temporary path in `/Applications`,
validated there, then atomically replaces the old Habitat bundle. The final DMG
is mounted read-only and verified before reporting completion.

## Verification

- Unit tests cover Apple-event login detection and launch presentation policy.
- Unit tests cover promotion from accessory to regular settings presentation.
- Unit tests prove thumbnail requests are cached and invalid resources return
  no image.
- A settings-window regression test verifies the initial navigation section is
  preserved without using the application model as the live List binding.
- Native QA measures **Integrations -> Pets** title transition latency, checks
  for zero SwiftUI publishing/layout-recursion warnings, and captures the normal
  launch window and Dock-visible process state.
- Full Swift tests, ad-hoc build, `verify-release`, strict signature checks, DMG
  mounting, and `/Applications` launch verification complete the release gate.
