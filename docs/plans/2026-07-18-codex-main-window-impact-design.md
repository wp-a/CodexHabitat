# Codex Main-Window Impact Design

**Date:** 2026-07-18
**Status:** Approved by continuation of the full-window direction

## Goal

Make the optional Codex appearance bridge produce a visually forceful, coherent
whole-window composition. The background must read as one continuous scene from
the left edge of the sidebar through the main surface, while native Codex content
remains usable on both the home and task routes.

The acceptance target is the Codex main window, not the Habitat gallery card or
the desktop pet overlay. Habitat previews remain useful, but they must represent
the same scene system rather than becoming the primary proof of quality.

## Evidence and Current Gaps

The current assets are not the main limitation. The four polished 2560 x 1440
backgrounds already reserve a low-information reading area and a high-information
focal area. The implementation suppresses that composition:

- built-in bridge themes resolve from `BuiltInThemeCatalog`, while the packaged
  `habitat.json` files contain a second copy of appearance data;
- twenty of twenty-four built-ins use the same resolved home, task, material,
  strength, opacity, and density defaults;
- all twenty-four built-ins use the same leading safe side, `0.42` background
  strength, and `0.88` panel opacity in their manifests;
- the task thread surface derives an approximately `80.68%` surface veil from a
  `0.42` background strength, hiding most of the image;
- the nine style-family recipes only change sidebar, composer, and popover
  borders, radii, and shadows;
- header, main, thread, home content, suggestion surfaces, task readability
  surfaces, and native fades share one generic treatment;
- several declared CSS variables are not consumed by the template, so some
  typed values do not materially alter the window;
- existing tests can report distinct styles because colors, base64 images, or a
  family-name comment differ even when the composition is structurally equal.

The useful structural lesson from `Fei-Away/Codex-Dream-Skin` commit
`3af1d6d62f3a0388cc640d2f497ac3100998938e` is not its CSS, selectors, presets,
or artwork. Its visual impact comes from one fixed full-window image, content
that moves into the low-information side of that image, route-specific surface
opacity, removal of host layers that would break the continuous scene, and a
near-solid composer over a more transparent home surface.

## Chosen Direction

Use a host-owned **scene plus skin** architecture.

- The scene owns art placement, scale, safe-side content placement, vignette,
  home/task visibility, and route-specific readability surfaces.
- The skin owns material, borders, highlights, selected navigation, controls,
  composer, popovers, scrollbars, and density.
- Theme packages continue to provide only typed enums, bounded numbers, local
  images, and palette tokens. They never provide CSS, selectors, commands,
  expressions, scripts, or URLs.
- Compatibility profiles remain the only source of Codex selectors.

This is preferred over a compiler-only opacity adjustment because it gives home
and task routes genuinely different compositions. It is preferred over
per-theme CSS because it keeps custom themes safe and prevents selectors from
entering resource packages.

## Whole-Window Scene

### One Art Canvas

Art is painted once on a profile-owned app-shell surface or a fixed decorative
pseudo-element spanning the entire viewport. The layer uses `cover`, a bounded
route-specific scale, a bounded focal point, no animation, and
`pointer-events: none`.

Sidebar, header, main, thread, and composer become material layers over that
single canvas. No route may paint separate copies of the image behind sidebar
and main. That avoids crop discontinuity and the visual seam visible in the
current implementation.

### Home Route

Home is background-first:

- art strength: normally 0.76 to 0.88;
- immersive header opacity: 0.00 to 0.28;
- sidebar opacity: normally 0.48 to 0.62;
- suggestion/home-card opacity: normally 0.52 to 0.66;
- composer opacity: normally 0.88 to 0.96;
- home content width: normally 46% to 58% of the main surface;
- home content is aligned opposite the focal area according to `safeSide`;
- the vignette protects window controls and content, not the full image.

`immersive`, `framed`, and `quiet` remain the stable home modes. Their meaning
becomes structural:

- `immersive`: one full-window canvas and a constrained safe-side content stage;
- `framed`: a large bounded scene inside the main surface for art that cannot
  survive a full-window crop;
