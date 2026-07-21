# CDP Compatibility Matrix

Last updated: 2026-07-21

The appearance bridge is optional, disabled by default, and never modifies the
Codex bundle. Compatibility is keyed to the verified official bundle version;
it is not inferred from DOM similarity.

| Codex version | Profile | Identity verification | Automated injection/restore | Live apply/restore | Status |
| --- | --- | --- | --- | --- | --- |
| `26.707.0` to `<26.708.0` | `codex-26.707` | Passed on `26.707.91948` arm64 | Passed, including reload bootstrap and watcher idempotence | Requires packaged-Habitat confirmation | Supported with live gate |
| `26.715.0` to `<26.715.31925` | `codex-26.715` | Passed on `26.715.31251` arm64 | Passed for the seven baseline surfaces | Requires packaged-Habitat confirmation | Baseline profile; live gate pending |
| `26.715.31925` to `<26.715.31926` | `codex-26.715.31925` | Passed on `26.715.31925` arm64 | Passed, including complete surface-profile decoding and safety validation | Requires packaged-Habitat confirmation | Exact-build static profile; live gate pending |
| `26.715.52143` to `<26.715.52144` | `codex-26.715.52143` | Passed read-only on `26.715.52143` arm64 | Static profile, compiler, coordinator, and health tests passed; live injection was not run | Requires packaged-Habitat confirmation | Exact-build static profile; live gate pending |
| `26.708.0` to `<26.715.0`, `26.715.31926` to `<26.715.52143`, and `26.715.52144` or newer | None | Version may verify | Rejected before restarting or injecting | Not applicable | Unsupported, fail closed |
| Older versions | None | Not evaluated | Rejected before injection | Not applicable | Unsupported, fail closed |

## Baseline profile-owned selectors

```text
aside.app-shell-left-panel
main.main-surface
.composer-surface-chrome
.thread-scroll-container
[data-radix-popper-content-wrapper]
main.main-surface > header.app-header-tint
[data-testid="home-icon"]
```

The exact `26.715.31925` and `26.715.52143` profiles additionally own these
independently validated selectors:

```text
#root
main.main-surface [role="main"]
[class~="group/home-suggestions"]
aside.app-shell-left-panel [aria-current]
[data-user-message-bubble]
[data-content-search-unit-key]
[data-content-search-unit-key] pre
[data-content-search-unit-key] [data-testid="exec-shell-body"]
[data-content-search-unit-key] [data-testid="dynamic-tool-call-group-body"]
[data-content-search-unit-key] [data-testid="pending-mcp-tool-calls-body"]
aside.app-shell-left-panel .sidebar-resize-handle-line
.app-shell-main-content-top-fade
.thread-scroll-container [data-thread-scroll-footer="true"] > [class~="pointer-events-none"]
main.main-surface [data-codex-composer-root]
```

No `stickyBand` selector is shipped because the read-only evidence did not
establish a narrow stable marker. The profile does not use positional `div`
selectors, content text, `aria-label`, wildcard roots, `:has`, or `:nth-*`.

The `26.715` profiles were derived from read-only extractions of the verified
official `26.715.31251` and `26.715.31925` bundles. Their `app.asar` SHA-256
values are `8142e0848fe49097c129a1093f80061c13de04c2893525ee7c751d26b5a7bd4f`
and `0c9dd677134340cb944e7642b8bc2504c7b73c7dc334d9d756547858171eea41`.
The `26.715.31925` bundle was reconfirmed read-only while the official Codex process
remained PID `23647`, started `Sat Jul 18 14:48:19 2026`; no apply, restart, or
quit action was performed. The extracted local-conversation bundle exposes the
narrow `data-user-message-bubble` host marker, so request-card treatment is
owned by that exact selector instead of a generic `article` rule.
The exact `26.715.52143` entry reuses that complete statically audited surface
map only for its single verified build. Read-only identity and version checks
plus profile, compiler, coordinator, and health tests passed; no live apply,
restart, restore, or screenshot claim was made.
The extracted React bundles still mount the sidebar class on an `aside`, the
main-surface class on a `main`, the composer and thread-scroll classes on their
respective live containers, and the Radix popper wrapper attribute. The current
bundle also starts an auxiliary pet renderer at
`avatar-overlay-composition-surface.html?surfaceId=...`, while primary windows
start at `index.html` with an optional `initialRoute`. The bridge validates
every page debugger endpoint before ignoring only allowlisted official
auxiliary URL shapes, then requires a passing native-layout snapshot before any
CSS installation. Unknown queries or unsafe endpoints fail the whole attempt;
unknown auxiliary routes cannot pass the pre-injection layout gate. No Codex
bundle file was modified. This static
evidence enables the narrow profile, but does not replace the required live
screenshot and restore gate.

Themes cannot provide selectors, CSS, script, commands, or remote URLs. The
host compiler accepts approved color tokens and bounded single-frame PNG,
JPEG, or WebP data from either the 24 bundled themes or a package that passes
the same local installer and bridge revalidation. Theme packages select one of
nine host-owned style families, but cannot inject CSS or other deep-theme
payloads.

## Health gate

Every accepted Codex main target must pass all checks after injection:

- sidebar, main surface, and composer exist, are visible, and fit the viewport;
- composer pointer events remain enabled;
- the thread surface exists and remains scrollable when content overflows;
- visible popovers and native controls stay inside the viewport;
- horizontal overflow remains at or below one pixel.

Failure removes installed styles, terminates only the recorded process identity,
closes the debugging port, and launches the verified official app normally.
PID reuse, session mismatch, wildcard listeners, non-`app://` pages, unexpected
targets, wrong ports, credentials, unknown query items, and fragments are
refused. If no valid main target remains, the bridge fails closed.

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
and release-package tests for every shipped profile without launching the
bridge. Live CDP apply on `26.715.31925` and `26.715.52143`, screenshot
inspection inside Codex, restore, and listener-closure confirmation remain
manual user-approved acceptance steps and are not claimed as passed.

The current selector direction was cross-checked against the MIT-licensed
[Codex Dream Skin](https://github.com/Fei-Away/Codex-Dream-Skin) project. The
bridge implementation and controlled CSS template are independent.
