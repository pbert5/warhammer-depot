#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$SCRIPT_DIR/compose-common.sh"
load_compose_environment "$ROOT"
cd "$ROOT"

compose config --quiet
echo "Compose project status"
compose ps --all
echo
echo "Revision proof (checked out vs. running container labels)"
echo "  parent: $WARHAMMER_PARENT_REVISION"
echo "  Depot:  $DEPOT_SOURCE_REVISION"
echo "  Munda:  $MUNDA_SOURCE_REVISION"
for service in depot-web depot-api munda-web; do
    container=$(compose ps -q "$service" 2>/dev/null || true)
    if [ -n "$container" ]; then
        docker inspect --format "  $service: image={{.Config.Image}} parent={{index .Config.Labels \"org.opencontainers.image.source.revision\"}} depot={{index .Config.Labels \"com.warhammer.depot.revision\"}} munda={{index .Config.Labels \"com.warhammer.munda.revision\"}}" "$container"
    else
        echo "  $service: not running"
    fi
done
echo
./scripts/check-network-guard.sh
