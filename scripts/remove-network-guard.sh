#!/bin/sh
set -eu

TAG=warhammer-depot-supabase-guard
CHAIN=WARHAMMER_DEPOT_SUPABASE_GUARD

if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || { echo "network guard requires root or sudo" >&2; exit 1; }
    exec sudo "$0" "$@"
fi

remove_jump() {
    tool=$1
    parent=$2
    while "$tool" -w -C "$parent" -m comment --comment "$TAG" -j "$CHAIN" >/dev/null 2>&1; do
        "$tool" -w -D "$parent" -m comment --comment "$TAG" -j "$CHAIN"
    done
}

for tool in iptables ip6tables; do
    command -v "$tool" >/dev/null 2>&1 || continue
    for parent in INPUT DOCKER-USER; do
        remove_jump "$tool" "$parent"
    done
    if "$tool" -w -nL "$CHAIN" >/dev/null 2>&1; then
        "$tool" -w -F "$CHAIN"
        "$tool" -w -X "$CHAIN"
    fi
done

echo "Removed only $TAG rules and chains"
