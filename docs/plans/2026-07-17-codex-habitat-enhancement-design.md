# Codex Habitat Enhancement Design

**Date:** 2026-07-17  
**Status:** Approved

## Goal

Turn the macOS v1 companion into a useful, Chinese-localized Codex desktop
enhancement: smooth animated pets, reliable movement, meaningful usage metrics,
and an optional deep Codex appearance session that visibly applies and safely
restores a theme.

## Research Findings

- [Codex Dream Skin](https://github.com/Fei-Away/Codex-Dream-Skin) treats deep
  styling as a loopback CDP session. It restarts Codex with a local debugging
  port, injects into verified `app://` renderers, survives renderer reloads, and
  provides explicit restore and verification workflows.
- [Awesome Codex Themes](https://github.com/mcpso/awesome-codex-themes)
  distinguishes native `codex-theme-v1` color themes from CDP skins. Habitat
  should support both instead of presenting clipboard export as deep styling.
- [CodexBar](https://github.com/steipete/CodexBar) demonstrates useful usage
  presentation: quota windows, token totals, reset times, consumption pace, and
  honest unavailable states.
- The installed Codex `26.707.91948` app-server schema exposes
  `account/rateLimits/read`, `account/usage/read`, and
  `thread/tokenUsage/updated`. Account usage endpoints require ChatGPT
  authentication and are unavailable in API-key-only mode.

## Product Direction

Use a controlled hybrid architecture:

1. Native Habitat themes remain independent and always available.
2. Native Codex theme share strings remain available for portable color themes.
3. An optional CDP bridge provides wallpaper-level styling. It is host-owned,
   explicit, loopback-only, version-gated, and reversible.

The app does not patch the Codex bundle, `app.asar`, signature, or preferences.
Imported packs remain static data and cannot carry CSS, JavaScript, selectors,
commands, or remote URLs.

## Interaction Design

### Pet and Overlay

- When position is unlocked, the whole pet region is a drag surface.
- Widget controls remain interactive and do not begin a drag.
- Click-through mode intentionally ignores pointer input. The menu bar exposes
  a temporary **Move Habitat** mode that enables movement without requiring the
  user to find the settings toggle first.
- Position lock remains the durable way to prevent accidental movement.

### Localization

- Ship English and Simplified Chinese resources.
- Follow the macOS language automatically; English is the fallback.
- Localize onboarding, settings, menus, overlays, widgets, confirmations,
  errors, help text, and accessibility labels.
- Use locale-aware number, date, percentage, and duration formatting.

### Theme Experience

The theme screen owns the complete workflow:

- preview the selected theme and background;
- import a bounded local image;
- apply the look to Habitat;
- apply the deep look to Codex;
- show bridge health and current session state;
- restore the official Codex appearance.

Applying a deep theme requires an explicit confirmation because Codex restarts
once. Habitat then keeps a verified helper session alive and re-applies styles
after renderer navigation or reload. Quitting Habitat restores the official
appearance and closes the debugging port. A failed identity, version, listener,
target, injection, or layout check fails closed and restores Codex.

## Metrics Design

The default overlay prioritizes:

1. task/activity state and elapsed activity time;
2. current-session input, cached-input, and output tokens;
3. current context-window utilization;
4. recent output speed in output tokens per minute;
5. five-hour and weekly quota when the authenticated Codex account exposes it.

Clock, Pomodoro, and countdown remain optional but are no longer in the default
layout.

### Data Sources

- Prefer exact `account/rateLimits/read` and `account/usage/read` responses when
  a read-only app-server can authenticate.
- In API-key mode, show an explicit unavailable reason for account quotas.
- Use an incremental local session metrics reader for current-thread tokens,
  context utilization, and output speed.
- The reader accepts only `event_msg` records whose payload type is
  `token_count`. Every other record is discarded immediately without decoding
  its content into the application model.
- Persist only user settings. Do not persist prompts, responses, commands,
  paths, thread identifiers, raw session lines, or token event history.

The overlay never displays a fabricated zero for missing data. It uses an
unavailable state and a short localized reason.

## Performance Architecture

- Replace the SwiftUI `TimelineView` frame path with a pet-specific AppKit
  renderer/driver. A bounded timer updates only the sprite layer.
- Do not mutate the animator or publish model changes while SwiftUI evaluates a
  view body.
- Coalesce related snapshot fields into one published overlay update.
- Keep resting, offline, hidden, and Reduce Motion states timer-free.
- Pause metric polling and animation while the overlay is not visible.

Target budgets for the packaged release build:

- no SwiftUI "Publishing changes from within view updates" faults;
- static overlay below 1% average CPU;
- active pet animation below 3% average CPU on the development machine;
- no unbounded helper, timer, or renderer process accumulation.

## Theme Bridge Architecture

The helper owns:

- strict official bundle identity and version verification;
- a random high loopback port and recorded process identity;
- verified `app://` page targets only;
- host-compiled CSS and bounded local background data;
- navigation/reload observation and idempotent re-injection;
- layout health checks and a bounded verification screenshot;
- explicit restore and exit cleanup.

The main app owns user intent, previews, localization, and lifecycle status. It
does not contain CDP entitlements or flags.

## Error Handling

- Missing local Token data shows a localized empty state.
- API-key authentication shows Token metrics but labels account quota as
  unavailable.
- A malformed or oversized local background is rejected before the bridge
  session starts.
- A Codex update outside the compatibility range disables deep apply while
  leaving native themes, pets, and widgets available.
- If cleanup cannot prove process identity, Habitat preserves the recovery
  record, reports the problem, and does not signal an unrelated process.

## Testing and Acceptance

- Add regression tests before each behavior change.
- Test token-only parsing against mixed JSONL fixtures and malformed/truncated
  tails.
- Test speed calculations, context percentages, quota unavailable states, and
  settings migration.
- Test full-pet drag geometry, widget exclusion, click-through movement mode,
  snapping, and saved placement.
- Test English and Simplified Chinese key coverage.
- Test CDP re-injection, image bounds, session cleanup, restore, and failure
  rollback using fake transports before live use.
- Build and package the app, inspect Chinese and English screenshots, sample
  CPU, check unified logs, and perform a real apply/restore against the verified
  installed Codex build.

