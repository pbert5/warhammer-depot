#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$ROOT" || ! -f "$ROOT/AGENTS.md" ]]; then
  printf 'FAIL repository: run from the Warhammer checkout\n'
  exit 1
fi
cd "$ROOT"

pass=0
warn=0
fail=0
pass_check() { printf 'PASS %-12s %s\n' "$1" "$2"; pass=$((pass + 1)); }
warn_check() { printf 'WARN %-12s %s\n' "$1" "$2"; warn=$((warn + 1)); }
fail_check() { printf 'FAIL %-12s %s\n' "$1" "$2"; fail=$((fail + 1)); }
command_check() {
  local name=$1 command=$2
  if command -v "$command" >/dev/null 2>&1; then
    pass_check "$name" "$("$command" --version 2>&1 | head -n 1)"
  else
    warn_check "$name" "not available in this shell; use the Dev Container/Compose authority"
  fi
}

printf 'Warhammer Codex doctor (%s)\n' "$ROOT"
branch=$(git branch --show-current)
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo '<none>')
[[ "$branch" == main ]] && pass_check repository "branch main" || warn_check repository "branch $branch (canonical branch is main)"
[[ "$upstream" == origin/main ]] && pass_check upstream "$upstream" || warn_check upstream "$upstream (expected origin/main)"
if git diff --quiet && git diff --cached --quiet && [[ -z "$(git status --porcelain --untracked-files=all)" ]]; then
  pass_check cleanliness clean
else
  warn_check cleanliness "local WIP or preserved submodule state exists"
fi
if git submodule status --recursive | awk '$1 ~ /^[-+]/ {bad=1} END {exit bad}'; then
  pass_check submodules "initialized at recorded commits"
else
  fail_check submodules "one or more submodules are unavailable or differ from the gitlink"
fi

command_check node node
command_check pnpm pnpm
command_check docker docker
if docker compose version >/dev/null 2>&1; then pass_check compose "$(docker compose version)"; else warn_check compose 'Docker Compose unavailable'; fi
command_check rtk rtk
command_check codex codex
command_check git git

if [[ -f .codex/config.toml ]] && rg -q '^enabled = true' .codex/config.toml; then
  pass_check agents 'Codex multi-agent mode enabled'
else
  fail_check agents 'missing or disabled .codex/config.toml agents section'
fi
if rg -q 'max_concurrent_threads_per_session = [1-9]' .codex/config.toml; then
  pass_check concurrency "$(rg 'max_concurrent_threads_per_session' .codex/config.toml | head -n 1 | tr -d '\r')"
else
  warn_check concurrency 'configured concurrency not found'
fi
for agent in .codex/agents/test-architect.toml .codex/agents/recovery-adviser.toml; do
  [[ -f "$agent" ]] && pass_check agent "$(basename "$agent") present" || fail_check agent "missing $agent"
done

if [[ -f .agents/plugins/marketplace.json && -f .agents/plugins/warhammer-chrome-devtools/.codex-plugin/plugin.json ]]; then
  pass_check plugin 'repository marketplace and Chrome plugin discovered'
else
  fail_check plugin 'repository Chrome plugin files are incomplete'
fi
if DEPOT_POSTGRES_PASSWORD=codex-doctor \
  DEPOT_TAILSCALE_IPV4_ADDR=127.0.0.1 DEPOT_TAILSCALE_ADDR=::1 \
  docker compose --profile development-tools config --services 2>/dev/null | rg -qx chrome-devtools-mcp; then
  pass_check mcp-service 'chrome-devtools-mcp is in Compose topology'
else
  warn_check mcp-service 'Compose service could not be rendered (check .env.local)'
fi

if [[ -f scripts/codex-doctor.test.mjs ]]; then
  if node --test scripts/codex-doctor.test.mjs >/dev/null 2>&1; then
    pass_check focused-test 'doctor contract test passed'
  else
    warn_check focused-test 'pytest unavailable or doctor contract test failed'
  fi
else
  warn_check focused-test 'doctor contract test is not present'
fi

if [[ "${CODEX_DOCTOR_MCP:-0}" == 1 ]]; then
  if ! command -v docker >/dev/null 2>&1 || ! DEPOT_POSTGRES_PASSWORD=codex-doctor \
    DEPOT_TAILSCALE_IPV4_ADDR=127.0.0.1 DEPOT_TAILSCALE_ADDR=::1 \
    docker compose --profile development-tools config --services >/dev/null 2>&1; then
    warn_check mcp 'skipped; Docker Compose topology is unavailable'
  elif ! docker image inspect warhammer-chrome-devtools-mcp >/dev/null 2>&1; then
    warn_check mcp 'skipped; image is not built'
  else
    probe=$(
      (printf '%s\n' \
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"codex-doctor","version":"1"}}}' \
        '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
        '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'; sleep 2) |
        timeout 20s env DEPOT_POSTGRES_PASSWORD=codex-doctor \
          DEPOT_TAILSCALE_IPV4_ADDR=127.0.0.1 DEPOT_TAILSCALE_ADDR=::1 \
          docker compose --profile development-tools run --rm --no-deps -T chrome-devtools-mcp 2>/dev/null || true
    )
    if rg -q '"serverInfo"' <<<"$probe" && rg -q '"tools"' <<<"$probe"; then
      pass_check mcp 'initialize and tools/list succeeded'
    else
      warn_check mcp 'transport did not complete initialize/tools/list'
    fi
  fi
else
  warn_check mcp 'not exercised; set CODEX_DOCTOR_MCP=1 for initialize/tools/list'
fi

printf 'SUMMARY PASS=%d WARN=%d FAIL=%d\n' "$pass" "$warn" "$fail"
(( fail == 0 ))
