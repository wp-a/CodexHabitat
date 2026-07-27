# Build 16 Reliability and Visual Hierarchy Design

## Status

Approved on 2026-07-27. This increment follows the completed Build 15 work and
addresses the remaining interaction stalls, ambiguous theme actions, native
layout imbalance, and the visual gap between the Habitat preview and the
compiler-owned Codex shell.

## Objective

Make Habitat feel immediate and dependable before adding more decoration. The
application must show its settings window without waiting for an external
helper, pet clicks and drags must remain responsive during panel animation, and
theme artwork must decode without serializing the whole gallery. Once those
contracts are reliable, refine the native library and editor and give all
twenty-four themes the same precise shell language with genuinely different
family details.

This increment does not generate new artwork, change the theme package safety
model, or broaden access to Codex. It improves presentation of the existing
twenty-four original bitmap backgrounds and the host-owned UI surrounding them.

## Safety Boundary

- Never invoke Theme Bridge `apply`, `start`, `watch`, `enable`, or `restore`
  during development or automated QA.
- Never quit, restart, modify, re-sign, or patch Codex, its bundle, preferences,
  configuration, or `app.asar`.
- Automated Codex theme QA uses only the offline fixture.
- Real CDP visual acceptance remains a user-performed manual step.
- Custom themes remain typed data. Imports cannot contain CSS, JavaScript,
  selectors, commands, URLs, executables, symbolic links, or undeclared files.

## Reliability Architecture

### Window launch and Bridge refresh

The settings window becomes visible after local model loading and binding. A
Bridge status refresh runs afterward in a cancellable task and publishes its
result without delaying the window. Helper commands used for status and verify
receive a short bounded timeout. Repeated refresh requests coalesce so only one
process is in flight and stale results cannot overwrite a newer generation.

The installed application may resume an already-authorized watcher after the
bounded refresh. Test and visual-QA launch modes never start a live watcher.

### Pet pointer ownership

The AppKit drag region continues to own click-versus-drag intent. A normal
external panel resize invalidates the current pointer sequence, but an internal
expansion animation explicitly preserves it. Starting a drag cancels the
remaining expansion frames and keeps the current right edge authoritative.
Later animation frames cannot pull the panel back toward a stale captured edge.

The visible NSPanel frame remains approximately 136 x 144 collapsed and 324 x
144 expanded at 100 percent scale. There is no transparent hit-test rail.

### Pet renderer identity

`PetSpriteNSView` rebuilds its animation driver when renderer identity,
available animation rows, clock, or Reduce Motion mode changes. Reusing an old
driver is allowed only when all inputs that determine playback are unchanged.

### Preview revision and concurrency

Pet and theme thumbnail task identities include the resource URL, requested
pixel size, file modification revision, and atlas layout where applicable.
Replacing a file in place therefore invalidates the displayed image without a
view restart.

Theme decoding follows the pet thumbnail model: decode work happens outside the
actor, identical requests share one in-flight task, and different resources can
decode concurrently. The previous successful preview stays visible while a new
selection loads.

## Native Habitat Visual Hierarchy

### System-owned interaction color

macOS system tint owns controls, keyboard focus, selection, and destructive or
semantic command states. A selected theme's accent is restricted to artwork,
palette swatches, preview chrome, and theme-specific badges. It no longer
recolors every native control. Prominent text and controls must meet at least
4.5:1 contrast, and every slider receives a persistent accessible label and
value.

### Theme library

The gallery fills available width with an adaptive two- or three-column grid.
The inspector stays near 316 points and does not leave a large unused content
area. Card selection remains a reversible preview action and never applies a
theme.

Two explicit commands remove the current ambiguity:

- **Use in Habitat** changes the local Habitat appearance only and never calls
  the Bridge.
- **Apply to Codex** uses the existing authorized Bridge flow and remains
  visually and semantically separate.

Active-in-Habitat, active-in-Codex, previewed, applying, failed, unsupported,
and restorable states are presented independently.

### Theme Studio

The empty artwork canvas is a real import target instead of a decorative blank.
Inspector controls use persistent field labels. Save and Export are disabled
until the minimum draft contract is satisfied; detailed validation still runs
before any destination chooser. Undo and Redo remain in the toolbar. A sheet
uses one Cancel command in its footer rather than a second close icon.

### Compact overview and pet library

Overview actions wrap or choose a compact arrangement instead of clipping at
the minimum window width. Pet selection feedback is immediate and image loading
does not block navigation. Hover and press effects never alter layout geometry.

## Shared Theme Family Recipe

Move the family treatment contract into `HabitatCore` so the SwiftUI preview and
the static CSS compiler consume the same values. The recipe is deliberately
limited to surfaces the host can own safely:

- header boundary and material rhythm;
- action-card radius, edge, and selected marker;
- reading-surface radius and boundary treatment;
- composer radius, edge, and shadow strength;
- focus and hover emphasis;
- density and decorative rail rhythm that does not move host geometry.

Preview-only geometry such as fake sidebar fractions or stage offsets is not a
family differentiator unless the compiler can implement the same effect
without changing Codex-owned layout. Sidebar width, home content position,
composer position, and route geometry remain owned by Codex.

The nine families preserve their established identities: arcade, retro
messenger, green chat, classic desktop, game cinematic, cozy world, anime
energy, fantasy adventure, and pixel world. Differences come from boundary,
material, selection, focus, density, and shadow behavior rather than arbitrary
repositioning.

Text uses at most one short readability shadow. Stronger separation comes from
the route scrim and reading material. Offline QA must achieve at least 5:1 for
normal text and 4.5:1 for controls across all twenty-four themes.

## Verification

Each implementation task follows RED, GREEN, focused verification, and an
atomic commit. Final verification includes:

- all Swift tests, excluding the two user-owned temporary snapshot sources;
- offline Codex fixtures for all 24 themes, routes, crops, and interaction
  states with zero external requests and zero horizontal overflow;
- original-pixel native screenshots at compact and wide sizes in English and
  Simplified Chinese;
- accessibility, Reduce Motion, Reduce Transparency, and Increase Contrast
  checks where supported by deterministic tests or isolated Habitat QA;
- ad-hoc application build, `verify-release`, DMG creation and mounted-volume
  inspection;
- a final read-only code review.

No automated verification result is described as real CDP acceptance.
