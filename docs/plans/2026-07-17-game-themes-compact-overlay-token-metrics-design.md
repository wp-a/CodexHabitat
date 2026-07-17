# Game Themes, Compact Overlay, and Token Metrics Design

**Date:** 2026-07-17
**Status:** Approved

## Goal

Make Codex Habitat visually distinctive enough to feel like a game companion rather than a monochrome utility, remove unused overlay space around the pet, and present Token metrics with labels that match what Codex actually reports.

The approved direction is a high-saturation game aesthetic. The product remains a quiet utility while the pet and theme surfaces carry the expressive visual identity.

## Research Findings

The current implementation has four built-in themes with five color tokens. Most deep-theme CSS remains a neutral surface; accent colors appear only on a few borders, buttons, focus states, and selections. The background preview is blended with `soft-light`, which further suppresses saturation.

The reference projects demonstrate a broader theme model:

- [Codex Dream Skin](https://github.com/Fei-Away/Codex-Dream-Skin) uses full-window bitmap art, separate panel colors, art focal points, safe areas, and route-specific scrims.
- [HeiGe Codex Skin Studio](https://github.com/HeiGeAi/heige-codex-skin-studio) ships multiple ready-to-switch image themes and derives a coordinated palette from each theme.
- [Codex ThemeScape Studio](https://github.com/2698686982-debug/Codex-Theme-Scape-Studio) demonstrates a larger theme gallery with multiple layout families and environmental treatments.

Habitat will adopt the useful structural ideas without importing their runtime code or redistributing third-party characters, celebrity imagery, screenshots, or other assets with unclear rights.

## Theme System

### Built-In Collection

Habitat will ship twelve built-in themes. The existing four IDs remain valid so saved settings do not break, but their palettes and art become more expressive. Eight new themes are added.

1. Workbench Turbo
2. Neon Night Shift
3. Arcade Overdrive
4. Pixel Meadow
5. Neon Drift
6. Solar Raid
7. Toxic Lab
8. Candy Combo
9. Crimson Mecha
10. Aurora Boss
11. Gold Rush
12. Aqua Pulse

Each theme gets original bitmap art, a real preview, and a palette containing:

- base surface;
- primary and alternate panels;
- primary text and muted text;
- accent, secondary, and highlight colors;
- attention and error colors;
- optional art focal point and safe side.

New palette fields are optional in the resource protocol. Older resource packs continue to decode with derived fallback colors.

### Visual Behavior

Codex home surfaces use the full background composition with a safe-side scrim so native headings and project controls remain readable. Conversation routes apply a stronger surface veil and reduce art contrast. Sidebar, composer, popovers, selected navigation, primary buttons, scrollbars, focus rings, and selections use the theme's distinct panel and accent tokens.

The current `soft-light` treatment is removed. Art remains visible through explicit bounded opacity and scrims. Decorations never accept pointer input and do not replace native Codex controls.

Habitat settings and the widget rail use the selected theme's tint, panel hierarchy, and preview art. The settings window does not become a game launcher dashboard; navigation and forms stay native and readable.

### Assets and Security

Built-in backgrounds are original generated or programmatic bitmap assets with recorded provenance. No recognizable third-party IP or real person is bundled. PNG, JPEG, and WebP data URLs are accepted only for host-owned built-ins, with MIME validation, decoded-size limits, and local-only loading. Resource packs still cannot provide CSS, JavaScript, selectors, or commands.

## Compact Pet Overlay

### Layout

The logical pet region changes from `160 x 180` to `136 x 144`. The widget rail becomes approximately `176 x 136`, and the expanded overlay becomes approximately `324 x 144` before user scaling.

- Collapsed: the actual panel is `136 x 144`.
- Expanded: the panel grows leftward to `324 x 144`.
- The pet stays anchored to the right edge during expansion and collapse.
- The panel's clickable, draggable, and snap geometry always matches the visible panel.
- The default five metric rows fit without clipping; optional extra widgets remain scrollable.

The overlay controller gains a bounded resize operation. Resizing preserves the right edge and saved display-relative placement. The SwiftUI root also changes its intrinsic layout instead of rendering a permanently expanded transparent canvas.

### Pet Rendering

Sprite aspect ratio remains unchanged. The renderer continues using integral source frames and the configured pixel/smooth interpolation mode. Pet scale applies inside the compact region, and clipping prevents the sprite from recreating invisible hit area outside the panel.

## Token Metric Semantics

Codex writes two different quantities in `token_count` events:

- `total_token_usage`: cumulative model input and output across the whole task. Repeated and cached context is counted again on later model calls, so long tasks can reach hundreds of millions.
- `last_token_usage`: the most recent model request. This represents the latest request, not the entire unique conversation.

The current widget displays `total_token_usage.total_tokens` as `Tokens`, which is technically sourced from Codex but misleading as a primary number.

The new presentation is:

- **Latest request**: `last_input_tokens + last_output_tokens`, shown as the default Token value.
- **Context**: `last_input_tokens / model_context_window`, unchanged and clamped to 0-100%.
- **Recent output**: cumulative output-token delta over the last 60 seconds, renamed from `Output speed` because JSONL events do not expose true streaming throughput.
- **Task cumulative**: `total_token_usage.total_tokens`, retained in help/detail text rather than the main compact value.

No estimate is substituted when a field is missing. Parallel tasks remain isolated through the salted active-thread ID and matching session filename.

## Error and Compatibility Behavior

- Missing theme art falls back to the palette without a blank placeholder image.
- Invalid extended palette fields fail resource validation; omitted fields derive deterministic safe fallbacks.
- Unknown Codex versions continue to fail closed before CDP injection.
- Collapsing or resizing never changes the user's saved scale, lock, click-through, or display placement settings.
- Missing or stale Token events show `--` and an unavailable accessibility value.

## Testing and Verification

Implementation follows test-first development.

Automated coverage will include:

- twelve unique built-in IDs, palettes, previews, and art assets;
- backward-compatible resource decoding and rejection of invalid extended colors or image data;
- compiled theme CSS using panel, secondary, highlight, safe-side, and route scrim tokens;
- compact collapsed and expanded geometry;
- overlay resizing that preserves the right edge and updates drag/snap bounds;
- latest-request, task-cumulative, context, and recent-output metric presentation;
- English and Simplified Chinese labels for all new theme and metric text.

Visual QA will capture the packaged Habitat theme gallery, expanded overlay, and truly collapsed pet-only window at Retina scale. It will check high saturation, contrast, clipped text, pointer geometry, and pet framing. Development QA will not invoke the live CDP apply action or restart Codex. Live Codex theme application remains an explicit user-initiated acceptance step in the packaged app.

## Out of Scope

- Bundling third-party game, anime, celebrity, or copyrighted character art.
- Importing arbitrary third-party theme scripts or CSS.
- Claiming JSONL-derived recent output as true model generation speed.
- A public theme marketplace in this release.
- Automatic Codex restart during development verification.
