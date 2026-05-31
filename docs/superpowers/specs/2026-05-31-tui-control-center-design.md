# Design — TUI as default + full control center (addendum)

- **Date:** 2026-05-31
- **Status:** Approved; extends `2026-05-30-nightshift-ui-v2-ink-tui-design.md`
- **Ships as:** 1.9.0

## Goal

Make `nightshift ui` the default entry point and a full control center: every
`bin/nightshift` subcommand is reachable from inside the TUI, and the TUI no
longer requires an already-running run.

## Decisions (approved)

- Bare `nightshift` in a TTY launches the TUI. Non-TTY (pipes/scripts/CI) and
  `nightshift help` print help. All subcommands unchanged.
- The TUI is a thin orchestration layer: it **spawns the real `bin/nightshift`
  subcommands** (passed in via `NIGHTSHIFT_BIN`), never reimplementing runner
  logic. Reuse the tested bash machinery.
- Ship as 1.9.0 (new feature).

## States

- **home** — no live runner. Shows project + branch + last-run summary, the
  detected todo/plan files (with task counts + done state), and actions. This is
  also the bare-`nightshift` landing screen.
- **live** — runner pid alive. The existing monitor + steer view (Header /
  TaskList / log / StatusBar / MessageBar + pause/resume/skip/stop/message).
- Done/stopped folds into **home** (last-run summary + review/resume/restart).

`runnerAlive()` = `runner.pid` exists and `process.kill(pid, 0)` succeeds. The
poll loop flips home↔live automatically as a run starts/ends.

## Actions

Home actions and a command palette (`:`) expose all commands:

| Command | How it runs |
|---------|-------------|
| start | spawn detached `NIGHTSHIFT_BIN start` in cwd → transition to live |
| stop | write `stop` to ui_control (live) or `NIGHTSHIFT_BIN stop` |
| status / review / version | spawn, capture stdout, show in a scrollable OutputModal |
| resume | spawn `NIGHTSHIFT_BIN resume` → output modal / live |
| init | prompt for a name in the TUI, spawn `NIGHTSHIFT_BIN init <name>` |
| tail | not needed inside the TUI (the log pane *is* the tail) — palette hint |
| bulletproof / debug | advanced; spawn, capture output → modal |

Spawning is `child_process.spawn`. `start` uses `{ detached: true, stdio:
'ignore' }` and `unref()` so the runner outlives the action. Output commands
capture stdout/stderr and render in a modal the user dismisses with `q`/Esc.

`NIGHTSHIFT_BIN`: `bin/nightshift` exports its own absolute path before exec'ing
the node bundle. If unset (node run directly), the TUI falls back to `nightshift`
on PATH, then to `./start-nightshift.sh` for start/stop.

## New / changed files

- `bin/nightshift` — bare-arg dispatch (TTY → ui), `cmd_ui` exports `NIGHTSHIFT_BIN`.
- `ui/src/cli.tsx` — no longer exits on missing `.agent-logs/`; renders the App
  (which picks home vs live).
- `ui/src/protocol.ts` — `runnerAlive()`, `listTodoFiles()` (+ task counts),
  `isInitialized()`, `lastRunSummary()`.
- `ui/src/actions.ts` (new) — `spawnDetached`, `runCapture`, command registry.
- `ui/src/components/Home.tsx`, `CommandPalette.tsx`, `OutputModal.tsx` (new).
- `ui/src/components/App.tsx` — home/live state machine, palette + modal overlays.
- Tests for the new protocol helpers + the home selftest frame.

## Acceptance

- Bare `nightshift` (TTY) opens the home screen; non-TTY prints help.
- From home: start a run (goes live), review/status in a modal, init a project.
- From the palette: every listed command runs.
- Live view unchanged. Bash fallback stays monitor-only.
- CI green; npm package still installs + runs.
