#!/usr/bin/env bash
# Baut das Rojo-Projekt und veroeffentlicht es via Roblox Open Cloud.
# Benoetigt: RBX_API_KEY (Open-Cloud-Key mit universe-places:write, nur dieses Experience).
# Aufruf:  ./scripts/publish.sh            -> versionType=Published (spielbar)
#          ./scripts/publish.sh Saved      -> nur Testversion, aendert nichts Spielbares
set -euo pipefail

UNIVERSE_ID="${RBX_UNIVERSE_ID:-10681442070}"
PLACE_ID="${RBX_PLACE_ID:-122300603709533}"
VERSION_TYPE="${1:-Published}"
ROJO_VERSION="7.5.1"

: "${RBX_API_KEY:?RBX_API_KEY ist nicht gesetzt (Environment-Variable/Secret mit dem Open-Cloud-Key)}"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

ROJO="$(command -v rojo || true)"
if [ -z "$ROJO" ]; then
    echo "rojo nicht im PATH — lade v${ROJO_VERSION}..."
    curl -sSL -o "$WORK_DIR/rojo.zip" \
        "https://github.com/rojo-rbx/rojo/releases/download/v${ROJO_VERSION}/rojo-${ROJO_VERSION}-linux-x86_64.zip"
    unzip -q -o "$WORK_DIR/rojo.zip" -d "$WORK_DIR"
    chmod +x "$WORK_DIR/rojo"
    ROJO="$WORK_DIR/rojo"
fi

cd "$PROJECT_DIR"
"$ROJO" build -o "$WORK_DIR/game.rbxl"

echo "Lade hoch (versionType=${VERSION_TYPE})..."
RESPONSE="$(curl -sS -w '\n%{http_code}' -X POST \
    "https://apis.roblox.com/universes/v1/${UNIVERSE_ID}/places/${PLACE_ID}/versions?versionType=${VERSION_TYPE}" \
    -H "x-api-key: ${RBX_API_KEY}" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$WORK_DIR/game.rbxl")"

HTTP_CODE="$(echo "$RESPONSE" | tail -n1)"
BODY="$(echo "$RESPONSE" | sed '$d')"

if [ "$HTTP_CODE" = "200" ]; then
    echo "OK: $BODY"
    echo "Spielbar unter: https://www.roblox.com/games/${PLACE_ID}"
else
    echo "FEHLER (HTTP $HTTP_CODE): $BODY" >&2
    echo "Hinweise: 401/403 -> Key/Scope pruefen; 404 -> Universe-/Place-ID vertauscht oder falsch." >&2
    exit 1
fi
