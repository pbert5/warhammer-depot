#!/usr/bin/env node
// Validate the parent parity inventory and its role/status matrix.
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const inventory = readFileSync(join(root, "docs/parity/original-behavior-inventory.md"), "utf8");
const status = readFileSync(join(root, "docs/parity/parity-status.yaml"), "utf8");
const inventoryIds = [...inventory.matchAll(/^\|\s*([A-Z][A-Z0-9-]+)\s*\|/gm)].map((m) => m[1]).filter((id) => id !== "ID");
const statuses = Object.fromEntries([...status.matchAll(/^  ([a-z-]+):\n    owner: [a-z-]+\n    resolved: (true|false)$/gm)].map((m) => [m[1], m[2] === "true"]));
const entries = Object.fromEntries([...status.matchAll(/^  ([A-Z][A-Z0-9-]+): \{status: ([a-z-]+)\}$/gm)].map((m) => [m[1], m[2]]));
const unique = (items) => [...new Set(items)].sort();
const missing = unique(inventoryIds.filter((id) => !(id in entries)));
const extra = unique(Object.keys(entries).filter((id) => !inventoryIds.includes(id)));
const duplicates = unique(inventoryIds.filter((id, i) => inventoryIds.indexOf(id) !== i));
const invalid = Object.entries(entries).filter(([, value]) => !(value in statuses)).map(([id]) => id).sort();
const unresolved = Object.entries(entries).filter(([, value]) => value in statuses && !statuses[value]).map(([id]) => id).sort();
const errors = [];
if (duplicates.length) errors.push(`duplicate inventory IDs: ${duplicates.join(", ")}`);
if (missing.length) errors.push(`missing matrix IDs: ${missing.join(", ")}`);
if (extra.length) errors.push(`matrix IDs not in inventory: ${extra.join(", ")}`);
if (invalid.length) errors.push(`invalid entry statuses: ${invalid.join(", ")}`);
if (unresolved.length) errors.push(`unresolved parity IDs: ${unresolved.join(", ")}`);
if (errors.length) {
  console.error("parity status validation failed:\n- " + errors.join("\n- "));
  process.exitCode = 1;
} else {
  console.log(`parity status valid: ${inventoryIds.length} IDs; all resolved`);
}
