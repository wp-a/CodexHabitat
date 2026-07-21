# Build 14 Native QA - 2026-07-21

These screenshots were captured from the ad-hoc Build 14 app in `dist` on
macOS 26.4, arm64, with Simplified Chinese localization. Each process used
isolated `CODEX_HOME` and `CODEX_HABITAT_HOME` directories with
`themeBridgeEnabled` set to `false`. No theme was applied, imported, or saved,
and no Codex process was restarted or terminated.

- `gallery-all-build14.png`: 1152-point Themes window with all 24 packaged
  themes available, the first gallery row visible, and the second row beginning.
- `theme-studio-build14.png`: automatically opened 640 x 620 local Theme Studio
  sheet. No image was selected and no save/export action was taken.
- `pets-build14.png`: isolated 760-point Pets page with the empty-library state.
- `pet-collapsed-build14.png`: visible pixels from the collapsed overlay. The
  screenshot tool trims transparent pixels; Window Server reported the physical
  panel as 136 x 144.

The same isolated launch reported an expanded panel of 324 x 144. Both panels
ended at screen x=1488, confirming right-edge anchoring. The collapsed process
owned a 136-point-wide window, so no expanded transparent interaction rail
remained.

Codex retained PID `94302` and its `Mon Jul 20 22:15:10 2026` start time. The
pre-existing installed Habitat retained PID `98649` and its
`Mon Jul 20 15:03:31 2026` start time. No `CodexHabitatThemeBridge` process was
present before or after capture. The three isolated Build 14 processes were
terminated by their own test sessions after capture.

These images validate Habitat's native gallery, editor, and overlay geometry.
They do not validate live styling inside Codex. Live CDP apply, Codex screenshot
inspection, official-appearance restore, and listener closure remain manual,
user-initiated acceptance steps.
