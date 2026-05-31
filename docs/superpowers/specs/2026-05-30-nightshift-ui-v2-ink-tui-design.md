# Design — `nightshift ui` v2: Claude-Code-grade Ink TUI

- **Date:** 2026-05-30
- **Status:** Approved (design); pending implementation plan
- **Author:** brainstormed with the maintainer
- **Branch:** `feat/ui-v2-ink`
- **Supersedes:** the bash ANSI dashboard (`scripts/nightshift-ui.sh`, shipped in v1.6.0/v1.7.0) — kept as a fallback, not deleted

---

## 1. Motivation

The maintainer wants `nightshift ui` to feel like Claude Code: a polished, interactive
terminal UI where you watch progress live AND write to the running agent. The current
dashboard is hand-rolled bash + ANSI escape codes. That approach has a hard quality
ceiling and, by the maintainer's own account, the raw terminal-code/command handling is
hard to follow and extend. Pushing bash ANSI further makes the code worse, not better.

Claude Code itself is not bash — it is a real TUI framework (Ink/React on Node). To reach
that bar we adopt the same class of tooling.

**Decisions locked during brainstorming:**

- Tech stack: **Node + Ink (React for terminals)** — matches Claude Code 1:1 and rides the
  project's primary `npm install -g` distribution channel.
- Upgrades in scope (all selected): **live agent stream**, **scrollable logs + diff viewer**,
  **richer messaging (multiline + history + delivery ack)**, **mouse + live metrics**.
- Existing parity features (task list, pause/resume/skip/stop, status, commit preview,
  message bar, `--attach`) are preserved.

---

## 2. Goals / Non-goals

### Goals

- A Claude-Code-grade interactive TUI for a live nightshift run.
- Watch the agent work in real time (live output stream), not just a summary log.
- Two-way: message the agent, pause/resume/skip/stop, with visible delivery acknowledgement.
- Scrollable + searchable logs; syntax-highlighted, scrollable diff per task.
- Mouse support and live cost/token/ETA metrics.
- Zero change to the bash runner's behavior or contract; the UI is a drop-in client.
- `npm install -g` works instantly with no build step and no `node_modules` install.

### Non-goals

- Replacing or rewriting the bash runners. They remain the engine.
- A web or desktop GUI.
- Removing the bash UI — it becomes the no-Node fallback.
- New dependencies in the **bash** harness. (Node deps for the UI are expected and bundled.)

---

## 3. Constraints

- The **bash harness stays dependency-free** (bash, `claude`, `gh`, `git`, `python3`).
  This is unchanged. The Ink app is a separate component; its npm deps are **bundled into a
  single self-contained JS file** and never required at the bash layer.
- Cross-platform: macOS + Linux. No reliance on BSD-only or GNU-only tools in the UI.
- Backwards compatible: every existing `nightshift` command behaves exactly as before.
- Cost-cap awareness is unaffected — the UI never calls `claude`; it only reads files and
  writes the cooperative control channel.

---

## 4. Architecture

### 4.1 Separation of concerns

```
 bash runner (engine, unchanged)
   │  writes
   ▼
 .agent-logs/                          ← the contract (already exists)
   ├─ run_state.json      current run state (status, task, phase, cost, …)
   ├─ run_events.jsonl    append-only event stream
   ├─ <per-task>.log      live `claude -p` output (tee'd, line 583 of runner)
   ├─ ui_control          UI → runner commands (pause|resume|skip|stop|note:…)
   └─ ui_notes            queued operator notes
   ▲  reads / tails                              │ writes ui_control, ui_notes
   │                                             ▼
 Ink TUI  (ui/dist/cli.js, new)  ◄──────────────┘
```

The Ink app is a near-read-only client. The **only** thing it writes is the existing
control channel — identical to what the bash UI writes today. This means the protocol test
(`scripts/test-ui-control.sh`) continues to guard the runner side unchanged.

### 4.2 Location and language

- New top-level directory **`ui/`** (TypeScript). `site/` remains the landing page.
- Build: **esbuild** bundles `ui/src/cli.tsx` + all npm deps into one file `ui/dist/cli.js`
  (Node shebang, executable). No `node_modules` ships or installs.

### 4.3 Distribution

- **Prebuilt bundle.** `ui/dist/cli.js` is built in CI and published in the npm package and
  the release tarball. `npm install -g` is instant and offline-safe; no postinstall build.
