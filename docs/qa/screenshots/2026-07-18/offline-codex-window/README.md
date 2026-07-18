# Offline Codex Window Visual QA

Generated on 2026-07-18 from commit `94e77403c31733e4ea1a28b814661c40585fc3ee`.

## Scope

This directory is offline-only evidence. It uses the pinned synthetic Codex DOM fixture, the exact supported compatibility profile, the production theme resolver/compiler/installer, and local bundled artwork. It does not connect to, modify, restart, quit, or capture the installed Codex application.

The evidence covers all 24 built-in themes on both `home` and `task` routes at wide and narrow viewports:

- 96 individual scene captures in `scenes/`
- 4 full-library contact sheets in `contact-sheets/`
- 8 primary nostalgia captures in `primary/`
- Machine-readable fingerprints and checks in `metrics.json`

## Automated Checks

- 96 of 96 theme, route, and viewport scenes passed.
- No external network request was attempted.
- Maximum measured route update latency was 0.31 ms.
- Narrow-viewport focus-Y probe pixel delta was 0.431640625.
- Minimum nonblank ratio was 0.9326171875.
- Minimum visible task artwork delta was 0.019287109375.
- Semantic foreground assignments and banner fades were present in every scene.
- Surface annotations, control bounds, composer hit targets, popover bounds, and horizontal overflow checks passed in every scene.

## Manual Review

The four contact sheets and the high-risk nostalgia, light, banner, wide, and narrow scenes were reviewed at original resolution. The review confirmed materially different full-window compositions, readable light-theme navigation and task surfaces, continuous banner fades, preserved artwork focal areas, and no obvious logos, protected characters, embedded text, or copied product imagery.

## Required Manual Acceptance

Real CDP application to Codex was intentionally not performed. Live Codex visual acceptance, restoration, and listener-closure checks remain explicit user-run steps. These offline screenshots must not be described as live Codex acceptance.
