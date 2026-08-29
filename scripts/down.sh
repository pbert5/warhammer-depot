#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR/.."

if [ ! -f .env.local ]; then
    echo "Missing .env.local; copy .env.local.example and set deployment values." >&2
    exit 1
fi

exec docker compose --env-file .env.local down