- **Dispatch.** `bin/nightshift ui` resolves: if `node` is on PATH and `ui/dist/cli.js`
  exists, exec `node "$ROOT/ui/dist/cli.js" "$@"`; otherwise fall back to
  `scripts/nightshift-ui.sh "$@"` (the bash "lite" UI). All args (`--attach DIR`, positional
  DIR, `-h`) are forwarded to whichever runs.
- The bash UI is retained and keeps passing its tests; it is the graceful degradation path
  for Homebrew/curl installs without Node.

### 4.4 Minimal additive runner change

To power the live stream, the UI needs the path of the **current** task's claude logfile.
Both runners already compute a per-task logfile and `tee` claude output to it. The change:
publish that path into `run_state.json` as `active_log` (and clear/refresh it per task).
This is a one-field, additive change in `run-agent-loop.sh` and `nightshift-bulletproof.sh`;
the bash UI ignores the field, so nothing breaks.

---

## 5. Components (Ink)

### Hooks (data layer)

- `useRunState()` — watches `run_state.json` (poll mtime ~150–250ms; the bash UI already uses
  a similar cadence). Parses to a typed `RunState`. Keeps last-good on parse error and exposes
  a `stale` flag.
- `useEventLog()` — incremental tail of `run_events.jsonl` by byte offset; exposes a typed
  event list (used for the Log pane and for the delivery-ack signal).
- `useAgentStream()` — follows `run_state.active_log`; exposes the live output lines; resets
  when the active task changes.
- `useGitDiff(sha)` — lazily runs `git show`/`git diff` for the selected task's commit;
  syntax-highlights via a bundled highlighter. Cached per sha.

### View components

- `<Header>` — title, status badge (RUNNING/PAUSED/STOPPED/DONE), progress bar, iter counter,
  cost + ETA + tok/s sparkline.
- `<TaskList>` — left pane; `✓ / ▸ / ·` task states; keyboard- and mouse-selectable; scrolls.
- `<MainPane>` — tabbed:
  - **Stream** — live agent output (`useAgentStream`), autoscroll with a "follow" toggle.
  - **Log** — scrollable summary/events with `/` search + level/event filter.
  - **Diff** — syntax-highlighted, scrollable diff for the selected task's commit.
- `<StatusBar>` — phase, validation attempt, chrome, last error, last action.
- `<MessageBar>` — multiline compose; sent-note history; `delivered ✓` when an `operator_note`
  event appears after the send timestamp.
- `<Help>` — keybinding overlay.

### Root

- `<App>` — wires hooks → state, owns focus/pane/tab state, routes keyboard + mouse, renders
  the layout with responsive flexbox (Ink `<Box>`), honors `NO_COLOR` and terminal resize.

---

## 6. Layout

```
╭─ nightshift · RUNNING ───────────────────────── task 4/18 · iter 12/60 ─╮
│  ████████████░░░░░░░░  ~$6.40 · ~38m left · tok/s ▁▂▃▅▇                  │
├──────────────────────┬──────────────────────────────────────────────────┤
│ TASKS                │  ◉ Stream   ○ Log   ○ Diff           [ / search]  │
│ ✓ 01 Fix login       │  › Reading src/auth/login.ts …                    │
│ ✓ 02 Dark mode       │  › Found redirect bug @ line 42. Patching.        │
│ ▸ 03 Settings page   │  › tsc … ok                                       │
│   04 Profile API     │  › tests … 2 failed, retrying                     │
│   05 …               │  ▌ live ▌                                         │
├──────────────────────┴──────────────────────────────────────────────────┤
│ phase validate · val 2/7 · chrome off · last: tests failed (2)           │
│ › message the agent…                                       delivered ✓   │
╰───────────────────────────────────────────────────────────────────────────╯
 i msg · p pause · r resume · n skip · s stop · ⇥ pane · / search · ? help
```

- Responsive: left pane width clamps; main pane flexes; degrades gracefully on narrow/short
  terminals (min sizes, then hides sparkline/labels first).
- Claude-Code aesthetic: rounded borders, dim/accent palette, spinner during active calls.

---

## 7. Keybindings + mouse

- `i` or `/`(when not searching) — open message compose; `Enter` send, `Esc` cancel,
  multiline via `Shift+Enter` (or `Alt+Enter` fallback).
- `p` pause · `r` resume · `n` skip · `s`/`x` stop · `K` force-kill (last resort).
- `Tab` cycle main-pane tabs (Stream/Log/Diff); `j/k`/arrows move selection; `g/G` top/bottom;
  `/` search within Log pane; `f` toggle stream follow.
- `?` help overlay · `q` quit (run continues).
- **Mouse:** enable SGR 1006; click a task to select, click a tab to switch, wheel to scroll
  the focused pane. Mouse is additive — keyboard remains fully sufficient.

