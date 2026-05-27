# Roadmap — Claude-Code-like UI for nightshift

Goal: make the CLI feel like Claude Code with an interactive TUI that shows tasks, context, logs, status, cost, and actions in a single screen. Bash-first. No new dependencies.

---

## Stage plan (implementation)

1. **UX target and flows**
   - Define screens: setup, run, review, resume
   - Decide keybindings and help overlay
   - Sketch the layout: header, task list, log pane, status pane
2. **TUI core**
   - ANSI screen renderer (clear + redraw)
   - Pane layout (split view with consistent widths)
   - Input loop (non-blocking reads)
   - Log streaming and color rules
3. **State and events**
   - Define `run_state.json` schema
   - Emit events: task_start, task_ok, task_fail, validation_*
   - Persist and reload state in the runner
4. **CLI integration**
   - Add `nightshift ui` command (opt-in)
   - Fallback to `nightshift tail` in non-TTY
   - Keep existing commands unchanged
5. **Quality and release**
   - TUI snapshot tests (golden outputs)
   - Smoke-test: init → start → ui
   - Docs, changelog, version bump, release

---

## Milestones

### Milestone 0 — UX target
- [ ] UI spec: screens and flows (setup/run/review/resume)
- [ ] Keybindings and help overlay
- [ ] Layout map: header, task list, logs, status

### Milestone 1 — TUI core (bash-first)
- [ ] Screen renderer (ANSI clear + redraw)
- [ ] Pane layout (split: tasks | logs | status)
- [ ] Input loop (non-blocking key reads)
- [ ] Log streaming (tail + color rules)

### Milestone 2 — State + events
- [ ] `run_state.json` schema
- [ ] Events: task_start/task_ok/task_fail/validation_*
- [ ] Persistence in `run-agent-loop.sh`
- [ ] UI adapter: state → view

### Milestone 3 — Commands + compatibility
- [ ] `nightshift ui` command
- [ ] Non‑TTY fallback to `nightshift tail`
- [ ] CLI help and USAGE updates
- [ ] No breaking changes

### Milestone 4 — Tests + release
- [ ] TUI snapshot tests (golden output)
- [ ] Smoke-test: init → start → ui
- [ ] Release notes + changelog
- [ ] Version bump + tag + publish

---

## Definition of done

- UI shows tasks, logs, status, cost, and current iteration
- Live runs are controllable (pause/resume/stop)
- Existing CLI flows keep working unchanged
