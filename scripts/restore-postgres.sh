#!/bin/sh
set -eu
if [ "$#" -ne 1 ]; then echo "usage: $0 PATH_TO_DUMP" >&2; exit 2; fi
case "$1" in *.dump) ;; *) echo "refusing non-dump path" >&2; exit 2;; esac
docker compose --env-file .env.local exec -T depot-db pg_restore --clean --if-exists --no-owner -U "${DEPOT_POSTGRES_USER:-depot}" -d "${DEPOT_POSTGRES_DB:-depot}" < "$1"
