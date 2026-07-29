# Codex Theme Premium Material Redesign

**Date:** 2026-07-30
**Status:** Approved

## Goal

Rebuild the visual material system applied to the Codex main window so all 24 built-in themes feel like coherent, polished products instead of high-saturation skin swaps. Preserve each theme's original background, focal composition, palette identity, and host-owned `styleFamily` while replacing heavy dark cards, neon idle borders, and competing chrome with a restrained shared shell and family-specific details.

## Design Read

This is a strong visual redesign of a daily-work developer interface. It should feel refined, content-first, and quietly expressive, with an Apple-adjacent material discipline and the complete product composition seen in the user references. It must not become a decorative game launcher or reproduce a third-party interface.

- Design variance: 7/10
- Motion intensity: 2/10
- Visual density: 6/10

The reference screenshots inform hierarchy, rhythm, material restraint, and the relationship between imagery and controls. They are not sources for copied assets, proprietary names, people, logos, characters, interface text, or CSS.

## Current Problems

The current implementation uses theme accent colors too broadly. The same saturated value appears in selected rows, card borders, focus rings, composer treatment, and submit controls. Dark themes place nearly black rectangles over vivid artwork; light themes often wash the entire scene with pale overlays. Both patterns weaken depth and make the background and controls compete.

The home surface also treats four native actions as four equally heavy cards. This creates a generic skin-pack composition rather than a clear product hierarchy. Several families differ mainly through borders, radii, and accent mixtures even though they are represented as separate host-owned style families.

The latest complete offline render also fails its existing continuity assertion for `workbench/home/wide`: the sidebar background alpha is approximately `0.702`, outside the expected material hierarchy. The redesign must fix this underlying contract instead of adjusting screenshots around it.

## Chosen Approach

Use a semantic material reset with one shared premium shell, nine host-owned family recipes, and 24 theme-level art and palette calibrations.

This approach is preferred over 24 unrelated compositions because it keeps selectors bounded, behavior consistent, and future Codex compatibility manageable. It is preferred over incremental CSS polish because the current problem is structural: the same accent-driven material logic is repeated across every family.

## Architecture

The compiler remains the only source of injected styling. Resource packs continue to provide typed colors and bounded local bitmap art only; they cannot provide CSS, JavaScript, selectors, commands, or URLs.

The generated CSS is organized into three layers:

1. Shared semantic shell: stage, sidebar, header, content action, composer, popover, selection, focus, and submit materials.
2. Host-owned family recipe: restrained differences in material type, radius, divider treatment, selected-row shape, action structure, and composer edge treatment.
3. Theme calibration: background strength, focal point, scale, saturation, contrast, exposure, localized scrim, and one decorative accent.

Existing Codex DOM order, accessible names, keyboard behavior, controls, and route semantics remain unchanged. The compiler only styles allowlisted compatibility-profile selectors.

## Semantic Material Model

The redesign separates decorative color from structural hierarchy. Accent color no longer acts as a universal border.

The shared shell defines semantic values for:

- stage scrim;
- sidebar chrome;
- header chrome;
- content action fill;
- composer fill;
- popover fill;
- divider color;
- selected fill and selected indicator;
- focus ring;
- submit fill and foreground;
- ambient shadow and inner highlight.

Idle boundaries use neutral dividers derived from the panel and text colors. The accent appears only in selection, focus, active submit controls, and small family details. Error, warning, and success colors remain semantic and are not decorative theme accents.

## Background Composition

Each bitmap remains full-window visual context. Artwork is calibrated rather than replaced in this iteration.

Theme appearance gains bounded host-owned calibration values for saturation, contrast, exposure, and localized scrim strength. These values are optional in imported typed manifests and receive conservative defaults. The CSS uses a dedicated non-interactive art layer so image filtering does not alter native controls.

Home routes preserve more artwork. Task routes reduce contrast and saturation behind reading surfaces. The safe side receives a localized gradient or solid veil based on the art focal point; the entire window is not covered by one muddy tint. Sidebar, title bar, and lower composer visually belong to the same scene.

## Shared Shell

The sidebar is a stable navigation plane with either restrained translucency or an opaque fallback. It uses one subtle edge and no neon halo. The title bar is quieter than the sidebar and never becomes an unrelated strip.

