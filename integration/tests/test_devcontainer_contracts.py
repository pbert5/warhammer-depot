import json
from pathlib import Path


ROOT = Path(__file__).parents[2]


def config():
    return json.loads((ROOT / ".devcontainer/devcontainer.json").read_text())


def test_node_compose_and_workspace_contract():
    cfg = config()
    assert cfg["remoteUser"] == "node"
    assert cfg["workspaceFolder"] == "/workspaces/warhammer-depot"
    assert "docker-outside-of-docker" in " ".join(cfg["features"])
    mounts = "\n".join(cfg["mounts"])
    assert "/var/run/docker.sock" in mounts
    assert "warhammer-codex" in mounts and "pnpm-store" in mounts
    dockerfile = (ROOT / ".devcontainer/Dockerfile").read_text()
    assert "FROM node:24" in dockerfile
    assert "corepack prepare pnpm@10.20.0" in dockerfile
    for tool in ("rtk", "codex", "openssh-client", "jq", "yq", "lazygit"):
        assert tool in dockerfile or tool in (ROOT / ".devcontainer/scripts/bootstrap-devcontainer").read_text()


def test_bootstrap_is_explicit_idempotent_and_non_destructive():
    script = (ROOT / ".devcontainer/scripts/bootstrap-devcontainer").read_text()
    assert "git submodule sync --recursive" in script
    assert "git submodule update --init --recursive" in script
    assert "pnpm --dir vendor/depot --version" in script
    assert "git reset" not in script and "git checkout" not in script
    assert "docker compose version" in script
    assert "WARHAMMER_INSTALL_DEPS" in script


def test_compose_remains_the_application_authority():
    text = (ROOT / "compose.yaml").read_text()
    assert "depot-db:" in text and "depot-api:" in text and "depot-web:" in text
    assert "chrome-devtools-mcp:" in text
    assert "host_ip: \"127.0.0.1\"" in text
