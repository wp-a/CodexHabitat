# Codex Runtime Compatibility

Last updated: 2026-07-17

Habitat uses the most precise local source Codex makes available without
reading conversation content. The status widget always distinguishes exact
control-plane state from a local metadata estimate.

| Codex runtime | Exact control events | Metadata estimate | Verified result |
| --- | --- | --- | --- |
| macOS app `26.707.91948`, arm64 | Control socket not published | Available | `Local activity estimate` |
| Managed standalone daemon with control socket | Supported by protocol and automated fixtures | Standby fallback | Requires live standalone install |
| Codex unavailable | Unavailable | Resting if the session directory is absent | No content read |

## Exact mode

Habitat resolves the Codex executable in this order: `CODEX_EXECUTABLE`, the
official app bundle, the managed standalone install, then `PATH`. It connects
with `codex app-server proxy`, performs the WebSocket and initialize handshake,
subscribes only to already-loaded threads, and uses an explicit read allowlist.

The connector publishes only event category, status, timestamp, rate-limit
percentages/reset times, and a locally salted thread hash. Prompt text, response
text, command output, paths, account tokens, and server error messages are
dropped before application state.

## Estimated mode

The official macOS build tested above runs its app server over private stdio and
does not create `~/.codex/app-server-control/app-server-control.sock`. Habitat
therefore enumerates only today's and yesterday's `*.jsonl` file metadata under
`$CODEX_HOME/sessions`: regular-file status, byte size, and modification date.
It never opens those files. Changes map to working, a quiet transition maps to
complete, and stable metadata maps to resting. Attention, failure, usage, and
thread identity remain unavailable in this mode.

The connector continues bounded exponential retries in the background. If a
supported control socket appears, exact mode takes precedence automatically;
disconnect returns to the labelled estimate.
