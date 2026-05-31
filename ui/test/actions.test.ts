import { test } from 'node:test';
import assert from 'node:assert/strict';
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

test('COMMANDS registry covers the core subcommands with correct kinds', () => {
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
