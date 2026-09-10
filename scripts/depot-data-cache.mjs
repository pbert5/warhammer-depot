#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { promises as fs } from 'node:fs';
import path from 'node:path';

const BASE_URL = process.env.DEPOT_DATA_BASE_URL ?? 'https://wahapedia.ru/wh40k11ed/';
const FILES = [
  'Factions.csv', 'Source.csv', 'Datasheets.csv', 'Datasheets_abilities.csv',
  'Datasheets_keywords.csv', 'Datasheets_models.csv', 'Datasheets_options.csv',
  'Datasheets_wargear.csv', 'Datasheets_unit_composition.csv',
  'Datasheets_models_cost.csv', 'Datasheets_stratagems.csv',
  'Datasheets_enhancements.csv', 'Datasheets_detachment_abilities.csv',
  'Datasheets_leader.csv', 'Stratagems.csv', 'Abilities.csv', 'Enhancements.csv',
  'Detachment_abilities.csv', 'Detachments.csv', 'Detachments_chapter_dp.csv',
  'Last_update.csv'
];
const CACHE_DIR = process.env.DEPOT_DATA_CACHE ?? path.resolve('data/depot-source');
const MANIFEST = 'manifest.json';

const cacheName = (name) => name.toLowerCase().replaceAll('_', '-');
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');
const fail = (message) => { throw new Error(message); };
const validateCsv = (bytes, name) => {
  const text = bytes.toString('utf8');
  if (!text.trim() || text.trimStart().startsWith('<') || !text.includes('\n')) fail(`invalid CSV payload for ${name}`);
};

async function readManifest(dir) {
  let manifest;
  try { manifest = JSON.parse(await fs.readFile(path.join(dir, MANIFEST), 'utf8')); }
  catch { fail(`missing or invalid ${path.join(dir, MANIFEST)}`); }
  if (manifest.schemaVersion !== 1 || manifest.source !== 'wahapedia' || manifest.edition !== 'wh40k11ed') {
    fail(`unsupported cache provenance in ${path.join(dir, MANIFEST)}`);
  }
  if (!Array.isArray(manifest.files) || manifest.files.length !== FILES.length) fail('cache manifest has an incomplete file list');
  const expected = new Set(FILES.map(cacheName));
  const actual = new Set(manifest.files.map((file) => file.path));
  if (actual.size !== expected.size || [...expected].some((name) => !actual.has(name))) fail('cache manifest has an incomplete file list');
  for (const entry of manifest.files) {
    if (!FILES.includes(entry.name) || entry.path !== cacheName(entry.name) || !Number.isInteger(entry.bytes) || entry.bytes <= 0 || !/^[a-f0-9]{64}$/.test(entry.sha256)) fail(`invalid manifest entry for ${entry.path}`);
    const bytes = await fs.readFile(path.join(dir, entry.path));
    if (bytes.length !== entry.bytes || digest(bytes) !== entry.sha256) fail(`cache checksum mismatch for ${entry.path}`);
    validateCsv(bytes, entry.name);
  }
  return manifest;
}

async function validate(dir) {
  const manifest = await readManifest(dir);
  console.log(`Validated ${manifest.files.length} files from ${dir} (fetched ${manifest.fetchedAt})`);
}

async function refresh() {
  const parent = path.dirname(CACHE_DIR);
  await fs.mkdir(parent, { recursive: true });
  const staging = await fs.mkdtemp(path.join(parent, '.depot-source-'));
  try {
    const entries = [];
    for (const name of FILES) {
      const response = await fetch(`${BASE_URL}${name}`);
      if (!response.ok) fail(`download failed for ${name}: HTTP ${response.status}`);
      const bytes = Buffer.from(await response.arrayBuffer());
      validateCsv(bytes, name);
      const relative = cacheName(name);
      await fs.writeFile(path.join(staging, relative), bytes, { flag: 'wx' });
      entries.push({ name, path: relative, url: `${BASE_URL}${name}`, bytes: bytes.length, sha256: digest(bytes) });
    }
    const manifest = {
      schemaVersion: 1,
      source: 'wahapedia',
      edition: 'wh40k11ed',
      fetchedAt: new Date().toISOString(),
      files: entries
    };
    await fs.writeFile(path.join(staging, MANIFEST), `${JSON.stringify(manifest, null, 2)}\n`, { flag: 'wx' });
    await validate(staging);

    const previous = `${CACHE_DIR}.previous`;
    await fs.rm(previous, { recursive: true, force: true });
    try {
      if (await fs.stat(CACHE_DIR).then(() => true).catch(() => false)) await fs.rename(CACHE_DIR, previous);
      await fs.rename(staging, CACHE_DIR);
    } catch (error) {
      try { await fs.rename(previous, CACHE_DIR); } catch {}
      throw error;
    }
    await fs.rm(previous, { recursive: true, force: true });
    console.log(`Refreshed ${CACHE_DIR} with ${entries.length} validated files`);
  } catch (error) {
    await fs.rm(staging, { recursive: true, force: true });
    throw error;
  }
}

const args = process.argv.slice(2);
const mode = args[0] ?? '--validate';
const directory = args[1] ?? CACHE_DIR;
try {
  if (mode === '--refresh') await refresh();
  else if (mode === '--validate') await validate(directory);
  else fail('usage: depot-data-cache.mjs [--validate [DIR] | --refresh]');
} catch (error) {
  console.error(`[depot-data-cache] ${error instanceof Error ? error.message : error}`);
  process.exitCode = 1;
}
