# Theme Layout Continuity and Interaction Polish Design

**Date:** 2026-07-20
**Status:** Approved

## Goal

Make all twenty-four Codex themes feel visually balanced and responsive without displacing Codex's native workspace geometry. Background artwork must read as one continuous full-window scene across the title bar, task sidebar, and main surface, while native controls retain predictable placement and interaction.

The user-approved direction is global rather than theme-specific. A theme may change color, material, artwork, and bounded interaction feedback, but it must not push the Codex home workspace to one edge or narrow it enough to change the native action-card rhythm.

## Layout Contract

The Codex home content keeps its host-defined width, centering, wrapping, and responsive behavior. Habitat no longer applies `max-width`, asymmetric inline margins, translations, or other geometry to the complete home `[role="main"]` surface.

`safeSide` remains part of the strongly typed theme protocol, but its responsibility is limited to artwork focus and directional readability scrims. It must not reposition native content. This preserves the value of art-directed compositions without making the work surface appear crooked.

At narrow widths, Codex continues to own its own content margins and card wrapping. Habitat does not introduce a second width breakpoint for the complete home surface.

## Full-Window Scene Continuity

The host-owned scene layer remains fixed to the verified Codex app shell and spans the complete viewport. The task sidebar becomes a translucent themed wash rather than an opaque slab, so the same bitmap remains visible beneath it.

The sidebar treatment uses a bounded directional gradient:

- enough panel color near text and selected rows to preserve contrast;
- a softer inner edge toward the main surface so the image reads continuously;
- no backdrop blur on the large sidebar surface;
- no repeated or separately cropped sidebar image that could break scene continuity.

Task routes retain a somewhat stronger sidebar wash than the home route. The distinction is expressed through existing bounded opacity tokens and route selectors, not arbitrary theme-provided CSS.

## Visual Hierarchy

The theme compiler continues to own all styling. Themes may select only an allowlisted `styleFamily`; resource packs cannot provide CSS, JavaScript, selectors, event handlers, commands, or URLs.

The polished hierarchy includes:

- readable themed fills for home action cards, selected navigation, composer, and popovers;
- restrained borders and shadows derived from semantic theme tokens;
- a clear selected task row without hiding the scene beneath the sidebar;
- a composer that remains visually anchored without becoming an oversized opaque block;
- no nested decorative card shells or geometry changes to native controls.

The right-edge Habitat pet remains a separate overlay. It is not part of any Codex theme bitmap and is not bundled into theme assets.

### Reference Refinement

The user-provided `2009..png` is a composition and hierarchy reference only. Its useful qualities are the continuous window scene, quiet translucent sidebar, one coherent material language across navigation/actions/composer, stable centered work area, and immediately legible selected and interactive states.

Habitat will transfer those principles without copying the portrait, person, costume, ribbons, decorative marks, text, watermark, icons, brand treatment, or exact composition. Built-in artwork remains original, text-free, person-free, and free of recognizable third-party IP.

The refinement applies measured restraint rather than universal glassmorphism:

- home actions use a lighter theme-derived fill instead of an 80% opaque block;
- built-in composer opacity moves from the current 94-98% range to a theme-appropriate 84-90% range;
- selected navigation remains stronger than hover but still reveals the continuous scene;
- `gameCinematic` replaces thick attention-colored rails with a fine tinted boundary, inner highlight, and shorter shadow;
- other style families retain their distinct desktop, messenger, cozy, pixel, anime, arcade, and fantasy material cues.

Typography, wording, control order, and native Codex layout remain host-owned.

## Interaction Contract

Interaction polish is CSS-only and attaches to existing native actionable surfaces.

- Home actions receive distinct hover, pressed, and keyboard focus-visible feedback.
- Sidebar buttons and task rows receive hover and selected feedback that remains legible over the scene.
- The composer receives a bounded focus-within border/shadow treatment.
- Feedback uses color, border, opacity, and small compositor-only transforms where safe.
- Hover or press states must not change element dimensions or reflow the page.
- `prefers-reduced-motion: reduce` disables nonessential transitions and transforms.

Habitat does not synthesize clicks, replace controls, attach runtime event listeners, or change Codex command behavior.

## Compatibility and Failure Behavior

All selectors remain sourced from the narrow compatibility profile for the verified Codex version. Missing optional surface selectors omit the related enhancement. Unknown Codex versions continue to fail closed.

Layout health checks remain route-aware. The polish must not weaken sidebar, main-surface, header, composer, pointer, hit-test, scroll, annotation, viewport, or overflow checks for routes where those checks apply.

## Testing and Verification

Implementation follows RED to GREEN development.

Automated coverage will assert:

- generated CSS never overrides the complete home surface's width or inline margins;
- all twenty-four built-ins compile with a continuous app-shell scene and translucent sidebar wash;
- home and task sidebar treatments remain distinct and bounded;
- home actions expose hover, active, and focus-visible states without layout-changing properties;
- the composer exposes focus-within feedback;
- reduced-motion rules suppress nonessential motion;
- no theme resource gains CSS, JavaScript, selector, command, URL, or executable content.

Offline fixture rendering will cover all twenty-four themes on home and task routes at desktop and compact widths. Native screenshot QA will inspect Habitat's packaged gallery and confirmation flow. Live Codex visual acceptance remains user initiated: development verification will not run theme apply, restart Codex, quit Codex, or modify the official Codex bundle or configuration.

## Out of Scope

- Regenerating the twenty-four background bitmaps.
- Adding arbitrary per-theme layout offsets.
- Injecting JavaScript interactions into Codex.
- Styling or bundling the user's locally installed pet as theme artwork.
- Modifying the official Codex application, `app.asar`, preferences, signature, or installation.
