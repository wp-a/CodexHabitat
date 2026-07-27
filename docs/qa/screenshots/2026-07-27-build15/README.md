# Build 15 Native QA - 2026-07-27

These screenshots were captured from the ad-hoc Build 15 app in `dist` on
macOS 26.4, arm64. Every process used isolated `CODEX_HOME` and
`CODEX_HABITAT_HOME` directories with settings schema 6 and
`themeBridgeEnabled` set to `false`. No theme was applied, imported, or saved,
and no Codex process was started, restarted, inspected, or modified.

- `gallery-zh-dark-wide-build15.png`: active 1040-point Simplified Chinese
  Themes window in dark appearance, with the selected theme preview and gallery
  visible without clipping.
- `theme-studio-zh-dark-build15.png`: active 900 x 672 Simplified Chinese Theme
  Studio sheet in dark appearance. No image was selected and no save or export
  action was taken.
- `pets-empty-zh-dark-compact-build15.png`: active 760-point Simplified Chinese
  Pets page in dark appearance, showing the empty-library state.
- `overlay-collapsed-zh-dark-build15.png`: visible pixels from the collapsed
  overlay. Window Server reported the physical panel as 136 x 144; the capture
  trims its transparent pixels.
- `overview-en-light-build15.png`: active 1040-point English Habitat overview in
  forced light appearance, covering the second localization and appearance
  combination.

All images were reviewed at original resolution. The settings windows showed no
truncated labels, blank previews, incoherent overlap, or unstable geometry. A
filtered unified-log scan found no SwiftUI publication, AttributeGraph-cycle,
layout-recursion, or main-thread warnings. All isolated Build 15 processes were
terminated after capture, and no `CodexHabitatThemeBridge` process remained.

These images validate Habitat's native localization, appearance handling,
gallery, editor, empty state, and overlay geometry. They do not validate live
styling inside Codex. Live CDP apply, Codex screenshot inspection,
official-appearance restore, and listener closure remain manual,
user-initiated acceptance steps.
