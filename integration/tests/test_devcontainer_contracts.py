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
    assert (ROOT / ".devcontainer/scripts/codex-doctor").exists()


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
    assert 'DEPOT_USER_ID: "${DEPOT_USER_ID:-00000000-0000-0000-0000-000000000001}"' in text


def test_e2e_topology_is_namespaced_and_loopback_only():
    text = (ROOT / "compose.e2e.yaml").read_text()
    assert "depot-e2e-db-data" in text
    assert text.count('host_ip: "127.0.0.1"') == 3
    assert "tailscale" not in text.lower()
    assert "depot-e2e-bootstrap:" in text
    assert "service_completed_successfully" in text
    assert "WARHAMMER_E2E_PARENT_USER_ID" in text


def test_e2e_identity_and_purge_guards_are_explicit():
    env = (ROOT / ".env.e2e.example").read_text()
    e2e = (ROOT / "scripts/e2e.sh").read_text()
    purge = (ROOT / "scripts/purge-e2e.sh").read_text()
    assert "WARHAMMER_E2E_PARENT_USER_ID" in env
    assert "00000000-0000-0000-0000-000000000002" in env
    assert "00000000-0000-0000-0000-000000000001" not in env
    assert "COMPOSE_PROJECT_NAME" in e2e and "warhammer-e2e" in e2e
    assert "--apply" in purge and "warhammer-e2e" in purge
    assert "Dry run" in purge
    assert "SELECT 'roster' AS kind" in purge
    assert "BEGIN; DELETE FROM rosters WHERE user_id" in purge
    assert "COMMIT;" in purge
    assert "Purge postcondition failed" in purge
    assert "down --volumes" not in purge
