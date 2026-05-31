import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { nightshiftBin, COMMANDS } from '../src/actions.ts';

test('nightshiftBin honors NIGHTSHIFT_BIN, falls back to `nightshift`', () => {
  const prev = process.env['NIGHTSHIFT_BIN'];
  delete process.env['NIGHTSHIFT_BIN'];
  assert.equal(nightshiftBin(), 'nightshift');
  process.env['NIGHTSHIFT_BIN'] = '/abs/bin/nightshift';
  assert.equal(nightshiftBin(), '/abs/bin/nightshift');
  if (prev === undefined) delete process.env['NIGHTSHIFT_BIN'];
  else process.env['NIGHTSHIFT_BIN'] = prev;
});

test('COMMANDS registry has the core commands with correct kinds', () => {
  const byId = Object.fromEntries(COMMANDS.map((c) => [c.id, c]));
  for (const id of ['start', 'stop', 'status', 'review', 'resume', 'init']) {
    assert.ok(byId[id], `missing command: ${id}`);
  }
  assert.equal(byId['start'].kind, 'start');
  assert.equal(byId['stop'].kind, 'stop');
  assert.equal(byId['stop'].needsRun, true);
  assert.equal(byId['init'].kind, 'init');
  assert.equal(byId['status'].kind, 'capture');
});

// The contract that prevents a palette command from spawning a non-existent
// subcommand (which would print "Unknown command"). Every COMMANDS id must be a
// real dispatch case arm in bin/nightshift.
test('every COMMANDS id maps to a real bin/nightshift subcommand', () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const bin = readFileSync(join(here, '..', '..', 'bin', 'nightshift'), 'utf8');
  for (const c of COMMANDS) {
    const esc = c.id.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
    // matches a case arm like `id)` or `id|...)` in the dispatch switch
    const re = new RegExp(`(^|\\s|\\|)${esc}[)|]`, 'm');
    assert.ok(re.test(bin), `COMMANDS id '${c.id}' has no matching subcommand in bin/nightshift`);
  }
});
