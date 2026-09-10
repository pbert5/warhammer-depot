import { createServer } from 'node:http';
import { execFile } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { promisify } from 'node:util';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const run = promisify(execFile);
const script = path.resolve('scripts/depot-data-cache.mjs');
const files = [
  'Factions.csv', 'Source.csv', 'Datasheets.csv', 'Datasheets_abilities.csv',
  'Datasheets_keywords.csv', 'Datasheets_models.csv', 'Datasheets_options.csv',
  'Datasheets_wargear.csv', 'Datasheets_unit_composition.csv',
  'Datasheets_models_cost.csv', 'Datasheets_stratagems.csv',
  'Datasheets_enhancements.csv', 'Datasheets_detachment_abilities.csv',
  'Datasheets_leader.csv', 'Stratagems.csv', 'Abilities.csv', 'Enhancements.csv',
  'Detachment_abilities.csv', 'Detachments.csv', 'Detachments_chapter_dp.csv',
  'Last_update.csv'
];

test('refresh swaps only a complete valid snapshot and preserves it on failure', async () => {
  let failName = null;
  const server = createServer((request, response) => {
    const name = path.basename(request.url);
    if (name === failName) { response.writeHead(503); response.end('temporary failure\n'); return; }
    response.writeHead(200, { 'content-type': 'text/csv' });
    response.end('id,name\n1,fixture\n');
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  const base = `http://127.0.0.1:${address.port}/`;
  const root = await mkdtemp(path.join(tmpdir(), 'depot-cache-test-'));
  const cache = path.join(root, 'cache');
  const env = { ...process.env, DEPOT_DATA_CACHE: cache, DEPOT_DATA_BASE_URL: base };
  try {
    await run(process.execPath, [script, '--refresh'], { env });
    const before = await readFile(path.join(cache, 'manifest.json'), 'utf8');
    await run(process.execPath, [script, '--validate'], { env });

    const first = 'factions.csv';
    await writeFile(path.join(cache, first), '<html>tampered</html>\n');
    await assert.rejects(run(process.execPath, [script, '--validate'], { env }));
    await writeFile(path.join(cache, first), 'id,name\n1,fixture\n');

    failName = 'Source.csv';
    await assert.rejects(run(process.execPath, [script, '--refresh'], { env }));
    assert.equal(await readFile(path.join(cache, 'manifest.json'), 'utf8'), before);
    await run(process.execPath, [script, '--validate'], { env });
  } finally {
    server.close();
    await rm(root, { recursive: true, force: true });
  }
});
