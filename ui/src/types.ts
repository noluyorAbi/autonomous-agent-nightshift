// Shape of .agent-logs/run_state.json as written by the bash runners.
// Everything is optional/defensive: the UI must never crash on a partial or
// mid-write state file.
export interface RunState {
  status: string; // running | paused | stopped | completed | starting | ...
  phase: string;
  taskIndex: number;
  taskTotal: number;
  taskName: string;
  iteration: number;
  maxIterations: number;
  cost: string; // free-form (e.g. "6.40" or "")
  lastError: string;
  validationAttempt: number;
  validationMax: number;
  chromeEnabled: boolean;
  chromeAttempt: number;
  chromeMax: number;
  summaryLog: string;
  todoFile: string;
  planFile: string;
  activeLog: string; // current task's live claude logfile (Milestone 2)
}

export type TaskBox = ' ' | 'x';

export interface Task {
  box: TaskBox; // ' ' open, 'x' done
  title: string;
  num: number | null; // parsed "Task N" / "Step N"
}

export type LogMode = 'summary' | 'events';
export type Mode = 'nav' | 'input';
