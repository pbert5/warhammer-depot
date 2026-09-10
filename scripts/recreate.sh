#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$SCRIPT_DIR/compose-common.sh"
load_compose_environment "$ROOT"
cd "$ROOT"

compose config --quiet

# Keep the existing guard in place while containers are replaced. Applying it
# first also repairs a missing guard before any project service is exposed.
./scripts/apply-network-guard.sh
echo "Recreating services from existing images (database volume preserved)"
compose up -d --no-build --force-recreate --remove-orphans "$@"
./scripts/apply-network-guard.sh
compose ps