- `quiet`: a low-strength canvas with a stronger unframed reading surface.

### Task Route

Task is readable without returning to a flat opaque app:

- art strength: normally 0.42 to 0.58 for ambient and banner scenes;
- task sidebar opacity: normally 0.68 to 0.80;
- task header opacity: normally 0.54 to 0.72;
- transcript/readability surface opacity: normally 0.62 to 0.76;
- composer opacity: normally 0.92 to 0.98;
- code, tool, popover, and destructive-action surfaces stay more opaque than
  ambient transcript chrome;
- task art placement and scale may differ from home to preserve the focal area.

`ambient`, `banner`, and `off` remain the stable task modes. `off` is reserved
for light or detailed themes that cannot retain readable task content.

### Host-Layer Cleanup

The compatibility profile may add only statically verified selectors for host
surfaces that interrupt the scene, such as sidebar resize chrome, top/bottom
thread fades, sticky search bands, home content, suggestions, task transcript,
and message/code/tool surfaces. The compiler can make those layers transparent
or material-backed only within the selected route and style scope.

No third-party selector is copied. New selectors must be derived from a
read-only extraction of the exact verified official Codex bundle and stored in
the narrow version profile. Unknown versions continue to fail closed.

## Typed Appearance Contract

Keep the existing scene enums and add only values that cannot be safely derived
from the current flat appearance:

- optional home and task focal points;
- bounded home and task art scale;
- bounded task sidebar and task header opacity;
- bounded home and task content opacity;
- bounded home content width;
- bounded vignette strength.

Legacy packs derive deterministic values from their existing focal point,
strength, panel opacity, mode, safe side, material, density, and style family.
Theme Studio exposes the new values in an advanced route-composition section.

The accepted bounds are intentionally narrow. They must prevent invisible
native controls, unreadable task content, oversized art, and excessive blur.

## Twenty-Four Built-In Themes

Every built-in theme receives an explicit treatment. None may rely on the
generic fallback.

The twenty-four definitions must cover multiple scene signatures across the
nine style families:

- dark cinematic themes use immersive home plus ambient or banner task;
- retro desktop themes use immersive or framed home with compact, route-aware
  chrome rather than the same modern glass recipe;
- light garden/chat themes use quiet or framed home with stronger text plates;
- arcade, anime-energy, and sports themes use asymmetric high-energy stages;
- fantasy, storybook, and pixel themes use their own border, selected-nav,
  transcript, and composer recipes.

`BuiltInThemeCatalog` becomes the single source of built-in appearance data.
Packaged manifests are generated from or checked exhaustively against it. A
change that only edits one copy must fail tests.

## Complete Skin Recipes

Each of the nine host-owned style-family recipes must cover:

- sidebar and selected navigation;
- header and route transition edge;
- main surface and home content stage;
- suggestion/action surfaces;
- task transcript and message/code/tool surfaces;
- composer and project/location selector;
- popovers and menus;
- primary, focus, selected, warning, and destructive states;
- scrollbars and native fades.

Recipes must remain materially distinct after comments, literal colors, and
theme-specific numbers are normalized. A unique family marker is not sufficient
evidence of a unique recipe.

Blur is limited to small chrome regions. The full-window canvas, transcript,
and large side surfaces prefer transparent colors and gradients so the theme
does not create constant expensive backdrop composition.

## Route and Runtime Behavior

The existing bounded route classifier remains content-blind. It may inspect
only profile-owned markers and set fixed host-owned route/surface attributes.
It must not read prompt, response, project, thread, account, file, or user text.

If stable styling requires surface annotations, the bridge may add fixed
`data-codex-habitat-surface` values to nodes selected by the compatibility
profile. Annotation must be idempotent, survive allowed DOM replacement within
the existing bounded update cadence, and be completely removed on restore.

The pre-injection gate, post-install health check, exact process ownership,
loopback-only listener, bootstrap cleanup, PID reuse protection, and official
restore path remain unchanged.

## Offline Codex Window Fixture

Native Habitat screenshots do not prove Codex main-window composition. Add a
strictly offline Chromium fixture that consumes the real resolver, compiler,
and route installer output.

