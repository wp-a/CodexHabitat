# Apple-Inspired Visual and Interaction Reconstruction Design

## Status

Approved on 2026-07-21. The user approved a simultaneous reconstruction of
the native Habitat application, pet interaction, and all twenty-four Codex
themes. Further visual decisions use the direction in this document without
requiring per-component approval.

## Objective

Raise Codex Habitat from a functional prototype to a cohesive native macOS
product. The result should feel responsive, spatially predictable, restrained,
and carefully finished while preserving the existing privacy, package, and
Codex compatibility boundaries.

The design is informed by the principles in Emil Kowalski's `apple-design`
skill, particularly immediate response, direct manipulation, interruptible
motion, spatial consistency, layered materials, accessibility, and deliberate
typography. Web-specific implementation examples are not copied. Habitat
translates those principles into SwiftUI, AppKit, and compiler-owned static CSS.

## Product Direction

### Stable native structure, restrained theme following

Habitat keeps one stable macOS information architecture. The selected theme may
change the tint, selection accent, preview artwork, and limited material glow,
but it must not recolor every surface or change control geometry. This makes the
application recognizable and readable regardless of the selected Codex theme.

Codex receives the stronger expression. Its twenty-four themes keep their own
artwork, palette, focal point, safe area, and route treatments while sharing a
precise, tested shell. Nine compiler-owned style families control meaningful
structural details rather than only color and radius.

### Useful additions only

This reconstruction may add only small capabilities that reduce work or make
state easier to understand:

- a compact Habitat status overview using state already held by the app;
- theme favorites and recently used ordering stored locally;
- side-by-side home/task theme preview modes;
- explicit selected, previewed, applying, active, failed, and restorable states;
- a focused pet preview with immediate selection feedback;
- undo and redo for the in-memory Theme Studio draft;
- direct focal-point manipulation in the local preview.

It does not add accounts, cloud sync, remote theme code, social features,
analytics, new Codex data access, or automated live visual acceptance.

## Visual System

### Tokens

Create native tokens for:

- spacing: 4, 8, 12, 16, 20, 24, and 32 points;
- control height: compact 28, standard 32, prominent 36;
- radius: 5 for small controls, 8 for cards and inspectors, 10 only for large
  continuous preview surfaces;
- typography: macOS system semantic styles with explicit hierarchy and no
  viewport-scaled type;
- material: sidebar, toolbar, content, inspector, popover, and focused control;
- motion: press, selection, navigation, panel, and reduced-motion equivalents;
- emphasis: quiet, normal, selected, focused, warning, destructive, and success.

The selected theme contributes an accent and secondary color. The design system
derives bounded selection and focus colors that continue to meet contrast
requirements. Background artwork never becomes a foreground control material.

### Material hierarchy

The sidebar is the heaviest structural material. Toolbars are lighter and float
over scroll content. Content pages use the standard window background with
limited grouping surfaces. Inspectors use one raised material. A translucent
surface must not be placed inside another translucent card.

Dividers are used for data boundaries. Soft scroll-edge treatments replace
unnecessary decorative divider lines under floating toolbars.

### Motion

- Press feedback begins on pointer down and does not wait for command completion.
- Navigation and ordinary selection use 160-220 ms non-bouncing transitions.
- The pet rail uses an interruptible spring around 0.32 seconds and preserves
  the panel's right edge.
- Hover, press, focus, and selection cannot change layout geometry.
- Large artwork does not pan or animate.
- Reduced Motion replaces movement with a short cross-fade.
- Reduced Transparency uses more opaque semantic surfaces without removing
  state feedback.
- Increased Contrast strengthens boundaries without increasing visual clutter.

## Native Habitat Application

### Settings shell

Keep a macOS navigation split view, but give it a stable minimum 1040 x 680
working layout with a bounded wide mode. The title bar owns only window chrome
and compact global status. The sidebar uses SF Symbols, concise labels, stable
row heights, clear hover, pressed, selected, and keyboard focus states.

