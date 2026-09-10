#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$SCRIPT_DIR/compose-common.sh"
load_compose_environment "$ROOT"
cd "$ROOT"

# Dockerfiles retain frozen lockfile installs; revision labels provide proof of
# the exact checked-out inputs without changing the deployment tag. We leave
# base-image pulling explicitly disabled so a routine build does not silently
# refresh a floating base tag.
compose config --quiet
echo "Building parent revision $WARHAMMER_PARENT_REVISION"
echo "  Depot source: $DEPOT_SOURCE_REVISION"
echo "  Munda source: $MUNDA_SOURCE_REVISION"
compose build --pull=false "$@"
