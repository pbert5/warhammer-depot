#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
ORACLE_REV=${ORACLE_REV:-6d424fc55820d773bb20866a999750d9462f16e1}
PROJECT=${COMPOSE_PROJECT_NAME:-warhammer-oracle-6d424fc}
ORACLE_SOURCE=$(mktemp -d "${TMPDIR:-/tmp}/warhammer-oracle.XXXXXX")
COMPOSE="docker compose --project-name $PROJECT --file $REPO_DIR/compose.oracle.yaml"

cleanup() {
  $COMPOSE down --volumes --remove-orphans >/dev/null 2>&1 || true
  git -C "$REPO_DIR/vendor/depot" worktree remove --force "$ORACLE_SOURCE" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

if ! git -C "$REPO_DIR/vendor/depot" cat-file -e "$ORACLE_REV^{commit}" 2>/dev/null; then
  git -C "$REPO_DIR/vendor/depot" fetch --quiet origin main
fi
git -C "$REPO_DIR/vendor/depot" cat-file -e "$ORACLE_REV^{commit}"
git -C "$REPO_DIR/vendor/depot" worktree add --detach "$ORACLE_SOURCE" "$ORACLE_REV" >/dev/null

export WARHAMMER_REPO=$REPO_DIR
export WARHAMMER_ORACLE_SOURCE=$ORACLE_SOURCE
export WARHAMMER_ORACLE_DOCKERFILE=$REPO_DIR/Dockerfile.oracle
export WARHAMMER_ORACLE_TEST_DOCKERFILE=$REPO_DIR/Dockerfile.oracle-test
export WARHAMMER_ORACLE_PLAYWRIGHT_CONFIG=$REPO_DIR/playwright.oracle.config.mjs
export WARHAMMER_PARITY_SPEC=$REPO_DIR/vendor/depot/packages/web/e2e/roster-add-units-parity.spec.ts

echo "Oracle revision: $ORACLE_REV"
echo "Compose project: $PROJECT"
$COMPOSE --profile test build oracle-web oracle-test chrome-devtools-mcp
$COMPOSE up -d oracle-web
$COMPOSE --profile test run --rm oracle-test pnpm --dir /app/packages/web exec playwright test --config=/opt/playwright.oracle.config.mjs e2e/home.spec.ts e2e/settings.spec.ts e2e/not-found.spec.ts
$COMPOSE --profile test run --rm oracle-test pnpm --dir /app/packages/web exec playwright test --config=/opt/playwright.oracle.config.mjs e2e/roster-add-units.spec.ts e2e/roster-add-units-parity.spec.ts
$COMPOSE run --rm --no-deps oracle-test node -e "fetch('http://oracle-web/').then(r=>{if(!r.ok) throw Error(String(r.status));}).catch(e=>{console.error(e);process.exit(1)})"
echo "Oracle vertical slice passed"
