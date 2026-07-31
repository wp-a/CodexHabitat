# Premium Codex Theme Fixture QA - 2026-07-30

This directory records the deterministic offline visual QA for the shared
premium Codex shell and all 24 built-in themes. The renderer exercised both
home and task routes at wide, narrow, and compact viewports:

- 144 individual scene PNGs under `scenes/`
- 6 all-theme contact sheets under `contact-sheets/`
- 8 representative review images under `primary/`
- machine-readable evidence in `metrics.json`

The evidence was generated from the worktree based on commit
`b28af1a2fc2f48f63e7c4669a5561db04f814571` with the Task 4 fixture and
contrast changes present. The recorded source fingerprints in `metrics.json`
bind the renderer, CSS template, fixture source, and exporter contract used for
the capture. The exact command was:

```sh
scripts/render-codex-theme-fixtures.sh --write /var/folders/8b/lpww4rx97bsdpy0bg802vmlm0000gn/T/codex-habitat-premium-theme-qa-final.JrSmVu
```

The run passed all 144 scene checks with zero external requests. It covered 9
host-owned style families. The minimum measured text contrast was 6.0615, the
minimum control contrast was 4.5224, maximum route latency was 0.6 ms, and the
maximum task-reading artwork leak was 0.0718. The lowest task and home artwork
pixel deltas were 0.1507 and 0.3463 respectively, confirming that the scene
remains visible instead of being replaced by a flat application surface.

All six contact sheets and original-resolution representative images for dark,
light, nostalgic desktop, cinematic, cozy, anime-inspired, fantasy, and pixel
families were reviewed. No obvious clipping, incoherent overlap, detached
composer, broken scene continuity, or unreadable task surface was found.

This was an offline fixture run only. It did not apply a theme to Codex, start
or use the live bridge, restart or quit Codex, or modify the official Codex app,
configuration, signature, or installation. Real CDP application, interaction,
restore, and visual acceptance in the installed Codex app remain explicit
manual user steps and are not claimed as passed here.
