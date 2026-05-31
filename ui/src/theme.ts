// Semantic palette. Ink colors flow through chalk, which auto-disables when
// NO_COLOR is set or stdout is not a TTY, so we don't strip colors by hand.
export const theme = {
  accent: 'cyan',
  accentBright: 'cyanBright',
  ok: 'green',
  warn: 'yellow',
  err: 'red',
  muted: 'gray',
  magenta: 'magenta',
} as const;

// status -> badge background + label (Claude-Code-style pill)
export function statusBadge(status: string): {
  label: string;
  bg: string;
  fg: string;
} {
  switch (status) {
    case 'running':
      return { label: 'RUNNING', bg: 'green', fg: 'black' };
    case 'paused':
      return { label: 'PAUSED', bg: 'yellow', fg: 'black' };
    case 'stopped':
      return { label: 'STOPPED', bg: 'red', fg: 'white' };
    case 'completed':
      return { label: 'DONE', bg: 'blue', fg: 'white' };
    case 'starting':
      return { label: 'STARTING', bg: 'cyan', fg: 'black' };
    default:
      return { label: (status || 'unknown').toUpperCase(), bg: 'gray', fg: 'black' };
  }
}

export function progressBar(cur: number, total: number, width: number): string {
  const t = total > 0 ? total : 1;
  const c = Math.max(0, Math.min(cur, t));
  const filled = Math.floor((c * width) / t);
  return '█'.repeat(filled) + '░'.repeat(Math.max(0, width - filled));
}
