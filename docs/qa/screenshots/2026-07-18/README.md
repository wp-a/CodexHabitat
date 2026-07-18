# Polished Theme Prototype QA - 2026-07-18

These captures were made from the installed ad-hoc Codex Habitat build 7 on
macOS 26.4, arm64, with Simplified Chinese localization. The app used its gated
`--visual-qa` options. `themeBridgeEnabled` was false, no bridge session record
or helper process existed, and Codex retained PID `23647` and its original
`Sat Jul 18 14:48:19 2026` start time throughout capture.

## Captures

- [`gallery-prototypes.png`](gallery-prototypes.png): wide 1040-point theme
  gallery showing the composed whole-window previews for Cathedral Foundry,
  Arcade Signal, Quiet Garden, and the beginning of the blue-glass Retro
  Messenger row. The Retina capture is 2216 x 1344 including the window shadow.
- [`retro-framed-preview.png`](retro-framed-preview.png): wide 1040-point
  Nostalgia view showing Retro Messenger 2007 with artwork confined to the
  inset main pane beside its light grouped sidebar. The Retina capture is
  2216 x 1344 including the window shadow.
- [`theme-studio-route-controls.png`](theme-studio-route-controls.png): narrow
  760-point parent with the Studio scrolled to the typed style, density, safe
  side, home treatment, task treatment, and chrome material controls. The
  dynamic strength and opacity labels are localized in Simplified Chinese. The
  Retina capture is 1656 x 1480 including the sheet and shadow.

Original-resolution review found no blank assets, repeated bitmap, clipped
labels, overlap, unreadable controls, or poor focal crop. The wide gallery,
framed Retro treatment, and narrow Studio retained stable geometry. The final
Habitat process emitted zero SwiftUI view-update, AttributeGraph-cycle, or
layout-recursion warnings during this QA run.

These screenshots validate Habitat's native gallery and editor only. No theme
was applied to Codex, and live CDP visual acceptance remains a manual user step.
