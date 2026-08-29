# Warhammer Depot

Private self-hosted deployment of upstream [Depot](https://github.com/fjlaubscher/depot), with Ash's personal Warhammer data kept in a separate private submodule.

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

The Depot submodule tracks upstream at `https://github.com/fjlaubscher/depot.git`. Private lists are maintained at `https://github.com/pbert5/warhammer-lists.git` and are accessed over HTTPS using the GitHub CLI credential helper.

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
# Edit .env.local when the host's Yggdrasil address is known.
docker compose --env-file .env.local build
./scripts/up.sh
./scripts/smoke.sh
```

`up.sh` intentionally does not pass `--build`, so restarts reuse the existing
`warhammer-depot:production` image. Re-run the explicit build command after
changing the pinned source or deployment image.

### Binding and access

Compose's long-form port mapping accepts an IPv6 `host_ip`. Set
`DEPOT_YGGDRASIL_ADDR` to the host's specific Yggdrasil IPv6 address (without
brackets); traffic will then bind only to that address. While it is blank,
Compose uses the documented narrow fallback `127.0.0.1`, making the service
loopback-only rather than exposing it on all interfaces. `DEPOT_PORT` defaults
to `19096`.

Stop the service with:

```sh
./scripts/down.sh
```

### nginx routing

`/data/` is served only when the requested generated file exists and otherwise
returns 404. All other missing paths fall back to `index.html` for React
BrowserRouter direct navigation.
