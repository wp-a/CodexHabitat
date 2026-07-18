# Native Theme and Overlay QA - 2026-07-18

This directory contains the earlier polished-prototype captures from build 7
and final native QA from the installed ad-hoc Codex Habitat build 8 on macOS
26.4, arm64, with Simplified Chinese localization. Build 8 used its gated
`--visual-qa` options plus isolated `CODEX_HOME` and `CODEX_HABITAT_HOME`
directories. The overlay used the repository's original deterministic test pet
instead of reading user-installed pets. Its plain cyan cells are a geometry
fixture for window bounds and animation decoding, not a shipped pet or pet-art
quality evidence. `themeBridgeEnabled` was false, no
bridge session record or helper process existed, and Codex retained PID `23647`
and its original `Sat Jul 18 14:48:19 2026` start time throughout capture.

## Captures

- [`gallery-prototypes.png`](gallery-prototypes.png): 1152-point theme
  gallery showing the composed whole-window previews for Cathedral Foundry,
  Arcade Signal, Quiet Garden, and the beginning of the blue-glass Retro
  Messenger row. The visible Retina window content is 2304 x 1432; the complete
  PNG is 2528 x 1656 including the macOS capture margin and shadow.
- [`retro-framed-preview.png`](retro-framed-preview.png): 1108-point
  Nostalgia view showing Retro Messenger 2007 with artwork confined to the
  inset main pane beside its light grouped sidebar. The Retina capture is
  2440 x 1568 including the macOS capture margin and shadow, with 2216 x 1344
  of visible window content.
- [`theme-studio-route-controls.png`](theme-studio-route-controls.png): narrow
  760-point parent with the Studio scrolled to the typed style, density, safe
  side, home treatment, task treatment, and chrome material controls. The
  dynamic strength and opacity labels are localized in Simplified Chinese. The
  Retina capture is 1656 x 1480 including the sheet and shadow.
- [`gallery-all-build8.png`](gallery-all-build8.png),
  [`gallery-nostalgia-build8.png`](gallery-nostalgia-build8.png),
  [`gallery-anime-build8.png`](gallery-anime-build8.png), and
  [`gallery-custom-build8.png`](gallery-custom-build8.png): final Build 8 All,
  Nostalgia, Anime, and Custom filters at 1152 points.
- [`gallery-classic-build8.png`](gallery-classic-build8.png): final installed
  Build 8 Classic filter confirming the generic Chinese display name
  `经典桌面工作台` fits its native card without clipping.
- [`theme-studio-wide-sheet-build8.png`](theme-studio-wide-sheet-build8.png),
  [`theme-studio-narrow-sheet-build8.png`](theme-studio-narrow-sheet-build8.png),
  and [`theme-studio-route-controls-build8.png`](theme-studio-route-controls-build8.png):
  local-image-only Theme Studio at wide and narrow widths plus its typed advanced
  home/task route controls.
- [`pets-build8.png`](pets-build8.png),
  [`pet-expanded-build8.png`](pet-expanded-build8.png), and
  [`pet-collapsed-build8.png`](pet-collapsed-build8.png): isolated Pets UI and
  the exact 324 x 144 expanded and 136 x 144 collapsed physical windows at 100%.
- [`pet-expanded-scale-075-build8.png`](pet-expanded-scale-075-build8.png) and
  [`pet-expanded-scale-150-build8.png`](pet-expanded-scale-150-build8.png):
  75% and 150% physical overlay bounds, each still anchored to the right edge.

Original-resolution review found no blank assets, repeated bitmap, clipped
labels, overlap, unreadable controls, or poor focal crop. The wide gallery,
filtered views, and narrow Studio retained stable geometry. Themes -> Pets and
Pets -> Themes measured 305.6 ms and 306.1 ms including accessibility automation
overhead, without the previous multi-second stall. The final Habitat processes
emitted zero SwiftUI view-update, AttributeGraph-cycle, or layout-recursion
warnings during this QA run.

The Build 8 DMG mounted with both media and volume read-only, reported build 8
and `Codex Habitat 0.1.0`, and passed mounted release and strict signature
verification. Its SHA-256 is
`c964ef1729b40dbd6f05d1af631e1607f0ec8893efb6ca022de9769709eadd6a`.

Offline full-window Codex evidence for all 96 theme/route/viewport scenes is in
[`offline-codex-window/`](offline-codex-window/README.md).

These screenshots validate Habitat's native gallery and editor only. No theme
was applied to Codex, and live CDP visual acceptance remains a manual user step.
