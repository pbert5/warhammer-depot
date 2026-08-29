# Project guidance

- `vendor/depot` is the upstream Depot repository as a Git submodule. Keep it clean and do not casually advance its gitlink.
- The parent repository owns Docker, Compose, networking, scripts, and integration glue; do not fork or casually modify upstream Depot.
- `data/lists` is an independently versioned private submodule for Ash's durable/exportable rosters and collections. Do not invent army data.
- At the start of substantial work, inspect/fetch the parent and both submodules. Treat submodules as independent repositories.
- Use isolated worktrees for mutating workers and Luna sub-agents first when delegation is requested.
- Never commit credentials, tokens, private keys, or `.env.local`.
- Do not broaden network exposure without explicit intent; avoid wildcard host bindings.

## Shared agent and Compose contract

- Sub-agent delegation is the default for substantial work. The lead schedules an explicit dependency DAG, dispatches READY work continuously, integrates green checkpoints, and uses isolated worktrees for mutating workers.
- Blockers do not halt unrelated READY work. Prefer a bounded repair or review worker before the lead takes over. Keep checkpoints pushed frequently and preserve concurrent branches.
- `docker compose` is the development, runtime, build, test, and acceptance authority. Do not require host Node, pnpm, browsers, PostgreSQL clients, local servers, or DevTools installations.
- Browser-visible work uses the disposable Compose-hosted Chrome DevTools MCP. Bring up the relevant deployed topology, inspect DOM/styles/console/network and interactions at desktop and narrow widths, run deterministic tests through Compose, then perform final front-door acceptance.
- The browser service uses stdio MCP and container-local CDP only; never publish port 9222 or attach to a personal browser. Do not put secrets in screenshots or logs.
- Use `gpt-5.6-luna` as the Codex repository-agent default: low for scouts/docs/mechanical checks and medium for implementation, acceptance, integration, and debugging. Do not use Terra by default.

See [docs/agent-workflows.md](docs/agent-workflows.md) for role contracts, dependency examples, repair loop, and canonical commands.
