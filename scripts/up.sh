#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR/.."
. "$SCRIPT_DIR/compose-common.sh"

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
load_compose_environment "$PWD"
compose build --pull=false depot-api depot-web munda-web
# Recreate source-built application services from those just-built images. The
# database volume is intentionally left attached and untouched.
compose up -d --no-build --force-recreate --remove-orphans --wait --wait-timeout 180
if ! ./scripts/apply-network-guard.sh; then
    echo "Network guard failed; stopping the newly started project to avoid leaving Supabase published unprotected." >&2
    compose down || true
    ./scripts/munda-supabase.sh stop || true
    exit 1
fi
exec ./scripts/status.sh