---

## 8. Messaging + delivery acknowledgement

The runner emits an `operator_note` event (via `emit_event`) when `consume_notes` folds a note
into the next prompt. The UI: on send, append `note:<text>` to `ui_control` and mark the note
**queued** with a timestamp; when an `operator_note` event with a later timestamp appears in
`run_events.jsonl`, flip it to **delivered ✓**. If the run stops first, the runner's
`operator_note_unsent` event (added in v1.7.0) lets the UI show **not delivered (run stopped)**.

---

## 9. Error handling / edge cases

- **No Node / no bundle** → bash fallback (see 4.3).
- **No `.agent-logs/`** → friendly "no active run — `nightshift start` first" screen, not a crash.
- **Malformed `run_state.json`** → keep last-good state, show a `stale` indicator.
- **Missing `active_log`** → Stream tab shows "waiting for agent output…".
- **No commit yet for a task** → Diff tab shows "no commit for this task".
- **Terminal resize** → re-layout on `SIGWINCH`; restore cursor/raw mode + disable mouse on exit
  (and on `SIGINT`/`SIGTERM`).
- **`--attach DIR`** → resolve and watch that repo's `.agent-logs/`, same as today.

---

## 10. Build + distribution details

- `ui/package.json` with `react`, `ink`, and supporting `ink-*` libs + a syntax highlighter,
  all **bundled** by esbuild into `ui/dist/cli.js`.
- `ui/dist/cli.js` is committed/published so installs need no build; CI rebuilds and verifies it
  is in sync with source (fail CI if `dist` is stale).
- `package.json` `files` includes `ui/dist`. `release.yml` includes `ui/dist` in the tarball.
- `.github/workflows/` gains a `ui-build` job: install, typecheck, unit-test, build, drift-check.

---

## 11. Testing

- **Bash side unchanged:** `scripts/test-ui-control.sh` keeps guarding the runner protocol
  (30 assertions today).
- **Node side:** unit tests with `ink-testing-library` rendering components to strings against a
  temp `.agent-logs/` fixture: state parsing/stale handling, event tailing by offset, stream
  follow, diff rendering, and the queued→delivered ack transition.
- **Integration smoke:** render one frame headless (a `--selftest` flag mirroring the bash UI's
  `NIGHTSHIFT_UI_SELFTEST`) and assert key regions, wired into CI.
- **Fallback:** a CI check that `bin/nightshift ui` selects bash when `node` is masked from PATH.

---

## 12. Phasing (each milestone shippable)

1. **Parity + plumbing.** `ui/` scaffold, esbuild bundle, `bin/nightshift` dispatch + bash
   fallback, CI `ui-build` job, and `<Header>/<TaskList>/<Log>/<StatusBar>/<MessageBar>` at
   feature parity with today's bash UI (incl. control writes + `--attach`).
2. **Live agent stream.** Runner publishes `active_log`; `useAgentStream` + Stream tab.
3. **Diff + scrollback.** Diff tab (`useGitDiff` + highlighting); Log scrollback + `/` search.
4. **Richer messaging.** Multiline compose, note history, queued→delivered ack.
5. **Mouse + metrics + polish.** SGR mouse, cost/token/ETA sparklines, resize/aesthetic polish.

Acceptance for each milestone is "CI green + the milestone's surface works in a real run, with
the bash fallback intact." Milestone 1 alone is a safe replacement of the current UI.

---

## 13. Files touched (expected)

- **New:** `ui/` (package.json, tsconfig, src/*.tsx, esbuild config), `ui/dist/cli.js` (built).
- **Modified (additive):** `bin/nightshift` (ui dispatch + fallback); both runners
  (`run-agent-loop.sh`, `nightshift-bulletproof.sh`) publish `active_log`; `package.json`
  (`files`, version); `.github/workflows/lint.yml` or a new `ui.yml` (build job); `release.yml`
  (tarball includes `ui/dist`); docs (`README.md`, `USAGE.md`, `ROADMAP-UI.md`, `CHANGELOG.md`).
- **Retained:** `scripts/nightshift-ui.sh` (fallback) and `scripts/test-ui-control.sh`.

---

## 14. Open questions (non-blocking)

- Exact syntax-highlight lib for the Diff pane (pick smallest that bundles cleanly).
- Whether to expose tok/s if token accounting isn't emitted yet — Milestone 5 may show cost+ETA
  first and add tok/s when the runner emits tokens.

These do not block Milestones 1–4 and will be resolved in the implementation plan.
