import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const doctor = await readFile(new URL("scripts/codex-doctor.sh", root), "utf8");

test("doctor is repository-owned and non-destructive", () => {
  assert.match(doctor, /^#!\/usr\/bin\/env bash/);
  assert.doesNotMatch(doctor, /git reset|git checkout/);
  assert.match(doctor, /docker compose/);
  assert.match(doctor, /chrome-devtools-mcp/);
  assert.match(doctor, /SUMMARY PASS=/);
});

test("doctor covers canonical agents and plugin", () => {
  for (const required of [
    ".codex/config.toml",
    ".codex/agents/test-architect.toml",
    ".codex/agents/recovery-adviser.toml",
    ".agents/plugins/marketplace.json",
    "max_concurrent_threads_per_session",
  ]) {
    assert.match(doctor, new RegExp(required.replaceAll(".", "\\.")));
  }
});
