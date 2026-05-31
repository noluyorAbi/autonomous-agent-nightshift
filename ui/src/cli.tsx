#!/usr/bin/env node
import { render } from 'ink';
import { existsSync, statSync } from 'node:fs';
import { App } from './components/App';
import { LOG_DIR } from './protocol';

const HELP = `nightshift ui — interactive dashboard for a live nightshift run

Usage: nightshift ui [DIR]
       nightshift ui --attach DIR

  DIR            project dir to watch (defaults to the current directory)
  --attach DIR   same as DIR; watch a run in another repo
  -C DIR         same as --attach
  -h, --help     show this help

Keys: i message agent · p pause · r resume · n skip · s/x stop · K force-kill
      j/k move · t toggle logs · ? help · q quit
`;

function resolveTarget(argv: string[]): string {
  let dir = '';
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--attach' || a === '-C') {
      dir = argv[i + 1] ?? '';
      i++;
    } else if (a.startsWith('--attach=')) {
      dir = a.slice('--attach='.length);
    } else if (a === '-h' || a === '--help') {
      process.stdout.write(HELP);
      process.exit(0);
    } else if (a === '--selftest') {
      // handled by caller
    } else if (!a.startsWith('-') && !dir) {
      dir = a;
    }
  }
  return dir;
}

function isDir(p: string): boolean {
  try {
    return statSync(p).isDirectory();
  } catch {
    return false;
  }
}

const argv = process.argv.slice(2);
const selftest = argv.includes('--selftest') || process.env['NIGHTSHIFT_UI_SELFTEST'];

const dir = resolveTarget(argv);
if (dir) {
  if (!isDir(dir)) {
    process.stderr.write(`error: attach dir not found: ${dir}\n`);
    process.exit(1);
  }
  process.chdir(dir);
}

if (!existsSync(LOG_DIR)) {
  process.stderr.write(
    `No ${LOG_DIR} in ${process.cwd()} — run \`nightshift start\` first.\n`,
  );
  process.exit(1);
}

if (selftest) {
  // CI smoke: render one frame to stdout (no raw mode) and exit.
  const { unmount } = render(<App inputActive={false} />, { patchConsole: false });
  setTimeout(() => {
    unmount();
    process.exit(0);
  }, 200);
} else if (!process.stdout.isTTY) {
  process.stdout.write('Non-TTY detected. Use: nightshift tail\n');
  process.exit(0);
} else {
  render(<App />);
}
