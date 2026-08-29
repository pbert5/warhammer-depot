# Warhammer Depot

Private self-hosted deployment of Ash's [Depot fork](https://github.com/pbert5/depot), with personal Warhammer data kept in a separate private submodule.

This repository is the deployment layer. See `AGENTS.md` for project boundaries and the deployment documentation for the Docker workflow.

## Clone and update

Clone all pinned dependencies with:

```sh
git clone --recurse-submodules https://github.com/pbert5/warhammer-depot.git
```

For an existing checkout, initialize and update the pinned commits with:

```sh
git submodule sync --recursive
git submodule update --init --recursive
```

The Depot submodule tracks Ash's fork at `https://github.com/pbert5/depot.git` (currently the same pinned commit as upstream). Private lists are maintained at `https://github.com/pbert5/warhammer-lists.git` and are accessed over HTTPS using the GitHub CLI credential helper.

## Deployment

The parent repository builds the pinned Depot submodule as a production nginx
image. The image uses Node 24, pnpm 10.20.0, `pnpm install --frozen-lockfile`,
and `pnpm build`. The upstream build generates Wahapedia data and places it in
`packages/web/dist/data`, which is served as static JSON.

### First deployment

The `vendor/depot` submodule must be checked out at the A0-approved commit
`6d424fc55820d773bb20866a999750d9462f16e1` before building. Private
`data/lists` remains a separate submodule and is not copied into the image.

```sh
cp .env.local.example .env.local
# Set DEPOT_TAILSCALE_ADDR to the host's address from `tailscale ip -6`.
docker compose --env-file .env.local build
./scripts/up.sh
./scripts/smoke.sh
```

`up.sh` intentionally does not pass `--build`, so restarts reuse the existing
`warhammer-depot:production` image. Re-run the explicit build command after
changing the pinned source or deployment image.

### Binding and access

Compose publishes the same container port three times: explicitly on
`127.0.0.1`, the host's specific Tailscale IPv4 address, and its specific
Tailscale IPv6 address. Set `DEPOT_TAILSCALE_IPV4_ADDR` from `tailscale ip -4`
and `DEPOT_TAILSCALE_ADDR` from `tailscale ip -6` (without brackets). Compose
refuses to start if either address is not configured, avoiding accidental
wildcard exposure. `DEPOT_PORT` defaults to `19096`.

Stop the service with:

```sh
./scripts/down.sh
```

The supported topology is a small launcher on `19095`, Depot on `19096`, and
Munda Manager on `19097`. Depot's mutable rosters and collections are stored
by its internal Node API in the named `depot-db-data` PostgreSQL volume;
Wahapedia reference data remains generated and static in the Depot web image.
Normal saves never require GitHub or the private lists repository.

Depot portable backups are produced automatically under the ignored
`runtime/backups/depot/` bind mount. Run `./scripts/backup-depot.sh` for an
explicit JSON snapshot and `./scripts/backup-postgres.sh` for a custom-format
database dump. Restore SQL dumps only after review with
`./scripts/restore-postgres.sh path/to/file.dump`.

JSON is the canonical versioned `depot-user-data` format (format version 1);
the API also exports/imports the same bundle as safe YAML. Existing
`depot-offline` IndexedDB roster and collection stores are retained as a
recovery source and copied once the API is available; the migration marker is
stored in IndexedDB and no old data is deleted automatically.

Munda Manager is pinned as `vendor/mundamanager` and remains on its own
Supabase/Postgres schema. `./scripts/up.sh` downloads the pinned Supabase CLI
release (with a checksum), starts the checked-in local project and seed files,
generates an ignored runtime credential file, builds Munda with the current
public anon key, and starts the application. The browser uses the restricted
`http://localhost:54321` gateway; container-side server calls use Docker's
`host.docker.internal` route. Set `MUNDA_ACCEPTANCE_EMAIL` and
`MUNDA_ACCEPTANCE_PASSWORD` in `.env.local` only when an ephemeral local test
user should be created automatically. Local email confirmation is disabled in
the CLI project only. No SES, Discord, or hosted webhook is required.

Use `./scripts/down.sh` to stop both stacks while retaining their volumes.
`RESET_MUNDA_LOCAL_CONFIRM=RESET ./scripts/reset-munda-local.sh` is the
explicit destructive local database reset. The committed placeholder
Turnstile values are only for private local development; production auth
semantics remain unchanged.

The application ports are published only on `127.0.0.1`, the configured
Tailscale IPv4, and the configured Tailscale IPv6. PostgreSQL and the Depot
API are internal Compose services and are not published to the host.

### nginx routing

`/data/` is served only when the requested generated file exists and otherwise
returns 404. All other missing paths fall back to `index.html` for React
BrowserRouter direct navigation.
