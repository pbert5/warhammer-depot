#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROJECT_DIR="$ROOT/vendor/mundamanager"
RUNTIME_DIR="$ROOT/runtime/munda-supabase"
CLI_VERSION=2.116.0
die() { echo "munda-supabase: $*" >&2; exit 1; }

case "$(uname -s):$(uname -m)" in
    Linux:x86_64) CLI_PLATFORM=linux_amd64; CLI_SHA256=5b3031cb297d51b25be4c284e4c852254460ec722ec221d3b81b07d55acfd158 ;;
    Linux:aarch64|Linux:arm64) CLI_PLATFORM=linux_arm64; CLI_SHA256=015a45756bb8459716a4b44b020605adc11956cd7d0bd5824aec2ed1c8287933 ;;
    Darwin:x86_64) CLI_PLATFORM=darwin_amd64; CLI_SHA256=1e1dce66222fba539211624617960887e445fd7f27830d6f54bdb4eaf1d7c498 ;;
    Darwin:arm64) CLI_PLATFORM=darwin_arm64; CLI_SHA256=8b750455d7b02c989cec0c6c26599d28b0aefcbeedf20a315bb1d5215a185a83 ;;
    *) die "unsupported host platform $(uname -s):$(uname -m)" ;;
esac
CLI_ARCHIVE="supabase_${CLI_VERSION}_${CLI_PLATFORM}.tar.gz"
CLI_URL="https://github.com/supabase/cli/releases/download/v${CLI_VERSION}/${CLI_ARCHIVE}"
CLI="$RUNTIME_DIR/bin/supabase"
ENV_FILE="$RUNTIME_DIR/env"

install_cli() {
    command -v curl >/dev/null 2>&1 || die "curl is required to download the pinned Supabase CLI"
    command -v tar >/dev/null 2>&1 || die "tar is required to unpack the pinned Supabase CLI"
    mkdir -p "$RUNTIME_DIR/bin"
    if [ -x "$CLI" ]; then return; fi
    tmp="$RUNTIME_DIR/$CLI_ARCHIVE.tmp"
    curl -fsSL "$CLI_URL" -o "$tmp"
    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$tmp" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$tmp" | awk '{print $1}')
    else
        rm -f "$tmp"
        die "sha256sum or shasum is required to verify the pinned Supabase CLI"
    fi
    [ "$actual" = "$CLI_SHA256" ] || die "Supabase CLI checksum mismatch"
    tar -xzf "$tmp" -C "$RUNTIME_DIR/bin" supabase
    chmod 0755 "$CLI"
    rm -f "$tmp"
}

status_env() {
    (cd "$PROJECT_DIR" && "$CLI" status -o env)
}

write_env() {
    mkdir -p "$RUNTIME_DIR"
    umask 077
    status=$(status_env) || die "Supabase is not running; run scripts/up.sh first"
    api_url=$(printf '%s\n' "$status" | sed -n 's/^API_URL=//p' | tr -d '"')
    anon_key=$(printf '%s\n' "$status" | sed -n 's/^ANON_KEY=//p' | tr -d '"')
    service_key=$(printf '%s\n' "$status" | sed -n 's/^SERVICE_ROLE_KEY=//p' | tr -d '"')
    [ -n "$api_url" ] && [ -n "$anon_key" ] && [ -n "$service_key" ] || die "Supabase status did not provide API credentials"
    # Public URL is deliberately loopback-only. Containers reach the same
    # gateway through host.docker.internal, configured separately below.
    {
        echo "MUNDA_SUPABASE_URL=http://localhost:54321"
        echo "MUNDA_SUPABASE_INTERNAL_URL=http://host.docker.internal:54321"
        echo "MUNDA_SUPABASE_ANON_KEY=$anon_key"
        echo "MUNDA_SUPABASE_SERVICE_ROLE_KEY=$service_key"
    } > "$ENV_FILE"
    chmod 0600 "$ENV_FILE"
}

bootstrap_user() {
    [ -n "${MUNDA_ACCEPTANCE_EMAIL:-}" ] && [ -n "${MUNDA_ACCEPTANCE_PASSWORD:-}" ] || return 0
    url=${MUNDA_SUPABASE_INTERNAL_URL:-http://127.0.0.1:54321}
    key=${MUNDA_SUPABASE_SERVICE_ROLE_KEY:?missing MUNDA_SUPABASE_SERVICE_ROLE_KEY}
    if command -v jq >/dev/null 2>&1; then
        payload=$(jq -cn --arg email "$MUNDA_ACCEPTANCE_EMAIL" --arg password "$MUNDA_ACCEPTANCE_PASSWORD" \
          '{email:$email,password:$password,email_confirm:true}')
    elif command -v python3 >/dev/null 2>&1; then
        payload=$(MUNDA_ACCEPTANCE_EMAIL="$MUNDA_ACCEPTANCE_EMAIL" MUNDA_ACCEPTANCE_PASSWORD="$MUNDA_ACCEPTANCE_PASSWORD" \
          python3 -c 'import json, os; print(json.dumps({"email": os.environ["MUNDA_ACCEPTANCE_EMAIL"], "password": os.environ["MUNDA_ACCEPTANCE_PASSWORD"], "email_confirm": True}))')
    else
        die "jq or python3 is required for safe local auth bootstrap JSON"
    fi
    curl -fsS -o /dev/null -X POST "$url/auth/v1/admin/users" \
      -H "Authorization: Bearer $key" -H "apikey: $key" \
      -H 'Content-Type: application/json' -d "$payload" || true
}

case "${1:-start}" in
    start)
        if [ -f "$ROOT/.env.local" ]; then
            set -a
            . "$ROOT/.env.local"
            set +a
        fi
        install_cli
        (cd "$PROJECT_DIR" && "$CLI" start)
        write_env
        set -a
        . "$ENV_FILE"
        set +a
        # The admin endpoint is idempotent for the intended ephemeral user;
        # a 422 means it already exists and is harmless.
        bootstrap_user
        echo "Local Supabase is ready; credentials written to $ENV_FILE"
        ;;
    status)
        install_cli
        (cd "$PROJECT_DIR" && "$CLI" status)
        ;;
    stop)
        install_cli
        (cd "$PROJECT_DIR" && "$CLI" stop)
        ;;
    reset)
        install_cli
        (cd "$PROJECT_DIR" && "$CLI" db reset)
        write_env
        ;;
    *) die "usage: $0 {start|status|stop|reset}" ;;
esac
