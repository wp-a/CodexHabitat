# Dream Skin-Inspired Theme Prototypes Design

**Date:** 2026-07-18
**Status:** Approved for prototype implementation

## Goal

Prove that Codex Habitat can produce four materially different, polished theme
experiences in both the native Habitat gallery and the optional Codex bridge.
The prototypes must feel like complete window treatments rather than one shared
layout with different colors and cropped background images.

The work uses `Fei-Away/Codex-Dream-Skin` commit
`3af1d6d62f3a0388cc640d2f497ac3100998938e` as the primary structural reference.
Its MIT-licensed implementation was inspected in a temporary checkout. Habitat
will not copy its CSS, injectors, selectors, presets, screenshots, character
art, celebrity material, product copy, or other bundled assets. The useful
ideas are route-aware art strength, semantic safe areas, focal points, and
separate chrome surfaces.

## Scope

The prototype set keeps four stable built-in identifiers:

1. `workbench`: an original cathedral foundry with charcoal iron, aged brass,
   restrained warm light, and dark cinematic chrome.
2. `retro-messenger`: an original 2007 blue-glass communication workspace with
   compact spacing, pale content surfaces, and beveled translucent chrome.
3. `arcade-signal`: an original after-hours arcade environment with navy,
   magenta, cyan, and yellow light plus crisp high-energy controls.
4. `quiet-garden`: an original morning conservatory with daylight, living
   greens, frosted glass, and a calm light interface.

All four backgrounds are pure, continuous, text-free bitmap environments. They
contain no people, characters, portraits, logos, watermarks, copied UI,
trademarks, or recognizable franchise material. Backgrounds target 2560 x 1440
and must remain useful under 16:9, 16:10, and wide `cover` crops. The packaged
preview remains 800 x 500.

The remaining twenty built-in themes keep working through backward-compatible
defaults. They are not regenerated during this prototype pass. After the user
reviews the four prototypes, the accepted system can be applied to all twenty-
four themes without another schema redesign.

## Typed Appearance Model

`HabitatThemeAppearance` gains bounded, optional fields with deterministic
fallbacks for schema-v1 resource packs:

- `homeMode`: `immersive`, `framed`, or `quiet`;
- `taskMode`: `ambient`, `banner`, or `off`;
- `safeArea`: `leading`, `trailing`, `center`, or `none`;
- `homeStrength` and `taskStrength`;
- `sidebarOpacity`, `headerOpacity`, and `composerOpacity`;
- `chromeMaterial`: `solid`, `tinted`, or `glass`;
- existing focal point, blur radius, density, palette, and style family.

Existing `backgroundStrength`, `panelOpacity`, and `safeSide` values continue to
decode. They supply fallbacks when the new fields are absent. Numeric bounds
remain host-owned and are validated before a package can be published or sent
to the bridge. Theme packages still cannot contain CSS, JavaScript, selectors,
commands, expressions, fonts from remote locations, or URLs.

## Codex Bridge Rendering

The compatibility profile remains the sole source of Codex selectors. It adds
only the minimum host-verified markers needed to distinguish the home surface
from a task surface. Unknown Codex versions still fail closed.

The host CSS compiler creates a complete treatment from typed values:

- Home mode controls whether art fills the window, sits in a framed hero, or
  remains a quiet atmospheric layer.
- Task mode independently chooses ambient full-window art, a bounded top
  banner, or no task art.
- Safe area and focal point determine art positioning and the direction of the
  readability scrim.
- Sidebar, header, composer, thread, popovers, selected navigation, focus,
  scrollbars, and primary controls receive separate material and opacity rules.
- Style families provide complete chrome recipes, including shape, border,
  shadow, highlight, density, and surface behavior. They no longer differ only
  by a border declaration.

The bridge installer may maintain a host-owned route marker through a bounded
DOM observer. It may only inspect the allowlisted compatibility selectors and
set a fixed root attribute. It does not read prompt, response, thread, project,
or user content. Removing the style also removes the marker and observer.

