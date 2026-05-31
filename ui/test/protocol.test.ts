import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  readFileSync,
  existsSync,
  rmSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  loadState,
  readTasks,
  detectSummaryLog,
  detectTaskFile,
  controlSend,
  controlNote,
  tailLines,
  parseTaskNum,
  runnerAlive,
  listTodoFiles,
  isInitialized,
  lastRunSummary,
  CONTROL_FILE,
  PID_FILE,
} from '../src/protocol.ts';

// Make a temp project dir with an empty .agent-logs/, chdir into it, return path.
function fixture(): string {
  const dir = mkdtempSync(join(tmpdir(), 'ns-ui-'));
  process.chdir(dir);
  mkdirSync('.agent-logs', { recursive: true });
  return dir;
}

function mk(d: string): string {
  mkdirSync(d, { recursive: true });
  return d;
}

const STATE = JSON.stringify({
  status: 'running',
  phase: 'validate',
  task_index: 2,
  task_total: 3,
  task_name: 'Add dark mode',
  iteration: 12,
  max_iterations: 250,
  cost_usd_estimate: '4.20',
  validation: { attempt: 1, max_attempts: 7, last_error: 'tests failed' },
  chrome: { enabled: true, attempt: 0, max_attempts: 3 },
  summary_log: '.agent-logs/nightshift-summary.log',
  todo_file: 'todo-test.md',
});

test('loadState parses nested validation + chrome', () => {
  const dir = fixture();
  writeFileSync('.agent-logs/run_state.json', STATE);
  const s = loadState();
  assert.ok(s);
  assert.equal(s!.status, 'running');
  assert.equal(s!.taskIndex, 2);
  assert.equal(s!.taskTotal, 3);
  assert.equal(s!.validationAttempt, 1);
  assert.equal(s!.validationMax, 7);
  assert.equal(s!.lastError, 'tests failed');
  assert.equal(s!.chromeEnabled, true);
  assert.equal(s!.cost, '4.20');
  rmSync(dir, { recursive: true, force: true });
});

test('loadState returns null on missing or malformed json', () => {
  const dir = fixture();
  assert.equal(loadState(), null); // no file yet
  writeFileSync('.agent-logs/run_state.json', '{ not json');
  assert.equal(loadState(), null);
  rmSync(dir, { recursive: true, force: true });
});

test('readTasks parses checkboxes and strips bold', () => {
  const dir = fixture();
  writeFileSync(
    'todo-test.md',
    '- [x] **Task 1: first**\n- [ ] **Task 2: Add dark mode**\n- [ ] Task 3: settings\nnot a task\n',
  );
  const tasks = readTasks('todo-test.md');
  assert.equal(tasks.length, 3);
  assert.equal(tasks[0].box, 'x');
  assert.equal(tasks[0].title, 'Task 1: first');
  assert.equal(tasks[0].num, 1);
  assert.equal(tasks[1].box, ' ');
  assert.equal(tasks[2].num, 3);
  rmSync(dir, { recursive: true, force: true });
});

test('parseTaskNum handles Task and Step', () => {
  assert.equal(parseTaskNum('Task 12: foo'), 12);
  assert.equal(parseTaskNum('Step 3 — bar'), 3);
  assert.equal(parseTaskNum('no number'), null);
});

test('detect* picks state paths then falls back', () => {
  const dir = fixture();
  writeFileSync('.agent-logs/run_state.json', STATE);
  writeFileSync('.agent-logs/nightshift-summary.log', 'x');
  writeFileSync('todo-test.md', '- [ ] **Task 1**\n');
  const s = loadState()!;
  assert.equal(detectSummaryLog(s), '.agent-logs/nightshift-summary.log');
  assert.equal(detectTaskFile(s), 'todo-test.md');
  rmSync(dir, { recursive: true, force: true });
});

test('controlSend and controlNote append the right lines', () => {
  const dir = fixture();
  mk('.agent-logs');
  controlSend('pause');
  controlSend('skip');
  assert.ok(controlNote('please add tests\nand docs'));
  assert.equal(controlNote('   '), false); // empty after trim
  const lines = readFileSync(CONTROL_FILE, 'utf8').trim().split('\n');
  assert.deepEqual(lines, ['pause', 'skip', 'note:please add tests and docs']);
  rmSync(dir, { recursive: true, force: true });
});

test('tailLines returns the last n non-trailing lines', () => {
  const dir = fixture();
  mk('.agent-logs');
  writeFileSync('.agent-logs/x.log', 'a\nb\nc\nd\n');
  assert.deepEqual(tailLines('.agent-logs/x.log', 2), ['c', 'd']);
  assert.deepEqual(tailLines('.agent-logs/missing.log', 5), []);
  rmSync(dir, { recursive: true, force: true });
});

test('CONTROL_FILE path is the shared protocol path', () => {
  assert.equal(CONTROL_FILE, '.agent-logs/ui_control');
  assert.ok(existsSync); // sanity import works
});

test('runnerAlive: false when no pid, true for a live pid, false for a dead one', () => {
  const dir = fixture();
  assert.equal(runnerAlive(), false); // no pid file
  writeFileSync(PID_FILE, String(process.pid)); // this test process — alive
  assert.equal(runnerAlive(), true);
  writeFileSync(PID_FILE, '2147483646'); // implausible pid — not running
  assert.equal(runnerAlive(), false);
  rmSync(dir, { recursive: true, force: true });
});

test('listTodoFiles: counts checkboxes and tags bulletproof', () => {
  const dir = fixture();
  writeFileSync('todo-2026_05_31_a.md', '- [x] **Task 1**\n- [ ] **Task 2**\n');
  writeFileSync('BULLETPROOF-STEPS.md', '- [ ] **Step 1**\n');
  const todos = listTodoFiles();
  const a = todos.find((t) => t.file === 'todo-2026_05_31_a.md')!;
  assert.equal(a.total, 2);
  assert.equal(a.done, 1);
  assert.equal(a.bulletproof, false);
  const bp = todos.find((t) => t.file === 'BULLETPROOF-STEPS.md')!;
  assert.equal(bp.bulletproof, true);
  rmSync(dir, { recursive: true, force: true });
});

test('isInitialized: true only when start-nightshift.sh exists', () => {
  const dir = fixture();
  assert.equal(isInitialized(), false);
  writeFileSync('start-nightshift.sh', '#!/usr/bin/env bash\n');
  assert.equal(isInitialized(), true);
  rmSync(dir, { recursive: true, force: true });
});

test('lastRunSummary: empty for null, descriptive for a state', () => {
  assert.equal(lastRunSummary(null), '');
  const dir = fixture();
  writeFileSync('.agent-logs/run_state.json', STATE);
  const s = loadState();
  const sum = lastRunSummary(s);
  assert.match(sum, /last run: running/);
  assert.match(sum, /task 2\/3/);
  rmSync(dir, { recursive: true, force: true });
});