Each detail page has a compact page header, optional status summary, and a
scrolling work area. Commands belong in a toolbar or next to the object they
affect. Pages should not start with oversized marketing-style headings.

### Habitat overview

The Habitat page becomes an operational overview rather than a stack of raw
settings. It presents existing state in three compact bands:

1. current Habitat visibility, selected pet, position lock, and widget rail;
2. Codex connection quality and sanitized metric availability;
3. selected theme, bridge compatibility, and restore availability.

The primary actions are Show/Hide Habitat, Lock/Unlock Position, and Open the
relevant detailed section. Advanced preferences remain below the overview.

### Theme library

The theme library uses a gallery and detail-inspector composition:

- the toolbar owns search, filters, favorites, import, create, and refresh;
- theme cards emphasize artwork and expose name, family, and active/favorite
  states without permanent rows of color dots;
- clicking a card only selects and previews it;
- the inspector shows a bounded Codex home/task preview, palette, family,
  compatibility, and explicit apply action;
- applying is never triggered by simple selection;
- recent and favorite filters are local metadata and do not change pack format;
- installed-pack maintenance is placed in a separate compact section.

Loading one preview must not block the grid. Failed thumbnails show a stable
placeholder and a retry affordance. The previously selected theme remains
visible while a new preview loads.

### Theme Studio

Theme Studio becomes a wide editor with a live canvas on the left and a native
inspector on the right. The canvas switches between home and task compositions.
The focal point is directly draggable within the image while keeping the exact
typed value visible in the inspector. Safe regions can be overlaid temporarily.

The inspector groups metadata, artwork, palette, scene, material, and packaging.
Advanced controls are disclosed progressively. Changes update an in-memory draft
immediately and support bounded undo/redo. Cancel discards the draft. Save and
export continue through the existing validated package builder.

No imported pack or image may contain CSS, JavaScript, selectors, commands,
URLs, executable data, symbolic links, or undeclared content.

### Pet library

The pet page uses a preview, resource list, and behavior inspector. Selecting a
pet updates the visible selection state immediately. Image decoding remains on
the existing actor-backed path. A pending pet keeps the previous renderer until
the replacement is ready. Failure produces an inline message and never blocks
navigation.

The zero-pet state is compact and offers the applicable Import and Petdex
actions. It does not consume the entire page with an oversized symbol.

### Desktop pet and widget rail

One AppKit-owned gesture path distinguishes click, drag, and context-menu intent.
SwiftUI content does not independently toggle expansion for the same pointer
sequence. Press feedback starts immediately. Drag begins only after a movement
threshold and keeps the original grab offset.

The collapsed panel remains approximately 136 x 144 and the expanded panel 324
x 144 at 100 percent scale. Expansion grows leftward from the pet and preserves
the right edge. The NSPanel frame changes with the visible content so no
transparent hit-test rail remains.

The widget rail keeps status, latest request tokens, context utilization,
recent 60-second output, and quota as compact useful information. It does not
add transcript, prompt, response, or command content.

## Codex Theme Shell

### Shared layers

Every compiled theme uses six stable layers:

1. one fixed artwork canvas spanning title bar, sidebar, main content, and the
   bottom edge;
2. a route-aware sidebar reading wash;
3. a lightweight title-bar material with no second artwork source;
4. a centered home action stage owned by Codex geometry;
5. a bounded task reading surface that preserves surrounding artwork;
6. a centered composer and correctly anchored popovers.

Theme CSS must not shift host-owned home content, composer geometry, or sidebar
width. Theme artwork and safe-side choices affect crop and scrims, not control
position. No theme may leave body, task rail, title bar, or bottom safe area with
an unrelated background.

### Family responsibilities

- `arcade`: compact console rhythm, paired signal lines, crisp neon states;
- `retroMessenger`: 2007 blue-glass title rhythm, narrow chrome, grouped panels,
  and restrained highlights;
- `greenChat`: green status rail, compact grouped navigation, flatter work area;
- `classicDesktop`: square corners, one-pixel separators, raised controls, and
  status-bar rhythm;
