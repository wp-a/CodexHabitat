# Codex Habitat Design

Date: 2026-07-16
Status: Approved

## 1. Objective

Build a native macOS companion for Codex that makes agent activity visible and
pleasant without replacing the Codex app. The first release combines an
animated desktop pet, compact widgets, a safe cross-platform resource format,
and an optional reversible CDP theme bridge.

The product should be attractive enough for broad adoption while remaining a
quiet work tool. Expressive visuals belong in the pet and Habitat overlay;
settings and diagnostics should follow familiar macOS conventions.

## 2. Decisions

- Native macOS first: Swift 6, SwiftUI, and AppKit.
- Direct distribution as a Developer ID-signed and notarized DMG. No iOS target
  and no Mac App Store dependency.
- Cross-platform resource protocol from the first release, without promising a
  Windows binary in v1.
- Codex state comes from the app-server control plane and is read-only by
  default.
- Existing pets under `~/.codex/pets` are discovered and reused in place.
- CDP theming is optional, isolated, version-gated, and never required for pets
  or widgets.
- Third-party packages are static data. They cannot execute scripts, commands,
  HTML, WebViews, or remote assets.

## 3. Alternatives Considered

### Native macOS application

Selected. SwiftUI gives a maintainable settings surface while AppKit provides
the window-level behavior needed for transparent nonactivating overlays,
click-through, multiple Spaces, and multi-display positioning.

### Tauri cross-platform application

Rejected for v1. It would accelerate a future Windows client, but the reviewed
Tauri companion projects still leave Windows click-through, mixed-DPI, and
multi-monitor behavior partially unverified. It also adds a web runtime to a
small always-on utility.

### Extend Codex Dream Skin directly

Rejected as the primary architecture. CDP injection can produce convincing
visuals, but tying pets, widgets, and state to Codex's private DOM would make the
entire product fragile after Codex updates.

## 4. Product Shape

Codex Habitat is a menu-bar application with two visible surfaces:

1. A transparent desktop Habitat containing the pet, a short status bubble,
   and an expandable widget rail.
2. A settings center for Habitat layout, pets, widgets, themes, integrations,
   privacy, and diagnostics.

The overlay does not use a decorative enclosing card. The pet remains visually
unframed. Status bubbles and widgets appear only when useful and collapse to a
small footprint during idle work.

### Primary interactions

- Click the pet to expand current state and widgets.
- Drag the pet to move the complete Habitat with edge-snap feedback.
- Right-click for pet switching, hide/show, position lock, and settings.
- Use the menu bar for global show/hide, timer controls, connection status, and
  quit.

### First-release modules

- Menu-bar shell, settings, first-run flow, launch-at-login, version display,
  and update checks.
- Read-only Codex connector.
- Pet renderer and animation state machine.
- Task status, usage, clock, and Pomodoro widgets.
- Local pet/theme library with preview, import, export, and validation.
- Optional Petdex browsing and installation.
- Optional CDP theme bridge with health checks and restore.

### Explicit non-goals

- Windows executable, iOS app, cloud account, or cloud sync.
- A replacement Codex chat or review client.
- Arbitrary third-party widget code.
- Marketplace publishing from the app.
- Reading or uploading prompts, responses, repository files, or command output.

## 5. Visual System

The visual direction is "quiet native tool, living desktop space."

- Use SF Pro for interface text and SF Mono for compact metrics.
- Use a neutral light/dark foundation with teal for running, amber for
  attention, and coral red for errors. Avoid a one-hue interface.
- Use system materials only for menu-bar popovers and compact overlay bubbles.
  Keep the settings surface clear and mostly opaque.
- Use SF Symbols for application controls.
- Keep repeated preview cards at 8 px radius or less and avoid nested cards.
- Keep motion between 120 and 240 ms except for pet frame animation. Respect
  Reduce Motion and accessibility contrast settings.

### Settings navigation

- Habitat
- Pets
- Widgets
- Themes
- Integrations
- Privacy

### Built-in Habitat themes

- Workbench: bright, restrained, tool-oriented default.
- Night Shift: dark workbench with teal state and amber attention.
- Arcade Signal: red, blue, and yellow accents for pixel pets.
- Quiet Garden: low-saturation green, white, and cherry accents for illustrated
  pets.

First launch opens a working preview, discovers existing pets, lets the user
choose one Habitat and widgets, then places it on the desktop. It is not a
marketing or account-registration flow.

Sharing exports a clean screenshot and static resource pack. User names,
project names, usage values, and task content are excluded by default.

