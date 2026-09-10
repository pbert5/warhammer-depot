#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
[ -f .env.e2e ] || { echo "Missing .env.e2e; copy .env.e2e.example." >&2; exit 1; }
mode=${1:-}
case "$mode" in
    ""|--apply) ;;
    *) echo "Usage: $0 [--apply]" >&2; exit 2 ;;
esac
set -a
. ./.env.e2e
set +a

case "${COMPOSE_PROJECT_NAME:-}" in
    warhammer-e2e|warhammer-e2e-*) ;;
    *) echo "Refusing non-E2E Compose project: ${COMPOSE_PROJECT_NAME:-unset}" >&2; exit 2 ;;
esac
[ "${WARHAMMER_E2E_PARENT_USER_ID:-}" = 00000000-0000-0000-0000-000000000002 ] || {
    echo "Refusing unexpected reserved parent identity" >&2
    exit 2
}

compose() {
    docker compose --project-name "$COMPOSE_PROJECT_NAME" --env-file .env.e2e \
        -f compose.yaml -f compose.e2e.yaml "$@"
}

compose config --quiet
user_id=$WARHAMMER_E2E_PARENT_USER_ID
db_user=${DEPOT_POSTGRES_USER:-depot_e2e}
db_name=${DEPOT_POSTGRES_DB:-depot_e2e}
counts_query="SELECT (SELECT count(*) FROM users WHERE id = '$user_id'), (SELECT count(*) FROM rosters WHERE user_id = '$user_id'), (SELECT count(*) FROM collections WHERE user_id = '$user_id');"
before=$(compose exec -T depot-db psql -v ON_ERROR_STOP=1 -At -F '|' -U "$db_user" -d "$db_name" -c "$counts_query")
IFS='|' read -r user_count roster_count collection_count <<EOF
$before
EOF
[ "$user_count" = 1 ] || { echo "Refusing to continue: reserved E2E user row is missing or duplicated" >&2; exit 1; }
inventory=$(compose exec -T depot-db psql -v ON_ERROR_STOP=1 -P pager=off -U "$db_user" -d "$db_name" -c "SELECT 'roster' AS kind, id, name FROM rosters WHERE user_id = '$user_id' UNION ALL SELECT 'collection', id, name FROM collections WHERE user_id = '$user_id' ORDER BY kind, id;")

if [ "$mode" = "--apply" ]; then
    compose exec -T depot-db psql -v ON_ERROR_STOP=1 -U "$db_user" -d "$db_name" \
        -c "BEGIN; DELETE FROM rosters WHERE user_id = '$user_id'; DELETE FROM collections WHERE user_id = '$user_id'; COMMIT;" >/dev/null
    after=$(compose exec -T depot-db psql -v ON_ERROR_STOP=1 -At -F '|' -U "$db_user" -d "$db_name" -c "$counts_query")
    IFS='|' read -r after_user_count after_roster_count after_collection_count <<EOF
$after
EOF
    [ "$after_user_count" = 1 ] && [ "$after_roster_count" = 0 ] && [ "$after_collection_count" = 0 ] || {
        echo "Purge postcondition failed; refusing success" >&2
        exit 1
    }
    echo "Purged E2E Depot documents for $COMPOSE_PROJECT_NAME; reserved user row retained"
else
    echo "Dry run for reserved E2E user $user_id (users row count: $user_count)"
    echo "Would delete $roster_count roster(s) and $collection_count collection(s):"
    printf '%s\n' "$inventory"
    echo "Use $0 --apply to execute and verify the purge"
fi
