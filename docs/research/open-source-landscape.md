# Codex Habitat Open-Source Landscape

Last reviewed: 2026-07-17.

This note records the repositories that influenced Codex Habitat and the
boundary for each influence. It is a product and implementation comparison,
not an assertion that every listed repository is a runtime dependency.

## Resulting product direction

Codex appearance support has three levels, in this order:

1. **Codex native theme share string.** The installed, signed Codex build
   `26.707.91948` contains a user-facing theme Import/Copy flow and the static
   `codex-theme-v1:` format. Habitat can copy a compatible color-token string
   to the pasteboard. The user performs the import in Codex. Habitat does not
   write Codex preferences.
2. **Independent Habitat themes.** Native pets and widgets always use the
   versioned `.habitat-pack` protocol and work without Codex theming or network
   access.
3. **Optional deep appearance bridge.** Loopback CDP remains available for
   wallpaper-level styling that native color themes cannot express. It is
   disabled by default, requires restart consent, verifies the Codex process,
   and restores on failure.

The public OpenAI documentation search did not document `codex-theme-v1` at
review time. The native exporter is therefore based on the schema present in
the locally installed signed build, not presented as a cross-version public
OpenAI API.

## Comparison matrix

| Project | Verified focus | What Habitat adopts | Boundary |
| --- | --- | --- | --- |
| [Codex Dream Skin](https://github.com/Fei-Away/Codex-Dream-Skin) | macOS/Windows Codex styling through loopback CDP without patching the app bundle; macOS code is MIT | reversible session lifecycle, loopback-only listener, health review, one-click restore | no scripts, CSS, selectors, presets, portraits, or IP artwork copied; bridge stays optional |
| [Awesome Codex Themes](https://github.com/mcpso/awesome-codex-themes) | CC0 index of CLI themes, Codex app share strings, builders, and CDP skins | ecosystem map and the distinction between native theme tokens and deep skins | index claims are rechecked against source or the local app before implementation |
| [samuxbuilds/codex-themes](https://github.com/samuxbuilds/codex-themes), [shaw-baobao/codex-themes](https://github.com/shaw-baobao/codex-themes), [lafllamme/codex-themes](https://github.com/lafllamme/codex-themes), [Tinte](https://github.com/Railly/tinte) | theme galleries, preview/build tools, and palette conversion | preview-first theme selection, semantic token export, portable palette thinking | Habitat does not bundle their themes or depend on their web runtimes |
| [OpenPets](https://github.com/alterhq/openpets) and [OpenPetsKit](https://github.com/alterhq/OpenPetsKit) | native macOS shared desktop pet, menu bar control, local socket/MCP integration, embeddable Swift runtime | non-activating pet ergonomics, host-owned actions, explicit local integration boundaries | Habitat keeps its own read-only Codex connector and package validator; no OpenPets runtime dependency |
| [Petdex](https://github.com/crafter-station/petdex) | MIT gallery/CLI/desktop ecosystem for 8x9 animated pet packages | opt-in catalog, license/source disclosure, ID and SHA-256 checks, existing Codex pet compatibility | individual pet assets keep their own licenses; unverified catalog entries are browse-only |
| [Ping Island](https://github.com/erha19/ping-island) | native macOS menu-bar/notch surface for attention, completion, and multi-agent sessions | compact connection status and glanceable attention states | Habitat does not approve actions, read transcripts, or become a multi-agent command center |
| [CodexMonitor](https://github.com/Dimillian/CodexMonitor) | MIT Tauri client for workspaces, threads, and the Codex app-server | app-server protocol awareness and reconnect-state presentation | Habitat is not a replacement conversation or review client |
| [CodexBar](https://github.com/steipete/CodexBar) | macOS usage visibility across Codex and other providers | compact usage display and missing-value honesty | Habitat does not reuse provider credentials, browser cookies, or billing aggregation |
| [friuns2/codexui](https://github.com/friuns2/codexui) | cross-platform replacement UI for Codex surfaces | useful comparison for portability requirements only | excluded from theming inputs because Habitat must remain a native companion, not a replacement client |

## Decisions carried into v1

- Theme and pet packages are static data. They cannot contain scripts,
  selectors, expressions, commands, remote CSS, or executable actions.
- Imported packages expose semantic colors, typed widget configuration,
  relative placement, pet rendering mode, and bounded pet scale. The host owns
  layout safety and all interactions.
- Existing Codex pets are discovered read-only. Habitat packages live under
  Habitat's own Application Support directory.
- Catalog access is opt-in. Author, source, license, content ID, and digest are
  shown or checked before an install can publish.
- Native Codex theme export is clipboard-only. Deep CDP styling is a separate
  helper and is never required for pets, timers, widgets, or resource packs.

## Rejected approaches

- Modifying `app.asar`, the official app bundle, signatures, or Codex settings
  files.
- Shipping arbitrary CSS or JavaScript in `.habitat-pack` archives.
- Copying community theme art without an asset-level redistribution license.
- Treating concept screenshots as importable themes.
- Reading prompt, response, command, transcript, or project-file content to
  drive the pet.
