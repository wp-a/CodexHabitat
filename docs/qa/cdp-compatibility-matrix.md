# CDP Compatibility Matrix

Last updated: 2026-07-18

The appearance bridge is optional, disabled by default, and never modifies the
Codex bundle. Compatibility is keyed to the verified official bundle version;
it is not inferred from DOM similarity.

| Codex version | Profile | Identity verification | Automated injection/restore | Live apply/restore | Status |
| --- | --- | --- | --- | --- | --- |
| `26.707.0` to `<26.708.0` | `codex-26.707` | Passed on `26.707.91948` arm64 | Passed, including reload bootstrap and watcher idempotence | Requires packaged-Habitat confirmation | Supported with live gate |
| `26.715.0` to `<26.716.0` | `codex-26.715` | Passed on `26.715.31251` arm64 | Passed, including profile compilation, layout health, fail-close, and watcher idempotence | Requires packaged-Habitat confirmation | Static selectors verified; live gate pending |
| `26.708.0` to `<26.715.0`, and `26.716.0` or newer | None | Version may verify | Rejected before restarting or injecting | Not applicable | Unsupported, fail closed |
| Older versions | None | Not evaluated | Rejected before injection | Not applicable | Unsupported, fail closed |

## Profile-owned selectors

```text
aside.app-shell-left-panel
main.main-surface
.composer-surface-chrome
.thread-scroll-container
[data-radix-popper-content-wrapper]
```

The `26.715` profile was derived from a read-only extraction of the verified
official `26.715.31251` `app.asar` with SHA-256
`8142e0848fe49097c129a1093f80061c13de04c2893525ee7c751d26b5a7bd4f`.
The extracted React bundles still mount the sidebar class on an `aside`, the
main-surface class on a `main`, the composer and thread-scroll classes on their
respective live containers, and the Radix popper wrapper attribute. No Codex
bundle file was modified. This static evidence enables the narrow profile, but
does not replace the required live screenshot and restore gate.

Themes cannot provide selectors, CSS, script, commands, or remote URLs. The
host compiler accepts approved color tokens and bounded single-frame PNG,
JPEG, or WebP data from either the 24 bundled themes or a package that passes
the same local installer and bridge revalidation. Theme packages select one of
nine host-owned style families, but cannot inject CSS or other deep-theme
payloads.

## Health gate

Every target must pass all checks after injection:

- sidebar, main surface, and composer exist, are visible, and fit the viewport;
- composer pointer events remain enabled;
- the thread surface exists and remains scrollable when content overflows;
- visible popovers and native controls stay inside the viewport;
- horizontal overflow remains at or below one pixel.

Failure removes installed styles, terminates only the recorded process identity,
closes the debugging port, and launches the verified official app normally.
PID reuse, session mismatch, wildcard listeners, non-`app://` pages, unexpected
targets, wrong ports, credentials, queries, and fragments are refused.

Each installed document receives a mutation-safe style element plus a
`Page.addScriptToEvaluateOnNewDocument` bootstrap. A low-frequency helper watch
checks both verified page target IDs and the document's installed marker, so a
new watcher does not register a duplicate bootstrap. Normal Habitat termination
stops the watcher before restore, while an orphaned watcher restores after its
Habitat parent disappears. The UI leaves the active state if the watcher exits.

## Updating the matrix

1. Verify the new official Codex bundle ID, Team ID, strict signature,
   architecture, executable, and version without injecting.
2. Inspect selectors without copying third-party CSS or injectors.
3. Add a narrow non-overlapping version range and regression fixtures.
4. Run all target, compiler, listener, coordinator, and health tests.
5. With explicit user confirmation, capture a live screenshot, inspect every
   native control, restore, and confirm the port is closed.
6. Record the exact tested version and architecture here.

The current development run completed compiler, resolver, coordinator, health,
and release-package tests for both versioned profiles without launching the
bridge. Live CDP apply on `26.715.31251`, screenshot inspection inside Codex,
restore, and listener-closure confirmation remain manual user-approved
acceptance steps and are not claimed as passed.

The current selector direction was cross-checked against the MIT-licensed
[Codex Dream Skin](https://github.com/Fei-Away/Codex-Dream-Skin) project. The
bridge implementation and controlled CSS template are independent.
