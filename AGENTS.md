# Project guidance

- `vendor/depot` is the upstream Depot repository as a Git submodule. Keep it clean and do not casually advance its gitlink.
- The parent repository owns Docker, Compose, networking, scripts, and integration glue; do not fork or casually modify upstream Depot.
- `data/lists` is an independently versioned private submodule for Ash's durable/exportable rosters and collections. Do not invent army data.
- At the start of substantial work, inspect/fetch the parent and both submodules. Treat submodules as independent repositories.
- Use isolated worktrees for mutating workers and Luna sub-agents first when delegation is requested.
- Never commit credentials, tokens, private keys, or `.env.local`.
- Do not broaden network exposure without explicit intent; avoid wildcard host bindings.
