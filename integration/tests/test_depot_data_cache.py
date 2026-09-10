from pathlib import Path
import json

ROOT = Path(__file__).parents[2]
SCRIPT = (ROOT / "scripts/depot-data-cache.mjs").read_text()
DOCKERFILE = (ROOT / "Dockerfile").read_text()
COMPOSE = (ROOT / "compose.yaml").read_text()


def test_cache_contract_is_parent_owned_and_seeded_before_build():
    assert "data/depot-source/" in DOCKERFILE
    assert "--validate /src/vendor/depot/packages/cli/dist/source_data" in DOCKERFILE
    assert "vendor/depot/packages/cli/dist/source_data" in DOCKERFILE
    assert "vendor/depot" not in SCRIPT
    assert "./data/depot-source:/app/packages/cli/dist/source_data:ro" in COMPOSE


def test_cache_validator_requires_complete_hashed_provenance():
    assert "manifest.schemaVersion !== 1" in SCRIPT
    assert "manifest.files.length !== FILES.length" in SCRIPT
    assert "digest(bytes) !== entry.sha256" in SCRIPT
    assert "fetchedAt" in SCRIPT and "url" in SCRIPT


def test_refresh_is_explicit_and_compose_hosted():
    assert 'profiles: ["data"]' in COMPOSE
    assert 'user: "${DEPOT_DATA_UID:-1000}:${DEPOT_DATA_GID:-100}"' in COMPOSE
    assert '"--refresh"' in COMPOSE
    assert "depot-data-test:" in COMPOSE
    assert "await response.arrayBuffer()" in SCRIPT
    assert "await fs.rename(staging, CACHE_DIR)" in SCRIPT


def test_cache_manifest_has_expected_shape_when_present():
    manifest_path = ROOT / "data/depot-source/manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        assert manifest["schemaVersion"] == 1
        assert len(manifest["files"]) == 21
