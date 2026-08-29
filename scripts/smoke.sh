#!/bin/sh
set -eu

BASE_URL=${1:-http://127.0.0.1:${DEPOT_PORT:-19096}}

curl --fail --silent --show-error "$BASE_URL/" >/dev/null
curl --fail --silent --show-error "$BASE_URL/faction/smoke-test-route" >/dev/null
curl --fail --silent --show-error "$BASE_URL/data/index.json" >/dev/null
echo "Depot smoke checks passed: $BASE_URL"
