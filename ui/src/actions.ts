// Orchestration layer: the TUI never reimplements runner logic — it spawns the
// real `bin/nightshift` subcommands. bin/nightshift exports its own absolute
// path as NIGHTSHIFT_BIN before launching the bundle; we fall back to the
// `nightshift` on PATH when run directly (e.g. tests).
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';

export function nightshiftBin(): string {
  return process.env['NIGHTSHIFT_BIN'] || 'nightshift';
}

export type CommandKind = 'start' | 'stop' | 'capture' | 'init';

export interface Command {
  id: string;
  label: string;
  desc: string;
  kind: CommandKind;
  needsRun?: boolean; // only meaningful while a run is live
}

// Everything reachable from the command palette.
export const COMMANDS: Command[] = [
  { id: 'start', label: 'start', desc: 'launch the configured run', kind: 'start' },
  { id: 'stop', label: 'stop', desc: 'halt the runner gracefully', kind: 'stop', needsRun: true },
  { id: 'status', label: 'status', desc: 'is it alive? what task?', kind: 'capture' },
  { id: 'review', label: 'review', desc: 'morning report: summary + diff', kind: 'capture' },
  { id: 'resume', label: 'resume', desc: 'diagnose + restart after a stop', kind: 'capture' },
  { id: 'init', label: 'init', desc: 'bootstrap a project (prompts for a name)', kind: 'init' },
  { id: 'bulletproof', label: 'bulletproof', desc: 'branch + commit-per-step PR mode', kind: 'capture' },
  { id: 'version', label: 'version', desc: 'show the CLI version', kind: 'capture' },
];

// Run a subcommand, capturing combined stdout+stderr for an OutputModal.
export function runCapture(
  args: string[],
  cb: (output: string, code: number) => void,
): void {
  const bin = nightshiftBin();
  let out = '';
  let child;
  try {
    child = spawn(bin, args, {
      stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, NO_COLOR: '1' },
    });
  } catch (e) {
    cb(`failed to spawn ${bin}: ${String(e)}`, 1);
    return;
  }
  child.stdout?.on('data', (d) => {
    out += d.toString();
  });
  child.stderr?.on('data', (d) => {
    out += d.toString();
  });
  child.on('error', (e) => cb(`error running ${bin} ${args.join(' ')}: ${String(e)}`, 1));
  child.on('close', (code) => cb(out.trim() || '(no output)', code ?? 0));
}

// Launch a run, fully detached so it outlives the UI process. The poll loop
// then detects runner.pid and flips the UI into the live view.
export function startRun(): { ok: boolean; msg: string } {
  if (!existsSync('start-nightshift.sh')) {
    return { ok: false, msg: 'not initialized — run `init` first' };
  }
  try {
    const child = spawn('bash', ['start-nightshift.sh', 'start'], {
      detached: true,
      stdio: 'ignore',
    });
    child.unref();
    return { ok: true, msg: 'run starting…' };
  } catch (e) {
    return { ok: false, msg: `start failed: ${String(e)}` };
  }
}
