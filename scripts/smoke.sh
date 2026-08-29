#!/bin/sh
set -eu

if [ "$#" -gt 0 ]; then
    BASE_URL=$1
else
    # Read only the simple numeric assignment we need; do not source .env.local.
    ENV_PORT=
    if [ -f .env.local ]; then
        ENV_PORT=$(sed -n 's/^[[:space:]]*DEPOT_PORT[[:space:]]*=[[:space:]]*\([0-9][0-9]*\)[[:space:]]*$/\1/p' .env.local | head -n 1)
    fi
    BASE_URL=http://127.0.0.1:${ENV_PORT:-${DEPOT_PORT:-19096}}
fi

curl --fail --silent --show-error "$BASE_URL/" >/dev/null
curl --fail --silent --show-error "$BASE_URL/faction/smoke-test-route" >/dev/null
curl --fail --silent --show-error "$BASE_URL/data/index.json" >/dev/null
echo "Depot smoke checks passed: $BASE_URL"