- `gameCinematic`: immersive scene, low-interference reading surface, thin
  luminous structural edge;
- `cozyWorld`: lighter material, calmer spacing, soft bounded shadow;
- `animeEnergy`: original graphic energy lines and high-contrast controls with
  no characters, names, costumes, props, silhouettes, or recognizable IP;
- `fantasyAdventure`: restrained etched borders, layered materials, subtle
  highlight hierarchy;
- `pixelWorld`: stepped corners, hard-edge shadows, pixel rhythm, and normal
  antialiased text.

Family rules cover header, stage, home actions, navigation, composer, popover,
reading surfaces, selected state, focus state, density, and boundary treatment.
Each surface has one owner for its outer boundary. Idle chrome remains quieter
than hover, selected, or focus feedback.

### Codex interaction behavior

The bridge emits only host-owned static CSS. Hover, active, focus-within, and
focus-visible feedback is immediate and limited to color, border, shadow,
opacity, and safe compositor transforms. Route changes may cross-fade artwork
and material tokens but never move functional controls. Reduced Motion removes
transitions while retaining semantic state differences.

## State and Data Flow

HabitatAppModel remains the source of truth for settings, available resources,
selected theme, selected pet, and bridge status. View-specific state stores
preview selection, filter, inspector visibility, favorites, recents, and editor
history. Expensive image work stays in actors and publishes immutable results on
the main actor.

Selecting a theme follows:

1. update local selection immediately;
2. request or reuse a cached preview asynchronously;
3. update recent metadata locally;
4. expose Apply only when the compatibility and bridge state allow it;
5. require the existing explicit confirmation before a first bridge start;
6. report applying, active, failure, and restore states without blocking the
   gallery.

No development or automated QA path invokes a live apply.

## Failure and Recovery

- Resource and preview failures are local to the affected row or preview.
- The previous valid pet or theme preview remains visible during replacement.
- Theme Studio validation points to the specific field and preserves the draft.
- Unknown Codex builds and selector gaps continue to fail closed.
- Layout-health failure restores the previous/official appearance through the
  existing bridge lifecycle; development tests use only mocks and fixtures.
- The user can always distinguish selected, previewed, active, and official
  appearance states.

## Verification Strategy

### Native application

- Swift tests for visual tokens, view-state reducers, favorites/recents,
  editor history, pet gesture arbitration, and accessibility preferences;
- focused tests proving selection and navigation are immediate and image work
  remains off the main actor;
- native screenshot QA at standard and bounded compact window sizes, light and
  dark appearance, Simplified Chinese and English, empty/loading/error/long-text
  states, and Reduced Motion/Transparency/Increase Contrast;
- runtime log review for SwiftUI publication, AttributeGraph, layout recursion,
  and main-thread stalls.

### Codex themes

- compiler tests for all 24 themes and all 9 families;
- offline Playwright rendering for home/task, wide/compact, interaction and
  accessibility states;
- geometry, coverage, contrast, hit-testing, overflow, and family-distinctness
  metrics;
- screenshot contact sheets and representative full-resolution review;
- no live Codex apply, restart, quit, or modification during development.

Real CDP visual acceptance remains a manual user step and cannot be reported as
passed by the implementation session.

### Release

Run the full Swift and visual suites, create an ad-hoc application, verify the
packaged executables and resources, package a DMG, mount it read-only, verify the
mounted application, inspect native screenshots, and perform a final read-only
code review. Developer ID signing and notarization are required only for a
public downloadable release.

## Implementation Order

1. design tokens and reusable native interaction primitives;
2. settings shell and useful Habitat overview;
3. theme gallery and inspector;
4. Theme Studio canvas and inspector;
5. pet library and unified overlay gesture path;
6. shared Codex shell and nine complete family treatments;
7. accessibility, localization, screenshot QA, packaging, and read-only review.

Each task follows RED, GREEN, focused verification, and an atomic commit.
