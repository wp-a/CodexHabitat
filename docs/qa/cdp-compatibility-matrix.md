# CDP Compatibility Matrix

Last updated: 2026-07-17

The appearance bridge is optional, disabled by default, and never modifies the
Codex bundle. Compatibility is keyed to the verified official bundle version;
it is not inferred from DOM similarity.

| Codex version | Profile | Identity verification | Automated injection/restore | Live apply/restore | Status |
| --- | --- | --- | --- | --- | --- |
| `26.707.0` to `<26.708.0` | `codex-26.707` | Passed on `26.707.91948` arm64 | Passed, including reload bootstrap and watcher idempotence | Requires packaged-Habitat confirmation | Supported with live gate |
| `26.708.0` and newer | None | Version may verify | Rejected before injection | Not applicable | Unsupported, fail closed |
| Older versions | None | Not evaluated | Rejected before injection | Not applicable | Unsupported, fail closed |

## Profile-owned selectors

```text
aside.app-shell-left-panel
main.main-surface
.composer-surface-chrome
.thread-scroll-container
[data-radix-popper-content-wrapper]
```

Themes cannot provide selectors, CSS, script, commands, or remote URLs. The
host compiler accepts approved color tokens and bounded host-owned PNG data;
resource packs cannot inject their own deep-theme payloads.

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

The current selector direction was cross-checked against the MIT-licensed
[Codex Dream Skin](https://github.com/Fei-Away/Codex-Dream-Skin) project. The
bridge implementation and controlled CSS template are independent.