The home heading is the primary content moment. Native action controls become lightweight interactive surfaces with a low-contrast fill, a single subtle edge, and clearer hover and pressed states. They must not read as four black slabs.

The composer is the strongest working surface. It uses a stable fill, restrained inner highlight, tinted ambient shadow, and a clear focus state. It does not use a permanent accent rail or glow. Popovers share the composer's material family at a slightly higher opacity.

Typography stays native to preserve Codex metrics and compatibility. Hierarchy comes from weight, spacing, contrast, and surface placement rather than custom fonts or oversized headings.

## Family Recipes

All nine recipes share the semantic shell but remain visually distinguishable:

- `retroMessenger`: pale blue glass, compact chrome rhythm, crisp selected bands, and fine highlight edges.
- `greenChat`: light message planes, restrained mint navigation tint, and compact pane divisions.
- `classicDesktop`: opaque neutral surfaces, crisp one-pixel boundaries, modest bevel cues, and minimal blur.
- `arcade`: smoked acrylic, compact geometry, and a small chromatic active edge without idle neon frames.
- `gameCinematic`: neutral charcoal scrims, broad calm surfaces, low-radius geometry, and image-led depth.
- `cozyWorld`: soft translucent material, generous but controlled radius, and warm or botanical tinting without beige dominance.
- `animeEnergy`: clean graphic planes, firmer selected indicators, and limited angular detail without protected characters or franchise motifs.
- `fantasyAdventure`: jewel-tinted glass, fine inner highlights, and slightly elevated composer material.
- `pixelWorld`: crisp modular spacing, low radius, and precise two-step depth without fake pixel fonts or heavy outlines.

No family may restore a permanent accent outline around all repeated actions. Differences must be expressed through material, geometry, spacing, and selected-state structure.

## Interaction

Motion remains restrained. Hover, pressed, focus, and selection feedback use 120-180 ms opacity, background, border-color, and small transform transitions. There are no perpetual animations. Reduced-motion mode removes transforms and shortens transitions.

Interactive state changes must not alter layout or pointer geometry. Native click targets and accessibility behavior remain owned by Codex.

## Error And Compatibility Behavior

- Missing art falls back to the calibrated palette and semantic shell.
- Unsupported art calibration fields are rejected by strict typed validation.
- Older custom packs receive deterministic conservative calibration defaults.
- Unsupported Codex versions continue to fail closed before injection.
- Reduced-transparency environments receive opaque material fallbacks.
- The fixture must fail when a required selector disappears or when hierarchy metrics fall outside bounded values.

## Testing And Visual Acceptance

Implementation follows RED to GREEN to commit.

Compiler tests will prove:

- semantic material tokens are emitted for all 24 themes;
- idle repeated actions do not use accent borders, outlines, or halos;
- all nine family recipes remain structurally distinct;
- art calibration values are bounded and safely encoded;
- custom manifests cannot introduce CSS, selectors, scripts, commands, or URLs;
- focus, hover, pressed, and reduced-motion states remain present;
- light and dark foreground contrast remains accessible.

The offline fixture will render all 24 themes across home and task routes at wide, narrow, and compact sizes, producing 144 scene images. Assertions will cover continuity, stage/sidebar/header/composer alpha, artwork visibility, text contrast, overflow, control geometry, and missing images. One representative light theme and one representative dark theme form the initial golden pair before the system expands to all themes.

Native screenshot QA may cover the Habitat theme gallery or previews if those surfaces change as a consequence of new calibration metadata. This design does not authorize applying a theme to a live Codex process, restarting Codex, quitting Codex, or modifying the official Codex bundle, configuration, or signature. Real CDP visual acceptance remains an explicit manual user step and will not be claimed as passed.

## Scope

In scope:

- shared Codex theme template and compiler materials;
- nine family recipes;
- 24 built-in theme appearance calibrations;
- strict typed manifest support where required;
- offline fixture contracts and regenerated visual QA artifacts;
- release verification affected by these changes.

Out of scope:

- changing Codex navigation, copy, DOM order, or behavior;
- regenerating all background artwork in this iteration;
- changing Habitat settings, theme library, Theme Studio, or pet interaction layouts;
- importing third-party CSS, injectors, screenshots, people, logos, characters, or protected IP;
- running live apply, watch, enable, restore, restart, or quit commands against Codex.
