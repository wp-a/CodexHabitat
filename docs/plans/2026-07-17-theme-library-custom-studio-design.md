# Theme Library and Local Theme Studio Design

**Date:** 2026-07-17
**Status:** Approved
**Extends:** `2026-07-17-game-themes-compact-overlay-token-metrics-design.md`

## Goal

Expand Codex Habitat from twelve built-in themes to a browsable library of twenty-four original themes, then let users create, import, edit, and export local themes without accepting executable CSS or JavaScript.

The collection may respond to familiar messenger, social-farm, anime, game, and film moods, but bundled names, images, icons, characters, and interface chrome must be original. The product must remain publishable without depending on unlicensed franchise assets.

## Product Direction

Habitat uses a hybrid model:

1. Twenty-four polished built-in themes provide immediate variety.
2. A local Theme Studio lets a user choose their own image and tune a bounded set of appearance controls.
3. Existing `.habitat-pack` import and export remains the sharing format.
4. A public online marketplace remains out of scope until moderation, licensing, attribution, and takedown processes exist.

This gives the user the breadth of a theme marketplace without making the first release dependent on a server or unsafe third-party code.

## Built-In Collection

The existing twelve stable IDs remain unchanged:

| Category | Stable ID | Display name |
| --- | --- | --- |
| Utility | `workbench` | Workbench Turbo |
| Dark | `night-shift` | Neon Night Shift |
| Game | `arcade-signal` | Arcade Overdrive |
| Cozy | `quiet-garden` | Pixel Meadow |
| Nostalgia | `retro-messenger` | Retro Messenger 2007 |
| Chat | `green-chat-desk` | Green Chat Desktop |
| Nostalgia | `cyber-cafe` | Cyber Cafe Neon |
| Game | `candy-combo` | Candy Combo |
| Game | `crimson-mecha` | Crimson Mecha |
| Classic | `win95-workbench` | Win95 Workbench |
| Game | `gold-rush` | Gold Rush |
| Game | `aqua-pulse` | Aqua Pulse |

Twelve new original themes extend the library:

| Category | Stable ID | Display name | Original visual direction |
| --- | --- | --- | --- |
| Cozy | `harvest-homestead` | Harvest Homestead | Social farm dashboard, crops, orchard, warm morning light |
| Anime energy | `solar-ki-arena` | Solar Ki Arena | Rocky arena, solar energy trails, bold orange and cobalt |
| Anime energy | `moonlit-shinobi` | Moonlit Shinobi | Rooftop village, indigo moon, crimson signal accents |
| Adventure | `grand-ocean-crew` | Grand Ocean Crew | Bright ocean chart, sails, treasure color rhythm |
| Cozy adventure | `elemental-companions` | Elemental Companions | Friendly elemental habitats, collectible-adventure mood |
| Cinematic | `walled-vanguard` | Walled Vanguard | Monumental ramparts, dawn haze, military UI rhythm |
| Fantasy | `arcane-academy` | Arcane Academy | Enchanted library, constellations, jewel-tone magic |
| Anime energy | `hero-training-campus` | Hero Training Campus | Graphic training grounds, primary-color action panels |
| Cinematic | `nebula-vanguard` | Nebula Vanguard | Space-opera command deck, red/blue light contrast |
| Storybook | `spirit-lantern-town` | Spirit Lantern Town | Hand-painted bath-town atmosphere and lantern warmth |
| Pixel game | `block-frontier` | Block Frontier | Voxel landscape and inventory-like panel rhythm |
| Sports | `turbo-striker` | Turbo Striker | Stadium floodlights, speed lines, cyan and lime signals |

These directions are intentionally genre-level. They do not include franchise names in the shipped UI and must not contain recognizable costumes, hairstyles, creatures, symbols, logos, props, catchphrases, or copied compositions.

## Theme Gallery

The Themes page becomes a compact library rather than one long undifferentiated grid.

