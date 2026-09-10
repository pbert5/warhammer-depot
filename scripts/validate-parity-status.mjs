#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const inventory = readFileSync(join(root, "docs/parity/original-behavior-inventory.md"), "utf8");
const status = readFileSync(join(root, "docs/parity/parity-status.yaml"), "utf8");
const inventoryIds = [...inventory.matchAll(/^\|\s*([A-Z][A-Z0-9-]+)\s*\|/gm)].map((m) => m[1]).filter((id) => id !== "ID");
const lines = status.split("\n").filter((line) => /^  [A-Z][A-Z0-9-]+: \{/.test(line));
const entries = new Map();
for (const line of lines) {
  const match = line.match(/^  ([A-Z][A-Z0-9-]+): \{(.*)\}$/);
  if (!match) continue;
  const fields = Object.fromEntries([...match[2].matchAll(/(\w+):\s*("[^"]*"|null|[^,}]+)/g)].map((m) => [m[1], m[2].replace(/^"|"$/g, "").trim()]));
  entries.set(match[1], fields);
}
const errors = [];
const duplicates = inventoryIds.filter((id, i) => inventoryIds.indexOf(id) !== i);
const missing = inventoryIds.filter((id) => !entries.has(id));
const extra = [...entries.keys()].filter((id) => !inventoryIds.includes(id));
if (duplicates.length) errors.push(`duplicate inventory IDs: ${[...new Set(duplicates)].join(", ")}`);
if (missing.length) errors.push(`missing matrix IDs: ${missing.join(", ")}`);
if (extra.length) errors.push(`matrix IDs not in inventory: ${extra.join(", ")}`);
for (const [id, fields] of entries) {
  for (const key of ["oracle_tests", "oracle_result", "candidate_tests", "candidate_result", "classification", "repair_commit", "override", "final_status"]) {
    if (!(key in fields)) errors.push(`${id} missing ${key}`);
  }
  if (fields.final_status !== "closed") errors.push(`${id} is not closed`);
  if (fields.oracle_result !== "pass") errors.push(`${id} oracle result is not pass`);
  if (fields.candidate_result !== "pass") errors.push(`${id} candidate result is not pass`);
  if (fields.override && fields.override !== "null" && (!inventoryIds.includes(id) || fields.override.length < 8)) errors.push(`${id} has an invalid override`);
}
if (errors.length) {
  console.error("parity status validation failed:\n- " + errors.join("\n- "));
  process.exitCode = 1;
} else {
  const total = inventoryIds.length;
  const oracle = [...entries.values()].filter((e) => e.oracle_result === "pass").length;
  const candidate = [...entries.values()].filter((e) => e.candidate_result === "pass").length;
  const divergences = [...entries.values()].filter((e) => e.override && e.override !== "null").length;
  console.log(`total IDs: ${total}`);
  console.log(`oracle proven: ${oracle}`);
  console.log(`candidate passing: ${candidate}`);
  console.log(`approved divergences: ${divergences}`);
  console.log("unresolved: 0");
}
