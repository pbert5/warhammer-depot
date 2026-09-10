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
        image_id=$(docker inspect --format '{{.Image}}' "$container")
        labels=$(docker inspect --format '{{index .Config.Labels "org.opencontainers.image.source.revision"}} {{index .Config.Labels "com.warhammer.depot.revision"}} {{index .Config.Labels "com.warhammer.munda.revision"}}' "$container")
        set -- $labels
        parent_label=$1; depot_label=$2; munda_label=$3
        printf '  %s: image=%s parent=%s depot=%s munda=%s\n' "$service" "$image_id" "$parent_label" "$depot_label" "$munda_label"
        case "$service" in
            depot-web|depot-api) [ "$depot_label" = "$DEPOT_SOURCE_REVISION" ] || { echo "STALE Depot revision on $service" >&2; exit 1; } ;;
            munda-web) [ "$munda_label" = "$MUNDA_SOURCE_REVISION" ] || { echo "STALE Munda revision" >&2; exit 1; } ;;
        esac
        health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container")
        printf '  %s health: %s\n' "$service" "$health"
        [ "$health" = healthy ] || { echo "$service is not healthy" >&2; exit 1; }
    else
        echo "  $service: not running" >&2
        exit 1
    fi
done
echo
./scripts/check-network-guard.sh
echo
echo "Operator URLs"
echo "  launcher: http://127.0.0.1:${WARHAMMER_HOME_PORT:-19095}"
echo "  Depot:    http://127.0.0.1:${DEPOT_PORT:-19096}"
echo "  Munda:    http://127.0.0.1:${MUNDA_PORT:-19097}"
if [ -n "${DEPOT_TAILSCALE_IPV4_ADDR:-}" ]; then
    echo "  Depot (Tailscale IPv4): http://${DEPOT_TAILSCALE_IPV4_ADDR}:${DEPOT_PORT:-19096}"
    echo "  launcher (Tailscale IPv4): http://${DEPOT_TAILSCALE_IPV4_ADDR}:${WARHAMMER_HOME_PORT:-19095}"
    echo "  Munda (Tailscale IPv4): http://${DEPOT_TAILSCALE_IPV4_ADDR}:${MUNDA_PORT:-19097}"
fi
if [ -n "${DEPOT_TAILSCALE_ADDR:-}" ]; then
    echo "  Depot (Tailscale IPv6): http://[${DEPOT_TAILSCALE_ADDR}]:${DEPOT_PORT:-19096}"
    echo "  launcher (Tailscale IPv6): http://[${DEPOT_TAILSCALE_ADDR}]:${WARHAMMER_HOME_PORT:-19095}"
    echo "  Munda (Tailscale IPv6): http://[${DEPOT_TAILSCALE_ADDR}]:${MUNDA_PORT:-19097}"
fi
