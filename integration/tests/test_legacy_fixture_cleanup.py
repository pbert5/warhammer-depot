from pathlib import Path


ROOT = Path(__file__).parents[2]
SCRIPT = (ROOT / "scripts/cleanup-legacy-depot-fixtures.sh").read_text()


def test_cleanup_defaults_to_dry_run_and_requires_backup_for_apply():
    assert "mode=dry-run" in SCRIPT
    assert "--apply" in SCRIPT
    assert "--backup-evidence" in SCRIPT
    assert "Refusing --apply without --backup-evidence PATH" in SCRIPT
    assert "[ -s \"$backup_evidence\" ]" in SCRIPT


def test_selector_keeps_exact_generated_prefixes_and_document_timestamp_evidence():
    for prefix in (
        "E2E Roster",
        "E2E Collection",
        "E2E Collection Roster",
        "Astra Militarum E2E",
    ):
        assert prefix in SCRIPT
    assert "[0-9]{13}" in SCRIPT
    assert "document->>'id' = id" in SCRIPT
    assert "document->>'name' = name" in SCRIPT
    assert "document->>'factionId' = faction_id" in SCRIPT
    assert "created_at" in SCRIPT and "updated_at" in SCRIPT
    assert "Everything else is intentionally ambiguous and is retained." in SCRIPT


def test_cleanup_never_deletes_users_and_uses_a_transaction():
    assert "DELETE FROM users" not in SCRIPT
    assert "BEGIN;" in SCRIPT
    assert "COMMIT;" in SCRIPT
    assert "DELETE FROM rosters" in SCRIPT
    assert "DELETE FROM collections" in SCRIPT


def test_cleanup_uses_canonical_compose_project_resolution():
    assert '. "$ROOT/scripts/compose-common.sh"' in SCRIPT
    assert 'load_compose_environment "$ROOT"' in SCRIPT
    assert "project=${COMPOSE_PROJECT_NAME:-warhammer}" in SCRIPT
    assert "warhammer|warhammer-*" in SCRIPT
    assert 'export COMPOSE_PROJECT_NAME="$project"' in SCRIPT
    assert "--project-name" not in SCRIPT


def test_postcondition_wraps_bare_selector_without_ordering_or_semicolon():
    selector = SCRIPT.split("selector=$(cat <<'SQL'\n", 1)[1].split("\nSQL\n)", 1)[0]
    assert "ORDER BY" not in selector
    assert not selector.rstrip().endswith(";")
    assert 'SELECT count(*) FROM ( $selector ) AS remaining;' in SCRIPT
    assert '"$selector ORDER BY kind, created_at, id;"' in SCRIPT
