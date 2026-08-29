#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
[ "${RESET_MUNDA_LOCAL_CONFIRM:-}" = "RESET" ] || {
  echo "This deletes the local Supabase database. Re-run with RESET_MUNDA_LOCAL_CONFIRM=RESET." >&2
  exit 2
}
exec "$ROOT/scripts/munda-supabase.sh" reset
