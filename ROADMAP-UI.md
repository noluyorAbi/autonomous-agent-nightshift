# Roadmap — Claude-Code-like UI for nightshift

Goal: make the CLI feel like Claude Code with an interactive TUI that shows tasks, context, logs, status, cost, and actions in one screen. Bash-first. No new dependencies. Backwards-compatible with all existing commands.

---

## Scope

### UX goals
- Single-screen TUI for active runs
- Clear progress per task and per validation phase
- Visible cost and iteration budget
- Fast keyboard control (no mouse)
- Safe fallbacks for non-TTY and remote logs

### Non-goals
- Replacing the existing CLI commands
- New runtime dependencies (no ncurses, no node)
- GUI or web UI

---

## Target UI layout

```
┌ nightshift 1.6.x  RUNNING  task 4/18  iter 12/60  cost ~$6.40 ┐
│ Project: /path/to/repo                                    ETA │
├─────────────── Tasks ───────────────┬────────── Logs ─────────┤
│ [x] 01 Fix login redirect            │ 02:14 validate: tsc    │
│ [>] 02 Add dark mode toggle          │ 02:15 validate: eslint │
│ [ ] 03 Update settings page          │ 02:16 ok: tests         │
│ [ ] 04 ...                           │ 02:17 task ok           │
│                                      │ 02:17 next task...      │
├─────────────── Status ───────────────┴────────────────────────┤
│ Phase: Validate   Retries: 2/7   Chrome: off   Max iters: 60  │
│ Last error: tests failed (2 failures)                         │
└───────────────────────────────────────────────────────────────┘
```

---

## Keybindings (proposal)

- `j/k` or `↑/↓`  move selection in task list
- `g/G`           top/bottom
- `p`             pause/resume runner
- `s`             stop runner (confirm)
- `r`             reopen last error details
- `t`             toggle log view (tail vs full)
- `?`             help overlay
- `q`             quit UI (runner continues)

---

## State model

### Files
- `.agent-logs/run_state.json` — current run state
- `.agent-logs/run_events.jsonl` — append-only event stream
- `.agent-logs/summary.log` — human-readable log (already used)

### `run_state.json` (example)
```json
{
  "version": 1,
  "status": "running",
  "cwd": "/path/to/repo",
  "todo_file": "todo-2026_05_28_example.md",
  "task_index": 4,
  "task_total": 18,
  "phase": "validate",
  "iteration": 12,
  "max_iterations": 60,
  "cost_usd_estimate": 6.40,
  "validation": {
    "attempt": 2,
    "max_attempts": 7,
    "last_step": "eslint",
    "last_error": "tests failed (2 failures)"
  },
  "chrome": {
    "enabled": false,
    "attempt": 0,
    "max_attempts": 3
  },
  "updated_at": "2026-05-28T00:12:11Z"
}
```

### `run_events.jsonl` (example)
```json
{"ts":"2026-05-28T00:11:02Z","type":"task_start","task":"02 Add dark mode toggle"}
{"ts":"2026-05-28T00:11:18Z","type":"validate_step","step":"tsc","status":"ok"}
{"ts":"2026-05-28T00:11:44Z","type":"validate_step","step":"eslint","status":"ok"}
{"ts":"2026-05-28T00:12:01Z","type":"validate_step","step":"tests","status":"fail","error":"2 failures"}
{"ts":"2026-05-28T00:12:08Z","type":"task_fail","task":"02 Add dark mode toggle"}
```

---

## Implementation stages

### Stage 1 — UX spec and flows
**Deliverables**
- UI wireframe and layout rules (widths, truncation, colors)
- Keybinding map and help overlay content
- Screen flows: setup, run, review, resume

**Acceptance criteria**
- A single-page spec that is precise enough to implement without guesswork

### Stage 2 — TUI core (bash-first)
**Deliverables**
- `scripts/ui/render.sh` for ANSI drawing
- `scripts/ui/input.sh` for key handling
- `scripts/ui/layout.sh` for pane sizes
- `scripts/ui/colors.sh` for consistent theming

**Acceptance criteria**
- Works on macOS and Linux
- No external dependencies beyond bash, coreutils, git

### Stage 3 — State + events
**Deliverables**
- `run_state.json` schema + writer helpers
- `run_events.jsonl` event emitter
- Update points in `run-agent-loop.sh` to emit events

**Acceptance criteria**
- UI shows current task, phase, and last error within 1 second of change

### Stage 4 — CLI integration
**Deliverables**
- `nightshift ui` command in `bin/nightshift`
- Non-TTY fallback to `nightshift tail`
- Help + USAGE updates

**Acceptance criteria**
- `nightshift ui` works in any repo with an active run
- Zero behavior change to existing commands

### Stage 5 — Quality and release
**Deliverables**
- Golden-output snapshots for key UI states
- Smoke-test: init → start → ui
- Docs + changelog entry

**Acceptance criteria**
- CI green; no regressions in existing lint and smoke tests

---

## Files touched (expected)

- `bin/nightshift` — new `ui` subcommand and help text
- `scripts/run-agent-loop.sh` — emit state + events
- `scripts/start-nightshift.sh` — optional UI launch on start
- `USAGE.md` and README — document the new UI
- New `scripts/ui/*.sh` modules

---

## Definition of done

- UI shows tasks, logs, status, cost, and iteration
- Live runs are controllable (pause/resume/stop)
- Non-TTY fallback works
- Existing CLI flows unchanged
