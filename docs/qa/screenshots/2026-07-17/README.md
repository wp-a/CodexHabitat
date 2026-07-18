# Native Visual QA - 2026-07-17

These captures were made from the ad-hoc `Codex Habitat.app` on macOS 26.4,
arm64, using the repository's gated `--visual-qa` view-state options and the
macOS screenshot workflow. Habitat used isolated `CODEX_HOME` and
`CODEX_HABITAT_HOME` roots with Reduced Motion and `themeBridgeEnabled=false`.
No `CodexHabitatThemeBridge` helper process existed during capture, and Codex
was not applied to, restarted, or quit.

## Gallery and Studio

- [`gallery-all.png`](gallery-all.png): all 24 bundled themes and selected state.
- [`gallery-nostalgia.png`](gallery-nostalgia.png): nostalgic desktop family, including Retro Messenger 2007 and Cyber Cafe Neon.
- [`gallery-anime.png`](gallery-anime.png): wide-layout Anime filter with three original environment themes.
- [`gallery-custom.png`](gallery-custom.png): Custom filter empty state.
- [`theme-studio-narrow.png`](theme-studio-narrow.png): complete 640 x 620 editor sheet over a 760-point settings parent.
- [`theme-studio-wide.png`](theme-studio-wide.png): the same editor over a 1040-point settings parent.

The settings window measured 760 x 604 at the narrow size and 1040 x 604 at
the wide size. Review at original resolution found readable labels, stable
selected states, intact previews, visible actions, and no incoherent overlap.

## Compact Overlay

- [`overlay-expanded.png`](overlay-expanded.png): visible content from the expanded 100% state.
- [`overlay-collapsed.png`](overlay-collapsed.png): visible content from the collapsed 100% state.
- [`overlay-scale-075.png`](overlay-scale-075.png): visible content from the 75% state.
- [`overlay-scale-150.png`](overlay-scale-150.png): visible content from the 150% state.

The pet-side marker is an original blue paw extracted from the repository's
deterministic visual fixture and assembled into a temporary QA-only animation
sheet. It is not a bundled pet and contains no character or third-party IP.
The collapsed capture contains only the pet region, confirming there is no
transparent widget rail left to intercept the mouse. Across the scale captures,
the compact Chinese Token labels remain visible without collision.
These PNG bounds reflect visible-content capture cropping, so exact physical
window dimensions are established by AppKit frame tests and runtime window
inspection rather than inferred from screenshot pixel dimensions.

Five post-warmup `top` samples averaged 0.58% CPU and approximately 54 MB for
the expanded overlay. The collapsed overlay averaged 0.42% CPU and
approximately 53 MB over five equivalent samples.

These screenshots validate Habitat's native UI only. They do not constitute a
live CDP visual acceptance test inside Codex.
