#!/bin/sh
set -eu

TAG=warhammer-depot-supabase-guard
CHAIN=WH_DEPOT_SUPA_GUARD

if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        exec sudo "$0" "$@"
    fi
    command -v docker >/dev/null 2>&1 || { echo "network guard inspection requires root, sudo, or Docker" >&2; exit 1; }
    ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
    exec docker run --rm --privileged --network host \
        -v /run/docker.sock:/var/run/docker.sock \
        -v "$ROOT:/repo" alpine:3.22 sh -c \
        'apk add --no-cache iptables docker-cli >/dev/null && exec /repo/scripts/check-network-guard.sh "$@"' \
        guard "$@"
fi

for tool in iptables ip6tables; do
    echo "### $tool $CHAIN"
    "$tool" -w -S "$CHAIN"
    for parent in INPUT DOCKER-USER; do
        "$tool" -w -C "$parent" -m comment --comment "$TAG" -j "$CHAIN"
        echo "$tool $parent jump: present"
    done
done