## 6. Technical Architecture

### Targets and modules

- `HabitatApp`: application lifecycle, menu bar, SwiftUI settings, onboarding,
  and update presentation.
- `HabitatCore`: settings, normalized state, timers, layout, and package domain
  models. It contains no AppKit UI.
- `OverlayHost`: AppKit `NSPanel` creation, window levels, click-through,
  dragging, edge snapping, Spaces, and display changes.
- `CodexConnector`: app-server control connection, allowlisted read methods,
  event filtering, and reconnect logic.
- `PetRuntime`: pet package adapters, frame decoding, deterministic animation,
  state chains, and render-mode selection.
- `WidgetRuntime`: built-in widget registry and typed metric binding.
- `ResourceKit`: package schemas, validation, atomic installation, previews, and
  library indexing.
- `ThemeBridge`: separate unprivileged helper process for optional CDP theming.

### State flow

```text
Codex control socket ----> CodexConnector ----+
Session file metadata ---> Estimated state ---+
System clock/timers --------------------------+--> HabitatState actor
Validated local/online packages --> ResourceKit   |-> PetRuntime
                                                   |-> WidgetRuntime
                                                   +-> OverlayHost

Theme tokens/assets --> ThemeBridge helper --> loopback CDP --> Codex renderer
```

`HabitatState` is a Swift Actor and the single source of truth for the overlay.
Renderers consume immutable snapshots rather than observing Codex events
directly.

### Codex connection

The connector first uses `codex app-server proxy` to reach the running app's
Unix control socket. It performs the required initialize/initialized handshake
and calls only an explicit read allowlist, including loaded thread status and
account rate limits.

It maps protocol data to a minimal state model:

- active -> working
- pending approval or input -> attention
- completed -> success, then idle
- failed or system error -> failure
- idle or not loaded -> resting

Message bodies, command text, file paths, model output, and reasoning are
dropped during event decoding. Only a local hash of the thread ID, state,
timestamp, and event category may enter application state.

When the control socket is unavailable, the connector retries with exponential
backoff and jitter. In parallel, the app may inspect only regular-file size and
modification time for recent `$CODEX_HOME/sessions` files. It must not open
session content, and the UI labels this fallback `Local activity estimate`.
A separate `codex app-server --stdio` process may be used only for a rate-limit
snapshot. It must not claim to provide live desktop thread state.

## 7. Resource Protocol

The portable distribution unit is a static `.habitat-pack` ZIP:

```text
example.habitat-pack
  habitat.json
  preview.png
  LICENSE
  pets/
  artwork/
  fonts/
```

The manifest contains package identity, semantic version, author, license,
minimum runtime, supported modes, semantic color tokens, local assets, pet
adapters, and widget placement. Layout uses relative coordinates, anchors, and
safe areas rather than absolute macOS screen coordinates.

Themes may select only registered widgets:

- `codex.status`
- `codex.usage`
- `system.clock`
- `timer.pomodoro`
- `timer.countdown`

Each widget accepts a typed, allowlisted configuration. Themes cannot provide
custom renderers, expressions, executable actions, or network requests.

### Pet compatibility

- Load existing Codex `pet.json` packages without rewriting them.
- Adapt the official 8 by 9 atlas into an internal versioned model.
- Reserve adapters for community v2 atlases, look direction, and richer state
  chains.
- Allow `auto` or `pixelated` image rendering, bounded scale, frame timing, and
  state-chain metadata in Habitat-owned packages.
- Keep interaction actions host-owned; pet assets cannot execute commands.

### Validation

Reject path traversal, symlinks, executable files, HTML, WebViews, remote URLs,
undeclared files, oversized archives, excessive image dimensions, missing
licenses, and invalid manifests. Apply file-count, compressed-size,
uncompressed-size, and canvas limits before installation.

Online downloads require an allowlisted HTTPS host, metadata confirmation,
manifest inspection, and SHA-256 verification. Installation happens in a
temporary directory and is atomically moved into the library only after every
check passes.

## 8. Theme Bridge

When the installed Codex version exposes its native theme import flow, Habitat
may export a static `codex-theme-v1` share string to the clipboard. The user
imports it in Codex; Habitat never writes Codex preferences. This is preferred
for color, font, contrast, and semantic diff tokens.

The bridge does not accept arbitrary CSS from resource packages. Themes provide
tokens and local art; Habitat compiles them into a maintained, versioned style
template with semantic selectors.

