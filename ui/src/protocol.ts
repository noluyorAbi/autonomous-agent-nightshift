// The file protocol layer: everything the TUI reads from / writes to the
// .agent-logs/ directory. This mirrors the bash UI (scripts/nightshift-ui.sh)
// exactly so the two are interchangeable clients of the same runner.
//
// All paths are relative to the current working directory; cli.tsx chdir's into
// the target project first (honoring `--attach DIR`), so the same relative
// paths resolve there.
import {
  existsSync,
  readFileSync,
  appendFileSync,
  readdirSync,
  statSync,
} from 'node:fs';
import { execFileSync } from 'node:child_process';
import type { RunState, Task, TaskBox } from './types';

export const LOG_DIR = '.agent-logs';
export const STATE_FILE = `${LOG_DIR}/run_state.json`;
export const EVENTS_FILE = `${LOG_DIR}/run_events.jsonl`;
export const PID_FILE = `${LOG_DIR}/runner.pid`;
export const CONTROL_FILE = `${LOG_DIR}/ui_control`;

const EMPTY_STATE: RunState = {
  status: '',
  phase: '',
  taskIndex: 0,
  taskTotal: 0,
  taskName: '',
  iteration: 0,
  maxIterations: 0,
  cost: '',
  lastError: '',
  validationAttempt: 0,
  validationMax: 0,
  chromeEnabled: false,
  chromeAttempt: 0,
  chromeMax: 0,
  summaryLog: '',
  todoFile: '',
  planFile: '',
  activeLog: '',
};

function num(v: unknown): number {
  const n = typeof v === 'string' ? parseInt(v, 10) : (v as number);
  return Number.isFinite(n) ? n : 0;
}

function str(v: unknown): string {
  if (v === null || v === undefined) return '';
  return String(v);
}

// Parse run_state.json. Returns null when the file is absent or unparseable so
// the caller can keep the last-good state and flag it stale.
export function loadState(): RunState | null {
  if (!existsSync(STATE_FILE)) return null;
  let raw: string;
  try {
    raw = readFileSync(STATE_FILE, 'utf8');
  } catch {
    return null;
  }
  let d: Record<string, unknown>;
  try {
    d = JSON.parse(raw);
  } catch {
    return null; // mid-write; keep last good
  }
  const v = (d['validation'] ?? {}) as Record<string, unknown>;
  const c = (d['chrome'] ?? {}) as Record<string, unknown>;
  return {
    ...EMPTY_STATE,
    status: str(d['status']),
    phase: str(d['phase']),
    taskIndex: num(d['task_index']),
    taskTotal: num(d['task_total']),
    taskName: str(d['task_name']),
    iteration: num(d['iteration']),
    maxIterations: num(d['max_iterations']),
    cost: str(d['cost_usd_estimate']),
    lastError: str(v['last_error']),
    validationAttempt: num(v['attempt']),
    validationMax: num(v['max_attempts']),
    chromeEnabled: c['enabled'] === true || c['enabled'] === 'true',
    chromeAttempt: num(c['attempt']),
    chromeMax: num(c['max_attempts']),
    summaryLog: str(d['summary_log']),
    todoFile: str(d['todo_file']),
    planFile: str(d['plan_file']),
    activeLog: str(d['active_log']),
  };
}

// Pick the human-readable summary log, mirroring bash detect_files().
export function detectSummaryLog(state: RunState): string {
  if (state.summaryLog && existsSync(state.summaryLog)) return state.summaryLog;
  if (existsSync(`${LOG_DIR}/nightshift-summary.log`))
    return `${LOG_DIR}/nightshift-summary.log`;
  if (existsSync(`${LOG_DIR}/bulletproof-summary.log`))
    return `${LOG_DIR}/bulletproof-summary.log`;
  return '';
}

// Pick the task/step markdown file, mirroring bash detect_files().
export function detectTaskFile(state: RunState): string {
  if (state.todoFile && existsSync(state.todoFile)) return state.todoFile;
  if (state.planFile && existsSync(state.planFile)) return state.planFile;
  try {
    const todo = readdirSync('.')
      .filter((f) => /^todo-.*\.md$/.test(f))
      .sort()[0];
    if (todo) return todo;
  } catch {
    /* ignore */
  }
  if (existsSync('BULLETPROOF-STEPS.md')) return 'BULLETPROOF-STEPS.md';
  return '';
}

const TASK_LINE = /^- \[([ xX])\] (.*)$/;

export function readTasks(taskFile: string): Task[] {
  if (!taskFile || !existsSync(taskFile)) return [];
  let lines: string[];
  try {
    lines = readFileSync(taskFile, 'utf8').split('\n');
  } catch {
    return [];
  }
  const tasks: Task[] = [];
  for (const line of lines) {
    const m = TASK_LINE.exec(line);
    if (!m) continue;
    const box: TaskBox = m[1] === ' ' ? ' ' : 'x';
    const title = m[2].replace(/\*\*/g, '');
    tasks.push({ box, title, num: parseTaskNum(title) });
  }
  return tasks;
}

