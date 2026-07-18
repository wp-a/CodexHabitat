# Offline Codex Window Visual QA

Generated on 2026-07-19 from commit `73e5a809f307d5a07b47b31d25c6d3853c547c4c`.

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
- Maximum measured route update latency was 0.20 ms.
- Narrow-viewport focus-Y probe pixel delta was 0.431640625.
- Minimum nonblank ratio was 0.9052734375.
- Minimum Home artwork delta was 0.4375.
- Minimum visible non-off Task artwork delta was 0.097412109375; the
  22 non-off Task themes averaged 0.2764337713068182 across both viewports.
- Minimum computed Task request-card opacity was 0.88.
- Minimum Home suggestion viewport inset was 29.5 px; Retro Messenger and
  Grand Ocean Crew measured 32 px wide and 29.5 px narrow.
- Semantic foreground assignments, banner fades, computed Task reading
  scrims, and independently readable request-card surfaces on the verified
  `data-user-message-bubble` host slot were present in every applicable scene.
- Surface annotations, control bounds, composer hit targets, popover bounds, and horizontal overflow checks passed in every scene.

## Manual Review

The four contact sheets and the high-risk nostalgia, light, banner, wide, and narrow scenes were reviewed at original resolution. The review confirmed materially different full-window compositions, readable light-theme navigation and task surfaces, continuous banner fades, preserved artwork focal areas, and no obvious logos, protected characters, embedded text, or copied product imagery. Compared with the previous Build 8 fixture, all 48 Task captures and the 28 immersive Home captures changed while the 20 framed/quiet Home controls remained byte-identical.

## Required Manual Acceptance

Real CDP application to Codex was intentionally not performed. Live Codex visual acceptance, restoration, and listener-closure checks remain explicit user-run steps. These offline screenshots must not be described as live Codex acceptance.
