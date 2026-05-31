import { useEffect, useRef, useState } from 'react';
import {
  loadState,
  detectSummaryLog,
  detectTaskFile,
  readTasks,
  fileMtimeMs,
  runnerAlive,
  STATE_FILE,
  EVENTS_FILE,
  PID_FILE,
} from './protocol';
import type { RunState, Task } from './types';

export interface RunSnapshot {
  state: RunState | null; // last-good state
  stale: boolean; // state file vanished/unparseable since last good read
  live: boolean; // runner.pid is alive → show the monitor, else the launcher
  tasks: Task[];
  summaryLog: string;
  eventsFile: string;
  pulse: number; // bumps whenever any watched file changes (drives log re-tail)
}

function setInterval_(fn: () => void, ms: number): () => void {
  const id = setInterval(fn, ms);
  return () => clearInterval(id);
}

// Polls the file protocol on an interval and exposes a reactive snapshot.
// Polling (vs fs.watch) is portable across macOS/Linux and matches the bash
// UI's redraw cadence; the files are tiny so the cost is negligible.
export function useRun(intervalMs = 200): RunSnapshot {
  const [snap, setSnap] = useState<RunSnapshot>(() => readOnce(null));
  const lastGood = useRef<RunState | null>(snap.state);
  const sig = useRef<string>('');

  useEffect(() => {
    const tick = () => {
      const next = readOnce(lastGood.current);
      lastGood.current = next.state;
      // Cheap change signature: re-render only when something moved.
      const s = JSON.stringify({
        st: next.state,
        stale: next.stale,
        live: next.live,
        t: next.tasks,
        p: next.pulse,
      });
      if (s !== sig.current) {
        sig.current = s;
        setSnap(next);
      }
    };
    tick();
    return setInterval_(tick, intervalMs);
  }, [intervalMs]);

  return snap;
}

function readOnce(prevGood: RunState | null): RunSnapshot {
  const fresh = loadState();
  const state = fresh ?? prevGood;
  const stale = fresh === null && prevGood !== null;
  const summaryLog = state ? detectSummaryLog(state) : '';
  const taskFile = state ? detectTaskFile(state) : '';
  const tasks = readTasks(taskFile);
  const pulse =
    Math.round(fileMtimeMs(STATE_FILE)) +
    Math.round(fileMtimeMs(EVENTS_FILE)) +
    Math.round(fileMtimeMs(summaryLog)) +
    Math.round(fileMtimeMs(PID_FILE)) +
    Math.round(fileMtimeMs(state?.activeLog ?? ''));
  return {
    state,
    stale,
    live: runnerAlive(),
    tasks,
    summaryLog,
    eventsFile: EVENTS_FILE,
    pulse,
  };
}
