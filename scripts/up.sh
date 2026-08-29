#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR/.."

if [ ! -f .env.local ]; then
    echo "Missing .env.local; copy .env.local.example and set deployment values." >&2
    exit 1
fi

# Create the ignored credential directory before Docker creates any runtime
# bind-mount parents as root.  This keeps a fresh clone writable by the
# operator who runs the launcher.
mkdir -p runtime/munda-supabase

./scripts/munda-supabase.sh start
# The generated anon key is a build-time NEXT_PUBLIC value in Next.js. Build
# Munda after the local stack starts so the browser gets the current project
# credentials; runtime server calls use MUNDA_SUPABASE_INTERNAL_URL.
set -a
. ./runtime/munda-supabase/env
set +a
docker compose --env-file .env.local --env-file ./runtime/munda-supabase/env build munda-web
exec docker compose --env-file .env.local --env-file ./runtime/munda-supabase/env up -d