The fixture:

- contains a fixed representative DOM for titlebar, sidebar, home content,
  suggestions, main header, transcript, messages, tool/code surfaces, composer,
  popover, and route marker;
- contains no official logo, screenshot, user data, third-party art, or copied
  Codex product text;
- blocks all network requests;
- uses the exact selectors from the selected compatibility profile;
- fails if required selector cardinality changes;
- renders at 1512 x 982, device scale factor 1, reduced motion, and a fixed
  locale;
- captures home and task for all twenty-four themes, with full-resolution
  review images for the four primary prototypes and contact sheets for the
  complete library;
- labels every image `OFFLINE THEME FIXTURE` and never presents it as live Codex
  acceptance.

The renderer records the compatibility profile, template, fixture, theme,
route, browser revision, viewport, commit, and SHA-256 fingerprints. It asserts
one installed style, correct route, no external requests, no console errors,
no horizontal overflow, working task scroll, composer hit testing, decodable
art, nonblank pixels, and minimum home/task and cross-theme image difference.

## Testing Strategy

Implementation follows RED to GREEN with atomic commits.

Required automated coverage includes:

- built-in catalog and packaged manifest equivalence for all resolved fields;
- twenty-four explicit non-default treatments;
- typed decoding, bounds, schema, and legacy fallback for new scene fields;
- profile-owned selectors for every newly styled surface;
- full-window canvas compilation on home and task routes;
- independent route focal point, scale, chrome, and content opacity;
- task transcript opacity low enough to preserve visible art but high enough for
  text contrast;
- style-family recipes that cover every required host surface and remain
  structurally distinct after normalization;
- route/surface annotation lifecycle, idempotence, bounded updates, and cleanup;
- fixture selector cardinality, layout, scrolling, hit testing, network block,
  screenshot pixels, and fingerprints;
- no regression in target validation, health gate, compact overlay, Theme
  Studio safety, localization, performance, or packaging.

Visual review covers at least 1512 x 982 and a narrower desktop viewport for
home and task. Review checks the continuous canvas, focal crop, content safe
area, sidebar hierarchy, selected navigation, title/header, suggestions,
transcript, code/tool surfaces, composer, popovers, and light/dark readability.

## Safety and Intellectual Property

- Do not apply a theme to Codex during development.
- Do not restart or quit Codex.
- Do not modify the official Codex bundle, `app.asar`, configuration,
  preferences, signature, or user data.
- Read-only bundle extraction is allowed only to verify versioned selectors.
- Dream Skin provides structural research only. Do not copy its CSS, JS,
  selectors, presets, text, screenshots, or assets.
- Do not use QQ, WeChat, Dragon Ball, or other protected names, logos,
  characters, silhouettes, costumes, props, dialogue, audio, or screenshots.
- Existing and new theme backgrounds remain original, text-free, and free of
  recognizable third-party IP, with provenance recorded.

## Acceptance

The implementation is accepted when:

1. all twenty-four themes compile to explicit whole-window home and task scenes;
2. each style family changes the complete host surface hierarchy, not only
   color or three local borders;
3. task content retains visible art without losing contrast or native control
   hit testing;
4. offline full-window screenshots show continuous composition and materially
   different theme families at both routes and viewports;
5. the complete Swift, fixture, build, verifier, signature, DMG mount, and
   read-only review gates pass;
6. Codex PID and start time remain unchanged, the bridge stays disabled, and no
   helper/session exists during development QA.

Real live CDP apply, live Codex screenshot review, restore, and listener closure
remain a manual user-approved acceptance step. Offline fixture evidence must
never be reported as proof that live Codex visual acceptance passed.

## Out of Scope

- replacing the original twenty-four background images unless a fixture proves
  a specific image cannot support its required crop;
- arbitrary per-theme CSS or external theme scripts;
- animation-heavy particles, parallax, video, audio, or decorative WebGL;
- changing native Codex information architecture, hiding controls, or replacing
  product copy;
- live apply or automatic Codex restart during this development task.