The existing pre-injection health gate, post-install layout check, loopback-only
CDP restriction, exact-process ownership, and restore behavior remain required.
Development QA must not invoke live apply, restart Codex, or quit Codex.

## Habitat Gallery and Studio

The gallery card stops presenting a raw image crop as the entire theme preview.
A host-owned `ThemeTreatmentPreview` composes the same theme data into a small
window treatment: background, safe-area scrim, sidebar rail, content hierarchy,
and composer surface. It contains no copied Codex screenshot or protected UI.

The selected card remains clearly outlined and all existing filters, search,
import, export, and Theme Studio flows remain available. Preview decoding stays
off the main actor and cached.

Theme Studio exposes the new enum and bounded numeric controls. Imported themes
can select only host-owned treatments. Existing custom themes open with derived
defaults and can still be exported without arbitrary styling content.

## Prototype Visual Directions

### Workbench / Cathedral Foundry

- Dark immersive home, ambient task treatment.
- Leading safe area with the architectural focus on the right.
- Solid-to-tinted iron sidebar, compact brass rules, dark opaque composer.
- No characters, weapons, heraldry, religious symbols, or franchise motifs.

### Retro Messenger 2007

- Framed home, banner task treatment, compact density.
- Leading safe area with blue-glass architecture and pale central light.
- Glass sidebar and composer, one-pixel highlights, restrained bevels.
- No messenger logos, proprietary icons, contacts, portraits, or copied text.

### Arcade Signal

- Immersive home, banner task treatment.
- Leading safe area with luminous cabinet geometry on the right.
- Tinted navy chrome, crisp magenta/cyan focus states, yellow attention cues.
- No game logos, readable marquees, recognizable cabinets, or characters.

### Quiet Garden / Morning Conservatory

- Quiet home, task art off.
- Leading safe area with the greenhouse structure and foliage on the right.
- Light frosted sidebar, white-green composer, subtle natural shadows.
- No cottage-game replicas, characters, creatures, signs, or branded objects.

## Asset Workflow and Provenance

Use the approved image-generation workflow to create four original backgrounds.
Dream Skin screenshots and assets are never sent to the image model. Prompts
describe only abstract composition requirements learned from the structural
review. Each generation records model, endpoint class, prompt, date, raw output
location, normalized dimensions, byte size, and SHA-256.

Generated files are normalized without stretching. Every background and preview
is checked for dimensions, file type, decoded pixel count, package size, text,
logos, people, characters, and obvious third-party resemblance. Failed assets
are discarded rather than patched from protected source material.

## Testing and Acceptance

Implementation follows RED to GREEN development. Automated coverage includes:

- backward-compatible decoding and strict rejection of unknown appearance keys;
- bounds for every new numeric field and all new enums;
- four distinct route and material configurations;
- compiler output for home/task modes, safe areas, independent chrome opacity,
  and materially distinct family recipes;
- route-marker installation, cleanup, and selector confinement;
- gallery preview composition and stable card geometry;
- four unique, validated background and preview hashes;
- continued rejection of CSS, scripts, selectors, commands, and remote URLs;
- existing CDP, package, localization, compact overlay, and performance suites.

Native screenshot QA covers the four prototype cards at narrow and wide window
sizes and the Theme Studio controls. A deterministic, non-Codex render fixture
may demonstrate compiled home and task treatments. It must be labeled as a
fixture, not a live Codex acceptance result.

Final verification includes the complete Swift test suite, production build,
ad-hoc app verification, release verifier, DMG read-only mount validation,
native screenshots, and read-only code review. Real Codex CDP visual acceptance
remains an explicit manual user step and cannot be reported as passed.

## Out of Scope

- Regenerating the other twenty themes before prototype approval.
- Copying or redistributing Dream Skin artwork or third-party character assets.
- Importing Dream Skin CSS, JavaScript, shell scripts, selectors, or runtime.
- Applying a theme to Codex, restarting Codex, quitting Codex, or modifying the
  official app bundle during development verification.
