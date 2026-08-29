#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TAG=warhammer-depot-supabase-guard
CHAIN=WARHAMMER_DEPOT_SUPABASE_GUARD
NETWORK=warhammer_default

if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || { echo "network guard requires root or sudo" >&2; exit 1; }
    exec sudo "$0" "$@"
fi

command -v iptables >/dev/null 2>&1 || { echo "iptables is required" >&2; exit 1; }
command -v ip6tables >/dev/null 2>&1 || { echo "ip6tables is required" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 1; }

network_json=$(docker network inspect "$NETWORK" 2>/dev/null) || {
    echo "Docker network $NETWORK is not present; start the project before applying the guard" >&2
    exit 1
}
network_id=$(printf '%s\n' "$network_json" | sed -n 's/.*"Id": "\([0-9a-f]*\)".*/\1/p' | head -n 1)
# Docker bridge names use the first 12 characters of the network id.
bridge_if=br-$(printf '%s' "$network_id" | cut -c1-12)
gateway=$(printf '%s\n' "$network_json" | sed -n 's/.*"Gateway": "\([0-9.]*\)".*/\1/p' | head -n 1)
[ -n "$network_id" ] && [ -n "$gateway" ] || { echo "could not resolve $NETWORK bridge metadata" >&2; exit 1; }

ensure_chain() {
    tool=$1
    if ! "$tool" -w -nL "$CHAIN" >/dev/null 2>&1; then
        "$tool" -w -N "$CHAIN"
    fi
}

remove_jump() {
    tool=$1
    parent=$2
    while "$tool" -w -C "$parent" -m comment --comment "$TAG" -j "$CHAIN" >/dev/null 2>&1; do
        "$tool" -w -D "$parent" -m comment --comment "$TAG" -j "$CHAIN"
    done
}

ensure_chain iptables
ensure_chain ip6tables

# Rebuild only the project-owned chains. Existing host and Docker policy is
# neither flushed nor replaced.
iptables -w -F "$CHAIN"
ip6tables -w -F "$CHAIN"
remove_jump iptables INPUT
remove_jump iptables DOCKER-USER
remove_jump ip6tables INPUT
remove_jump ip6tables DOCKER-USER

# Host INPUT sees Docker's userland-proxy traffic. The bridge exception is
# only for Munda's host.docker.internal:54321 route to this project's gateway.
iptables -w -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment "$TAG" -j ACCEPT
iptables -w -A "$CHAIN" -i lo -p tcp -m multiport --dports 54321,54322 -m comment --comment "$TAG" -j ACCEPT
iptables -w -A "$CHAIN" -i tailscale0 -p tcp --dport 54321 -m comment --comment "$TAG" -j ACCEPT
iptables -w -A "$CHAIN" -i "$bridge_if" -d "$gateway" -p tcp --dport 54321 -m comment --comment "$TAG" -j ACCEPT
iptables -w -A "$CHAIN" -p tcp --dport 54321 -m comment --comment "$TAG" -j REJECT --reject-with tcp-reset
iptables -w -A "$CHAIN" -p tcp --dport 54322 -m comment --comment "$TAG" -j REJECT --reject-with tcp-reset

# DOCKER-USER sees forwarded packets after Docker DNAT, so match the original
# published port with conntrack. This also protects the path if userland-proxy
# is disabled in a future Docker configuration.
iptables -w -A "$CHAIN" -i tailscale0 -p tcp -m conntrack --ctorigdstport 54321 -m comment --comment "$TAG" -j ACCEPT
iptables -w -A "$CHAIN" -p tcp -m conntrack --ctorigdstport 54321 -m comment --comment "$TAG" -j REJECT --reject-with tcp-reset
iptables -w -A "$CHAIN" -p tcp -m conntrack --ctorigdstport 54322 -m comment --comment "$TAG" -j REJECT --reject-with tcp-reset
iptables -w -A "$CHAIN" -j RETURN

# IPv6 has no project Docker bridge today, but the wildcard Supabase proxy is
# real. Loopback and Tailscale 54321 are allowed; all other published access
# is rejected, and 54322 is loopback-only.
ip6tables -w -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment "$TAG" -j ACCEPT
ip6tables -w -A "$CHAIN" -i lo -p tcp -m multiport --dports 54321,54322 -m comment --comment "$TAG" -j ACCEPT
ip6tables -w -A "$CHAIN" -i tailscale0 -p tcp --dport 54321 -m comment --comment "$TAG" -j ACCEPT
ip6tables -w -A "$CHAIN" -p tcp --dport 54321 -m comment --comment "$TAG" -j REJECT --reject-with tcp-reset
ip6tables -w -A "$CHAIN" -p tcp --dport 54322 -m comment --comment "$TAG" -j REJECT --reject-with tcp-reset
ip6tables -w -A "$CHAIN" -i tailscale0 -p tcp -m conntrack --ctorigdstport 54321 -m comment --comment "$TAG" -j ACCEPT
ip6tables -w -A "$CHAIN" -p tcp -m conntrack --ctorigdstport 54321 -m comment --comment "$TAG" -j REJECT --reject-with tcp-reset
ip6tables -w -A "$CHAIN" -p tcp -m conntrack --ctorigdstport 54322 -m comment --comment "$TAG" -j REJECT --reject-with tcp-reset
ip6tables -w -A "$CHAIN" -j RETURN

# Put the jumps first without changing any other rule ordering. Docker's
# chain is expected to exist while the published containers are running.
iptables -w -I INPUT 1 -m comment --comment "$TAG" -j "$CHAIN"
iptables -w -I DOCKER-USER 1 -m comment --comment "$TAG" -j "$CHAIN"
ip6tables -w -I INPUT 1 -m comment --comment "$TAG" -j "$CHAIN"
ip6tables -w -I DOCKER-USER 1 -m comment --comment "$TAG" -j "$CHAIN"

echo "Applied $TAG (IPv4/IPv6 INPUT and DOCKER-USER); Docker bridge $bridge_if gateway $gateway"
