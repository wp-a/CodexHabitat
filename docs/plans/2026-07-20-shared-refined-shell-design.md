# Shared Refined Shell Design

**Date:** 2026-07-20
**Status:** Approved

## Goal

Rebuild the host-owned Codex theme chrome with the refined, layered desktop language from the approved reference while preserving every theme's original background artwork, semantic palette, and `styleFamily` identity.

The reference contributes composition, material hierarchy, spacing rhythm, and quiet interaction emphasis only. It does not contribute people, logos, branded marks, text, protected icons, or copied decorative assets.

## Design Direction

All twenty-four themes share one polished Codex shell:

- the title bar, sidebar, main surface, and composer read as one continuous window scene;
- the sidebar is a translucent wash with one quiet boundary owner and a stronger but still restrained selected row;
- the home surface keeps Codex-owned centering and width while action cards use a light, theme-derived material;
- task routes use one stable reading surface, with code and message panels protected from high-frequency background detail;
- the composer has one visible outer shell, restrained shadow, and one clear focus treatment;
- idle borders are thin and low contrast; saturated 2px outlines are reserved for selected or keyboard-focused states.

Each `styleFamily` keeps a small set of host-owned signatures rather than a separate border system. Family differences may appear in accent pairings, corner treatment, inner highlight, pixel edge, or shadow character. No family may add geometry, move native content, or stack multiple competing boundaries on the same shared edge.

## Readability Contract

The compiler owns semantic foregrounds and bounded reading scrims. Background art remains visible around the work area, but core text, code, task controls, and composer content receive stable local contrast. Final fixture checks sample composited pixels rather than only comparing CSS color tokens.

The fixture contract expands to include:

- a sub-900px viewport;
- a dense bilingual sidebar with long and truncated task names;
- a title bar in the scene continuity assertions;
- center-line deltas for home content and composer relative to the main surface;
- final-pixel contrast checks for primary text, secondary text, selected navigation, action cards, task cards, code, and composer;
- idle, selected, keyboard-focus, and reduced-motion interaction states.

## Safety and Compatibility

The change remains limited to the typed theme compiler, host-owned template CSS, built-in appearance tokens, and offline fixture markup/tests. Resource packs remain data-only and cannot supply CSS, JavaScript, selectors, commands, or URLs. Unknown Codex versions continue to fail closed.

Development verification remains offline. It must not call helper `apply`, `start`, `watch`, or `restore`, quit or restart Codex, or modify the official Codex app, `app.asar`, configuration, signature, or preferences. Live acceptance of the packaged Build 14 remains user initiated after the active Build 12 session has been restored.

## Success Criteria

- all twenty-four themes compile with the shared refined shell and materially different family signatures;
- no complete home surface geometry override or shared-edge double owner remains;
- high-risk themes no longer show competing idle borders or background detail through core reading surfaces;
- light themes meet the bounded contrast contract in offline composited-pixel checks;
- expanded fixture coverage passes with no overflow, center drift, clipped controls, or unsafe source content;
- full tests, ad-hoc Build 14, release verification, DMG verification, and read-only review pass;
- live Codex visual acceptance remains explicitly pending user action.