- A segmented category filter shows All, Nostalgia, Chat, Anime, Games, Cozy, Classic, and Custom.
- Search matches localized theme name and category.
- Each card shows the real preview, five palette swatches, category, and selected state.
- Built-in and imported themes use the same card component.
- A fixed `Create Theme` command opens Theme Studio in a sheet.
- Empty search and empty custom states provide one clear action, not promotional text.

The gallery remains a native macOS settings surface. It does not imitate a storefront and does not nest cards inside decorative cards.

## Local Theme Studio

Theme Studio creates a local draft and previews changes without applying them to Codex. It exposes only host-owned controls:

- name and optional author;
- background image chosen from a local PNG, JPEG, or WebP;
- automatic palette suggestion plus manual color wells;
- allowlisted style family;
- art focal point and safe side;
- background strength, panel opacity, blur, and compact/comfortable density;
- optional local pairing with an installed pet;
- preview, save locally, import, and export.

The editor normalizes the source image to a bounded packaged background and preview. The original source file is never modified. Pet pairing is stored in Habitat settings; a pet is included in an exported pack only when its files already belong to that same validated pack.

Theme Studio has three states: editing, validation failure, and saved. Validation errors remain adjacent to the invalid field. Closing a dirty editor asks whether to discard the draft.

## Resource Protocol

The manifest gains one optional `theme` object so old packs continue to decode:

```json
{
  "theme": {
    "category": "animeEnergy",
    "styleFamily": "animeEnergy",
    "background": "background.jpg",
    "artFocus": { "x": 0.72, "y": 0.42 },
    "safeSide": "leading",
    "backgroundStrength": 0.42,
    "panelOpacity": 0.88,
    "blurRadius": 10,
    "density": "comfortable"
  }
}
```

Every enum is allowlisted. Coordinates and appearance numbers have strict finite ranges. The background must reference a declared local image whose hash, MIME signature, dimensions, and decoded size pass existing package validation. A theme pack cannot provide CSS, JavaScript, selectors, commands, URLs, fonts loaded from the network, or executable files.

Custom themes may be compiled by the optional CDP bridge only from validated tokens and this bounded metadata. The host selects the CSS template and selectors. Custom theme content never reaches string interpolation as raw CSS.

## Style Families

The original five host-owned families remain. Four general families are added: `cozyWorld`, `animeEnergy`, `fantasyAdventure`, and `pixelWorld`. Twenty-four themes map into these nine compiler-owned treatments. The family changes panel geometry, border treatment, texture strength, and route scrims; it is not only a color switch.

## Rights and Safety

Built-in assets are original, text-free, and character-free unless a new original Habitat character is separately designed and documented. Each generated image records its prompt, generation source, date, dimensions, checksum, and review result in the provenance log.

References such as QQ Farm, WeChat, Dragon Ball, Naruto, One Piece, Pokemon, Attack on Titan, Harry Potter, Star Wars, Studio Ghibli, Minecraft, or other popular properties are research inputs only. Habitat must not ship their names, marks, characters, distinctive silhouettes, copied UI, audio, or promotional art.

Users are responsible for rights to images they import locally. The editor shows this once before the first export. No telemetry, upload, public sharing, or remote catalog is added in this release.

## Testing and Acceptance

Automated coverage must prove:

- exactly twenty-four stable built-in IDs with localized names and categories;
- unique, readable, bounded preview and background assets;
- legacy manifests without `theme` remain valid;
- invalid enums, ranges, paths, hashes, MIME signatures, and undeclared files fail closed;
- Theme Studio creates a package that installs through the same `PackageInstaller` used for external packs;
- imported custom themes can be previewed and compiled without raw CSS or script content;
- search, category filters, dirty-draft confirmation, and Chinese localization behave correctly;
- existing pet, widget, overlay, Token, bridge-security, and resource-pack tests remain green.

Visual QA captures the All, Anime, Nostalgia, and Custom gallery filters plus Theme Studio at desktop and narrow settings widths. Live Codex application and Codex restart remain excluded from automated development QA.

