# Visual References

These references capture the Codex Habitat overlay with the four committed
semantic themes. They are release evidence, not screenshots of the official
Codex app and contain no user data or third-party pet artwork.

| Theme | Reference | Primary checks |
| --- | --- | --- |
| Workbench | `workbench-overlay.png` | Light surface, teal focus, amber attention |
| Night Shift | `night-shift-overlay.png` | Dark contrast, visible controls, coral error |
| Arcade Signal | `arcade-signal-overlay.png` | Blue/yellow accents, pixel-oriented clarity |
| Quiet Garden | `quiet-garden-overlay.png` | Light green surface, cherry error contrast |

Each image is 720 x 360 RGBA. The overlay frame is fixed so changes to labels,
status icons, widget expansion, or pet fallback cannot resize the window.

Release review checks:

- no clipped text, blank image, overlap, or unintended transparency;
- all status colors remain distinct from the surface and each other;
- pet and widget bounds remain stable between activity states;
- light and dark references retain readable native controls;
- no prompt, response, file path, account, or raw thread data appears.

The committed baselines were captured on 2026-07-17 from deterministic local
fixtures. Theme preview and icon generation details are recorded in
[`docs/asset-provenance.md`](../../docs/asset-provenance.md).
