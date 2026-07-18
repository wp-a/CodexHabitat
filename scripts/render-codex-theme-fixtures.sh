#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_ROOT="$ROOT/Tests/VisualFixtures/CodexWindow"
MODE="${1:---check}"
PROFILE_VERSION="26.715.31925"

case "$MODE" in
    --check)
        [[ "$#" -eq 1 ]] || { echo "usage: $0 --check" >&2; exit 64; }
        ;;
    --write)
        [[ "$#" -eq 2 ]] || { echo "usage: $0 --write OUTPUT_DIRECTORY" >&2; exit 64; }
        ;;
    *)
        echo "usage: $0 --check | --write OUTPUT_DIRECTORY" >&2
        exit 64
        ;;
esac

[[ -d "$FIXTURE_ROOT/node_modules/playwright" ]] || {
    echo "offline fixture: run 'npm ci' in $FIXTURE_ROOT" >&2
    exit 69
}

umask 077
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codex-habitat-offline-fixture.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT INT TERM
PAYLOAD="$TEMP_ROOT/payload.json"

swift build --package-path "$ROOT" --target CodexHabitatApp
swift run --package-path "$ROOT" CodexHabitatThemeBridge offline-fixture \
    --profile-version "$PROFILE_VERSION" \
    --output "$PAYLOAD"

[[ -f "$PAYLOAD" && ! -L "$PAYLOAD" ]] || {
    echo "offline fixture: exporter did not write a private local payload" >&2
    exit 70
}

npm --prefix "$FIXTURE_ROOT" run test:contract

if [[ "$MODE" == "--check" ]]; then
    node "$FIXTURE_ROOT/render.mjs" --check "$PAYLOAD"
else
    node "$FIXTURE_ROOT/render.mjs" --write "$PAYLOAD" "$2"
fi