export function parseTaskNum(title: string): number | null {
  const m = /(Task|Step)\s+(\d+)/.exec(title);
  return m ? parseInt(m[2], 10) : null;
}

// Tail the last n lines of a text file. Cheap full-read is fine for these logs.
export function tailLines(path: string, n: number): string[] {
  if (!path || !existsSync(path)) return [];
  try {
    const all = readFileSync(path, 'utf8').split('\n');
    if (all.length && all[all.length - 1] === '') all.pop();
    return all.slice(-n);
  } catch {
    return [];
  }
}

export function fileMtimeMs(path: string): number {
  try {
    return statSync(path).mtimeMs;
  } catch {
    return 0;
  }
}

// ---- Writers: the only mutations the UI makes (the control channel) ----

export function controlSend(cmd: string): void {
  try {
    appendFileSync(CONTROL_FILE, `${cmd}\n`);
  } catch {
    /* best effort */
  }
}

export function controlNote(text: string): boolean {
  const t = text.replace(/\n/g, ' ').trim();
  if (!t) return false;
  try {
    appendFileSync(CONTROL_FILE, `note:${t}\n`);
    return true;
  } catch {
    return false;
  }
}

export function forceKillRunner(): string {
  if (!existsSync(PID_FILE)) return 'no runner pid';
  let pid = 0;
  try {
    pid = parseInt(readFileSync(PID_FILE, 'utf8').trim(), 10);
  } catch {
    return 'no runner pid';
  }
  if (!pid) return 'no runner pid';
  try {
    process.kill(pid, 0); // probe
  } catch {
    return 'runner not running';
  }
  try {
    process.kill(pid, 'SIGTERM');
  } catch {
    /* ignore */
  }
  return `force-killed runner ${pid}`;
}

// ---- git commit preview for a finished task (parity with bash UI) ----

export function findTaskCommit(taskNum: number): string {
  try {
    const out = execFileSync(
      'git',
      [
        'log',
        '--all',
        '--pretty=%H',
        '-n',
        '1',
        `--grep=(task-${taskNum}):\\|(step-${taskNum}):`,
      ],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] },
    );
    return out.trim().split('\n')[0] ?? '';
  } catch {
    return '';
  }
}

export function buildCommitPreview(sha: string): string[] {
  if (!sha) return [];
  try {
    const head = execFileSync(
      'git',
      [
        'show',
        '-s',
        '--pretty=%h · %an · %ad · %s',
        '--date=format:%H:%M:%S',
        sha,
      ],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] },
    ).trim();
    const stat = execFileSync(
      'git',
      ['show', '--stat', '--format=', sha],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] },
    )
      .split('\n')
      .filter((l) => l.trim() !== '');
    return [head, ...stat];
  } catch {
    return [];
  }
}

// ---- Control-center helpers (home vs live, launcher) ----

// A run is "live" when runner.pid exists and that process is alive.
export function runnerAlive(): boolean {
  if (!existsSync(PID_FILE)) return false;
  let pid = 0;
  try {
    pid = parseInt(readFileSync(PID_FILE, 'utf8').trim(), 10);
  } catch {
    return false;
  }
  if (!pid) return false;
  try {
    process.kill(pid, 0); // probe; throws if not running / not permitted
    return true;
  } catch (e) {
    // EPERM means the process exists but we can't signal it — still alive.
    return (e as NodeJS.ErrnoException).code === 'EPERM';
  }
}

export interface TodoFileInfo {
  file: string;
  total: number;
  done: number;
  bulletproof: boolean;
}

// List runnable task files in the cwd with their checkbox counts.
export function listTodoFiles(): TodoFileInfo[] {
  const out: TodoFileInfo[] = [];
  let names: string[] = [];
  try {
    names = readdirSync('.')
      .filter((f) => /^todo-.*\.md$/.test(f))
      .sort();
  } catch {
    /* ignore */
  }
  if (existsSync('BULLETPROOF-STEPS.md')) names.push('BULLETPROOF-STEPS.md');
  for (const f of names) {
    const tasks = readTasks(f);
    out.push({
      file: f,
      total: tasks.length,
      done: tasks.filter((t) => t.box === 'x').length,
      bulletproof: f === 'BULLETPROOF-STEPS.md',
    });
  }
  return out;
}

// Has `nightshift init` been run here? (start-nightshift.sh is the marker.)
export function isInitialized(): boolean {
  return existsSync('start-nightshift.sh');
}

// One-line summary of the most recent run from state, or '' when none.
export function lastRunSummary(state: RunState | null): string {
  if (!state || !state.status) return '';
  const idx = state.taskIndex || 0;
  const total = state.taskTotal || 0;
  const where = total ? ` · task ${idx}/${total}` : '';
  const cost = state.cost ? ` · ~$${state.cost}` : '';
  return `last run: ${state.status}${where}${cost}`;
}
