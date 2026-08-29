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
