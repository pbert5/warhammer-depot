#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
. "$ROOT/scripts/compose-common.sh"

usage() {
    cat <<'EOF'
Usage: scripts/cleanup-legacy-depot-fixtures.sh [--apply --backup-evidence PATH]

The default is a read-only dry run. --apply deletes only matching legacy Depot
roster/collection rows; it never deletes users. A non-empty pg_dump evidence
file is mandatory for --apply.
EOF
}

mode=dry-run
backup_evidence=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --apply) mode=apply ;;
        --backup-evidence)
            [ "$#" -ge 2 ] || { echo "--backup-evidence requires a path" >&2; exit 2; }
            backup_evidence=$2
            shift
            ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [ "$mode" = apply ]; then
    [ -n "$backup_evidence" ] || {
        echo "Refusing --apply without --backup-evidence PATH" >&2
        exit 2
    }
    [ -s "$backup_evidence" ] || {
        echo "Refusing --apply: backup evidence is missing or empty: $backup_evidence" >&2
        exit 2
    }
fi

[ -f .env.local ] || { echo "Missing .env.local; copy .env.local.example." >&2; exit 1; }
load_compose_environment "$ROOT"

# compose-common deliberately leaves Docker Compose to resolve its normal
# project name from this repository directory: "warhammer". An explicit
# COMPOSE_PROJECT_NAME may be used for a namespaced local instance.
project=${COMPOSE_PROJECT_NAME:-warhammer}
case "$project" in
    warhammer|warhammer-*) ;;
    *) echo "Refusing unexpected Compose project: $project" >&2; exit 2 ;;
esac
export COMPOSE_PROJECT_NAME="$project"

compose config --quiet
db_user=${DEPOT_POSTGRES_USER:-depot}
db_name=${DEPOT_POSTGRES_DB:-depot}

# A candidate must have all three independent signals:
#   1. an exact prefix emitted by the historical E2E helpers and a 13-digit
#      Date.now() suffix;
#   2. document identity fields agreeing with the relational columns;
#   3. the generated millisecond timestamp falling between creation and the
#      latest update (with a small import/clock-skew allowance).
# Everything else is intentionally ambiguous and is retained.
selector=$(cat <<'SQL'
WITH candidates AS (
    SELECT 'roster'::text AS kind, id, name, user_id, created_at, updated_at
      FROM rosters
     WHERE name ~ '^(E2E Roster|E2E Collection Roster|Astra Militarum E2E) [0-9]{13}$'
       AND document->>'id' = id
       AND document->>'name' = name
       AND document->>'factionId' = faction_id
       AND (right(name, 13)::bigint BETWEEN
            floor(extract(epoch FROM created_at) * 1000)::bigint - 300000 AND
            ceil(extract(epoch FROM updated_at) * 1000)::bigint + 300000)
    UNION ALL
    SELECT 'collection'::text, id, name, user_id, created_at, updated_at
      FROM collections
     WHERE name ~ '^(E2E Collection|E2E Collection Roster|Astra Militarum E2E) [0-9]{13}$'
       AND document->>'id' = id
       AND document->>'name' = name
       AND document->>'factionId' = faction_id
       AND (right(name, 13)::bigint BETWEEN
            floor(extract(epoch FROM created_at) * 1000)::bigint - 300000 AND
            ceil(extract(epoch FROM updated_at) * 1000)::bigint + 300000)
)
SELECT kind, id, name, user_id, created_at, updated_at
  FROM candidates
 ORDER BY kind, created_at, id;
SQL
)

echo "Legacy Depot fixture selector (dry-run=$([ "$mode" = dry-run ] && echo true || echo false))"
echo "Compose project: $project; database: $db_name"
echo "Candidates (exact kind, id, name, user_id, created_at, updated_at):"
compose exec -T depot-db psql -v ON_ERROR_STOP=1 -P pager=off -U "$db_user" -d "$db_name" -c "$selector"

if [ "$mode" = dry-run ]; then
    echo "No changes made. Ambiguous records were retained."
    echo "For an apply, first run ./scripts/backup-postgres.sh and pass its dump to --backup-evidence."
    exit 0
fi

apply_sql=$(printf '%s\n%s\n%s\n%s\n%s\n' \
    'BEGIN;' \
    'CREATE TEMP TABLE legacy_fixture_candidates ON COMMIT DROP AS' \
    "$selector" \
    "DELETE FROM rosters AS target USING legacy_fixture_candidates AS candidate WHERE candidate.kind = 'roster' AND target.id = candidate.id AND target.user_id = candidate.user_id; DELETE FROM collections AS target USING legacy_fixture_candidates AS candidate WHERE candidate.kind = 'collection' AND target.id = candidate.id AND target.user_id = candidate.user_id;" \
    'COMMIT;')

compose exec -T depot-db psql -v ON_ERROR_STOP=1 -P pager=off -U "$db_user" -d "$db_name" -c "$apply_sql"
remaining=$(compose exec -T depot-db psql -v ON_ERROR_STOP=1 -At -U "$db_user" -d "$db_name" -c "SELECT count(*) FROM ( $selector ) AS remaining;")
[ "$(printf '%s' "$remaining" | tr -d '[:space:]')" = 0 ] || {
    echo "Postcondition failed: matching legacy rows remain" >&2
    exit 1
}
echo "Applied safely: matching roster/collection rows deleted; users were not touched."
