#!/bin/sh
set -eu

TAG=warhammer-depot-supabase-guard
CHAIN=WARHAMMER_DEPOT_SUPABASE_GUARD

if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || { echo "network guard inspection requires root or sudo" >&2; exit 1; }
    exec sudo "$0" "$@"
fi

for tool in iptables ip6tables; do
    echo "### $tool $CHAIN"
    "$tool" -w -S "$CHAIN"
    for parent in INPUT DOCKER-USER; do
        "$tool" -w -C "$parent" -m comment --comment "$TAG" -j "$CHAIN"
        echo "$tool $parent jump: present"
    done
done