Enablement requires explicit user confirmation to restart Codex. The bridge:

1. Verifies Bundle ID, Developer Team signature, version, and executable.
2. Starts Codex with a randomly selected loopback-only debugging port.
3. Confirms that the listener belongs to the verified Codex process tree.
4. Selects a compatibility profile for the installed Codex version.
5. Injects the controlled style template and runs layout health checks.
6. Verifies sidebar, composer, task area, popovers, scrolling, pointer events,
   and horizontal overflow.
7. On disable or failure, stops the themed session and launches Codex normally.

Unknown Codex versions fail closed. A limited stable background/token profile
may be offered only after its own health checks pass. The bridge never modifies
the app bundle, `app.asar`, code signature, authentication, API configuration,
or Codex threads.

## 9. Local Data and Privacy

```text
~/Library/Application Support/Codex Habitat/
  Settings.json
  Library/Pets/
  Library/Themes/
  Cache/Previews/
  Diagnostics/
```

The app does not store Codex login tokens. Diagnostics contain module names,
error codes, versions, and timestamps, rotate after seven days, and can be
cleared by the user. Exported diagnostics are redacted before packaging.

Core functionality works offline. Network access is limited to explicit market
browsing and signed update checks.

## 10. Error Handling

External failures degrade locally:

- Codex unavailable: pet idles; local timers continue.
- Connector disconnected: show a quiet offline state and reconnect without
  repeated alerts.
- Invalid pet: quarantine it and keep the last known-good selection.
- Missing metric: render unavailable, never an invented value.
- Invalid import: reject before atomic installation.
- Theme bridge failure: restore normal Codex and leave Habitat running.
- Theme helper crash: do not auto-reenable theming on the next launch.

Use inline status for routine errors. Reserve dialogs for decisions requiring
user consent. Diagnostics provides connection tests, resource validation,
official-appearance restore, redacted export, and cache clearing.

## 11. Verification

### Automated coverage

- Core state mapping, timers, settings migration, and layout math.
- JSON-RPC fixtures for disconnects, out-of-order events, added fields, and
  reconnect behavior.
- Pet frame mapping, loops, state chains, scale, and render modes.
- Package traversal, symlink, zip-bomb, remote URL, damaged image, and license
  validation cases.
- Theme bridge process ownership, port constraints, version rejection,
  injection, removal, and restoration.
- SwiftUI interaction tests and AppKit overlay behavior tests.
- Visual snapshots for light/dark mode, built-in themes, long strings, low
  resolution, and Retina rendering.

### Real-device QA

- Single and multiple displays with different scale factors.
- Normal desktop, full-screen applications, and multiple Spaces.
- Codex closed, starting, active, waiting, failed, completed, and updated.
- Sleep/wake, display disconnect, and menu-bar restart.
- Reduce Motion, increased contrast, and larger text.
- CDP enablement, abnormal Codex exit, and one-click restore.

### Release acceptance

- Discover an existing pet and display Habitat within three first-run steps.
- Never steal keyboard focus or block unrelated pointer interactions.
- Reflect normal Codex state changes within one second.
- Target less than 1 percent idle CPU on the reference Mac.
- Keep core pets, widgets, and timers usable without network access.
- Leave Codex threads and existing pets intact after uninstall.
- Confirm the debugging port closes and official appearance returns after CDP
  disablement.
- Confirm crash and diagnostics artifacts contain no messages, commands, paths,
  or credentials.

## 12. Distribution

Development builds run from Xcode. Public beta builds use hardened runtime,
Developer ID signing, notarization, and a DMG. Updates use a signed update feed.
The first release has no iOS target and no Mac App Store dependency.

## 13. Open-Source Research Inputs

The implementation may reuse compatible licensed code only after attribution
and dependency review. The design specifically draws ideas from:

- Codex Dream Skin: CDP injection, verification, and restoration.
- Awesome Codex Themes and its linked builders: native theme share formats,
  semantic tokens, previews, and palette portability.
- OpenPets and OpenPetsKit: native macOS pet and local state protocol patterns.
- Petdex: public pet catalog and package distribution.
- CodexBar: compact usage visibility and explicit unavailable states.
- Ping Island and CodexMonitor: Codex app-server integration and desktop state
  presentation.

CodexPet Nest informed the static theme and widget model, but its repository did
not expose a clear license during research, so its source must not be copied.
Third-party pet assets require per-asset license review regardless of the
catalog code's license.

The full comparison and adoption boundaries are recorded in
`docs/research/open-source-landscape.md`.
