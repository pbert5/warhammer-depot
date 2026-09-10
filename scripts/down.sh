#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR/.."
. "$SCRIPT_DIR/compose-common.sh"

if [ ! -f .env.local ]; then
    echo "Missing .env.local; copy .env.local.example and set deployment values." >&2
    exit 1
fi

compose down
./scripts/munda-supabase.sh stop
exec ./scripts/remove-network-guard.sh
