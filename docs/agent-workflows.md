# Agent workflows

`AGENTS.md` is the shared authority for all coding agents. Provider files are
adapters: Codex uses `.codex/`, Claude Code uses `.claude/`, and neither may
define a competing ownership model.

## Standing roles

| Role | Responsibility | Mutation |
| --- | --- | --- |
| repo-scout | map ownership, state, instructions, tests, and execution paths | read-only |
| frontend-ui | Depot catalogue UI, responsive behavior, accessibility | scoped source |
| persistence-data | Depot API/Postgres, imports/exports, migrations, fixtures | scoped source |
| compose-runtime | Dockerfiles, Compose, health, test/browser runtime | runtime files |
| browser-acceptance | DevTools navigation, DOM, styles, console, network, screenshots, interactions | read-only initially |
| test-verifier | Compose unit/type/build/Playwright execution and classification | read-only |
| integration-reviewer | gitlinks, boundaries, Compose, security and architecture | read-only |
| docs-maintainer | README, operator and agent workflow documentation | docs |

The lead is scheduler and integrator. A typical DAG is scout -> shared
contract -> provider/runtime adapters -> acceptance and regression -> final
integration review. Dispatch independent READY nodes continuously; a blocked
node does not stop unrelated work. Mutating workers use isolated worktrees.
Workers return changed files, exact commands, evidence, classification, and
bounded handoffs. Repository-owned failures enter a repair wave: capture,
classify, create a READY repair task, assign the owner, rerun the focused
check, reintegrate, and repeat final acceptance.

Only the compose-runtime owner restarts or destructively resets the canonical
parent Compose environment during acceptance. Browser workers use disposable
browser containers and unique fixture IDs.

## Canonical commands

```bash
# Parent integrated topology
docker compose up -d
docker compose run --rm --no-deps -T chrome-devtools-mcp

# Depot standalone and deterministic checks
docker compose up -d --build
docker compose --profile test run --rm depot-test pnpm test
docker compose --profile test run --rm depot-test pnpm typecheck
docker compose --profile test run --rm depot-test pnpm build
docker compose --profile test run --rm depot-test pnpm --filter @depot/web test:e2e

# Munda standalone
docker compose -f compose.standalone.yaml up -d --build
docker compose -f compose.standalone.yaml run --rm --no-deps -T chrome-devtools-mcp
```

Browser agents use service DNS for integrated checks and published front doors
for final acceptance. Inspect launcher, Depot, and Munda at desktop, 390x844,
and 360px-wide views; verify catalogue search/filter/sort/state/navigation,
focus, overflow, console, and failed requests. Chrome DevTools MCP is the
primary interactive path; Playwright is deterministic regression coverage.

Failure classes are: PRODUCT REGRESSION, STALE TEST CONTRACT, TEST HARNESS
DEFECT, MCP INTEGRATION DEFECT, COMPOSE TOPOLOGY DEFECT, AUTH/SESSION SETUP,
SCHEMA/FIXTURE MISMATCH, EXTERNAL ENVIRONMENT, UNKNOWN. Missing host tooling
is not an external blocker.
