# Offline Codex Window Fixture

This debug-only fixture is synthetic and is never a live Codex acceptance test.
Every capture contains the visible `OFFLINE THEME FIXTURE` label. It does not
launch, inspect, restart, or modify Codex, and it rejects all network protocols.

The renderer consumes only the debug-only Swift exporter payload. It exercises
the real bundled resolver, latest compatibility profile, compiler, and installer
expression against a fixed representative DOM. It renders all 24 built-in
themes on home and task routes at 1512 x 982, 1180 x 820, and 860 x 720, for
144 checks total.

The browser is isolated from all network protocols. Before rendering, it
independently verifies the exported profile, template, artwork, source, and CSS
fingerprints. It then asserts exact selector cardinality and annotations, one
installed style, bidirectional route response within 120 ms, no console or page
errors, bounded core controls, no horizontal overflow, composer hit testing,
task scrolling, visible decoded artwork, nonblank pixels, and perceptual image
differences. Nothing in this fixture is evidence of live Codex acceptance.

Install the exact local tooling and its Chromium revision:

```bash
npm ci
npx playwright install chromium
```

Run contract and headless-browser checks:

```bash
../../../scripts/render-codex-theme-fixtures.sh --check
```

Write the 144 full-resolution captures, six contact sheets, eight primary
captures for the four prototype themes, and `metrics.json` to a local directory:

```bash
../../../scripts/render-codex-theme-fixtures.sh --write /tmp/habitat-offline-fixture
```

The shell wrapper creates the exporter payload in a private temporary directory
and removes it on exit. It never accepts an app path, authorization flag, live
session, CDP endpoint, or network URL.
