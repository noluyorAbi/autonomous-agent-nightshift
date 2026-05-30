#!/usr/bin/env bash
# ============================================================================
# Integration test for the nightshift ui <-> runner control protocol.
#   - the TUI renders a frame from run_state.json without a TTY
#   - nav keys write the right commands into .agent-logs/ui_control
#   - the runner drains those commands (pause/resume/skip/stop)
#   - operator notes round-trip into the prompt and are then cleared
#   - skip flips the first open checkbox to done
# No network, no claude calls. Safe to run in CI.
# ============================================================================
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI="$REPO/scripts/nightshift-ui.sh"
RUNNER="$REPO/scripts/run-agent-loop.sh"

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); echo "  ok   $1"; }
bad() { FAIL=$((FAIL + 1)); echo "  FAIL $1"; }

WORK="$(mktemp -d)"
cd "$WORK" || exit 1

mkdir -p .agent-logs
cat > .agent-logs/run_state.json <<'JSON'
{ "version":1,"status":"running","phase":"validate","task_index":2,"task_total":3,
  "task_name":"Add dark mode","iteration":12,"max_iterations":250,"cost_usd_estimate":"4.20",
  "validation":{"attempt":1,"max_attempts":7,"last_error":"tests failed"},
  "chrome":{"enabled":true,"attempt":0,"max_attempts":3},
  "summary_log":".agent-logs/nightshift-summary.log","todo_file":"todo-test.md" }
JSON
cat > .agent-logs/nightshift-summary.log <<'LOG'
[t] STARTED: Task 2
[t] validate tsc ok
LOG
cat > todo-test.md <<'MD'
- [x] **Task 1: first**
- [ ] **Task 2: Add dark mode**
- [ ] **Task 3: settings**
MD

echo "== renderer =="
out="$(NIGHTSHIFT_UI_SELFTEST=1 NO_COLOR=1 bash "$UI" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "ui renders (exit 0)" || bad "ui render exit $rc"
printf '%s' "$out" | grep -q "RUNNING"      && ok "shows status badge"   || bad "no status badge"
printf '%s' "$out" | grep -q "Add dark mode" && ok "shows current task"   || bad "no task shown"
printf '%s' "$out" | grep -q "phase"         && ok "shows status footer"  || bad "no footer"

echo "== nav keys write control commands =="
: > .agent-logs/ui_control
NIGHTSHIFT_UI_SELFTEST=p NO_COLOR=1 bash "$UI" >/dev/null 2>&1
grep -qx "pause" .agent-logs/ui_control && ok "p -> pause" || bad "p did not write pause"
NIGHTSHIFT_UI_SELFTEST=r NO_COLOR=1 bash "$UI" >/dev/null 2>&1
grep -qx "resume" .agent-logs/ui_control && ok "r -> resume" || bad "r did not write resume"
NIGHTSHIFT_UI_SELFTEST=n NO_COLOR=1 bash "$UI" >/dev/null 2>&1
grep -qx "skip" .agent-logs/ui_control && ok "n -> skip" || bad "n did not write skip"
NIGHTSHIFT_UI_SELFTEST=s NO_COLOR=1 bash "$UI" >/dev/null 2>&1
grep -qx "stop" .agent-logs/ui_control && ok "s -> stop" || bad "s did not write stop"

echo "== runner drains control commands =="
: > .agent-logs/ui_control
# shellcheck disable=SC1090
NIGHTSHIFT_LIB_ONLY=1 source "$RUNNER"
set +e
# These feed the sourced runner functions; shellcheck can't see that use.
# shellcheck disable=SC2034
TODO_FILE="$WORK/todo-test.md"

CONTROL_PAUSE=0; CONTROL_SKIP=0; CONTROL_STOP=0
printf 'pause\nnote:please also add unit tests\nskip\n' >> "$CONTROL_FILE"
control_drain
[ "$CONTROL_PAUSE" = "1" ] && ok "drain sets pause" || bad "pause not set"
[ "$CONTROL_SKIP" = "1" ]  && ok "drain sets skip"  || bad "skip not set"
[ -f "$NOTES_FILE" ] && grep -q "please also add unit tests" "$NOTES_FILE" \
    && ok "note queued to notes file" || bad "note not queued"
[ -f "$CONTROL_FILE" ] && bad "control file not drained" || ok "control file drained"

printf 'stop\n' >> "$CONTROL_FILE"
control_drain
[ "$CONTROL_STOP" = "1" ] && ok "drain sets stop" || bad "stop not set"

echo "== operator notes round-trip into prompt =="
notes="$(consume_notes)"
printf '%s' "$notes" | grep -q "please also add unit tests" && ok "consume returns note text" || bad "note text missing"
printf '%s' "$notes" | grep -q "LIVE OPERATOR NOTES" && ok "note wrapped in prompt section" || bad "no prompt section header"
printf '%s' "$notes" | grep -qi "injected into next" && bad "log line leaked into prompt" || ok "no log leakage in prompt"
[ ! -f "$NOTES_FILE" ] && ok "notes cleared after consume" || bad "notes not cleared"
[ -z "$(consume_notes)" ] && ok "second consume is empty" || bad "second consume not empty"

echo "== operator note left at stop is preserved in the log (not lost) =="
# Regression: a note queued in the same drain as `stop` used to vanish because
# maybe_graceful_stop exited before consume_notes ran. flush_pending_notes_to_log
# must record it to the summary + event log on shutdown.
rm -f "$NOTES_FILE"
printf 'note:dont forget the migration\nstop\n' >> "$CONTROL_FILE"
control_drain
flush_pending_notes_to_log
grep -q "dont forget the migration" .agent-logs/nightshift-summary.log \
    && ok "unsent note recorded in summary on stop" || bad "note lost on stop (summary)"
grep -q "operator_note_unsent" .agent-logs/run_events.jsonl \
    && ok "unsent note emitted as event" || bad "note lost on stop (events)"
[ ! -f "$NOTES_FILE" ] && ok "notes file cleared after stop-flush" || bad "notes file lingered after flush"

echo "== skip marks the first open task =="
mark_task_skipped
grep -q "SKIPPED (operator)" todo-test.md && ok "skip appends marker" || bad "no skip marker"
grep -q "^- \[x\] \*\*Task 2" todo-test.md && ok "task 2 flipped to done" || bad "task 2 not flipped"
grep -q "^- \[ \] \*\*Task 3" todo-test.md && ok "task 3 left untouched" || bad "task 3 changed"

echo "== ui input handler (type / backspace / send / cancel) =="
(
    cd "$WORK" || exit 9
    : > .agent-logs/ui_control
    # shellcheck disable=SC1090
    NIGHTSHIFT_UI_LIB_ONLY=1 source "$UI"
    set +e
    MODE="input"; INPUT_BUFFER=""
    handle_input_key "h" 0
    handle_input_key "e" 0
    handle_input_key "l" 0
    handle_input_key "l" 0
    handle_input_key "o" 0
    [ "$INPUT_BUFFER" = "hello" ] || exit 11
    handle_input_key $'\x7f' 0
    [ "$INPUT_BUFFER" = "hell" ] || exit 12
    handle_input_key " " 0
    handle_input_key "w" 0
    [ "$INPUT_BUFFER" = "hell w" ] || exit 13
    handle_input_key "" 0
    [ "$MODE" = "nav" ] || exit 14
    [ -z "$INPUT_BUFFER" ] || exit 15
    grep -qx "note:hell w" .agent-logs/ui_control || exit 16
    MODE="input"; INPUT_BUFFER="draft"
    : > .agent-logs/ui_control
    handle_input_key $'\x1b' 0
    [ "$MODE" = "nav" ] || exit 17
    [ -z "$INPUT_BUFFER" ] || exit 18
    [ -s .agent-logs/ui_control ] && exit 19
    exit 0
)
rc=$?
[ "$rc" -eq 0 ] && ok "input handler types/edits/sends/cancels" || bad "input handler rc=$rc"

echo "== ui nav handler (direct dispatch) =="
(
    cd "$WORK" || exit 9
    : > .agent-logs/ui_control
    # shellcheck disable=SC1090
    NIGHTSHIFT_UI_LIB_ONLY=1 source "$UI"
    set +e
    handle_nav_key "p"
    handle_nav_key "r"
    handle_nav_key "n"
    handle_nav_key "s"
    grep -qx "pause"  .agent-logs/ui_control || exit 21
    grep -qx "resume" .agent-logs/ui_control || exit 22
    grep -qx "skip"   .agent-logs/ui_control || exit 23
    grep -qx "stop"   .agent-logs/ui_control || exit 24
    handle_nav_key "q" && exit 25
    exit 0
)
rc=$?
[ "$rc" -eq 0 ] && ok "nav handler dispatches every key" || bad "nav handler rc=$rc"

echo "== right pane shows the commit for a selected done task =="
PREV="$(mktemp -d)"
(
    cd "$PREV" || exit 30
    git init -q
    git config user.email t@t
    git config user.name t
    mkdir -p .agent-logs
    cat > .agent-logs/run_state.json <<'JSON'
{"status":"running","phase":"loop","task_index":1,"task_total":2,"task_name":"Fix login","iteration":3,"max_iterations":9,"cost_usd_estimate":"","validation":{"attempt":0,"max_attempts":7,"last_error":""},"chrome":{"enabled":false,"attempt":0,"max_attempts":3},"todo_file":"todo.md"}
JSON
    printf -- '- [x] **Task 1: Fix login redirect**\n- [ ] **Task 2: Settings**\n' > todo.md
    echo "old" > src.ts
    git add -A && git commit -q -m "init"
    echo "new" > src.ts
    git add -A && git commit -q -m "feat(task-1): Fix login redirect

Implemented auth guard."
    out="$(NIGHTSHIFT_UI_SELFTEST=1 NO_COLOR=1 bash "$UI" 2>&1)"
    printf '%s' "$out" | grep -q "COMMIT " || exit 31
    printf '%s' "$out" | grep -q "feat(task-1)" || exit 32
    printf '%s' "$out" | grep -q "src.ts" || exit 33
    # Also: selecting an unfinished task should fall back to LOG pane.
    out2="$(NIGHTSHIFT_UI_SELFTEST=j NO_COLOR=1 bash "$UI" 2>&1)"
    printf '%s' "$out2" | grep -q "LOG (summary)" || exit 34
    exit 0
)
rc=$?
[ "$rc" -eq 0 ] && ok "commit preview pane (auto switch)" || bad "commit preview rc=$rc"
rm -rf "$PREV"

echo "== ui --attach watches another repo =="
ATT="$(mktemp -d)"
mkdir -p "$ATT/.agent-logs"
cat > "$ATT/.agent-logs/run_state.json" <<'JSON'
{"status":"running","phase":"loop","task_index":1,"task_total":1,"task_name":"x","iteration":1,"max_iterations":9,"cost_usd_estimate":"","validation":{"attempt":0,"max_attempts":7,"last_error":""},"chrome":{"enabled":false,"attempt":0,"max_attempts":3},"todo_file":"todo-attach.md"}
JSON
printf -- '- [ ] **Task 1: attached run**\n' > "$ATT/todo-attach.md"
out="$(cd / && NIGHTSHIFT_UI_SELFTEST=1 NO_COLOR=1 bash "$UI" --attach "$ATT" 2>&1)"
printf '%s' "$out" | grep -q "attached run" && ok "--attach renders other repo" || bad "--attach not reading target"
rm -rf "$ATT"

echo "== bulletproof runner shares the same control protocol =="
(
    cd "$WORK" || exit 9
    : > .agent-logs/ui_control
    rm -f .agent-logs/ui_notes
    # shellcheck disable=SC1090
    NIGHTSHIFT_LIB_ONLY=1 source "$REPO/scripts/nightshift-bulletproof.sh" >/dev/null 2>&1
    set +e
    CONTROL_PAUSE=0; CONTROL_STOP=0; CONTROL_SKIP=0
    printf 'pause\nnote:bulletproof live note\n' >> "$CONTROL_FILE"
    control_drain
    [ "$CONTROL_PAUSE" = "1" ] || exit 3
    n="$(consume_notes)"
    printf '%s' "$n" | grep -q "bulletproof live note" || exit 4
    printf '%s' "$n" | grep -q "LIVE OPERATOR NOTES" || exit 5
    exit 0
)
rc=$?
[ "$rc" -eq 0 ] && ok "bulletproof drain + notes round-trip" || bad "bulletproof protocol rc=$rc"

echo "== bulletproof skip path marks the step done =="
(
    cd "$WORK" || exit 9
    # shellcheck disable=SC1090
    NIGHTSHIFT_LIB_ONLY=1 source "$REPO/scripts/nightshift-bulletproof.sh" >/dev/null 2>&1
    set +e
    echo '{"completed": [], "failed": [], "skipped": [], "chrome_review": []}' > "$PROGRESS_FILE"
    mark_step_progress 3 skipped
    [ "$(is_step_done 3)" = "yes" ] || exit 41   # skipped step counts as handled
    [ "$(is_step_done 2)" = "no" ]  || exit 42   # other steps stay open
    grep -q '"skipped"' "$PROGRESS_FILE"          || exit 43
    exit 0
)
rc=$?
[ "$rc" -eq 0 ] && ok "bulletproof skip marks step done (mark_step_progress)" || bad "bulletproof skip rc=$rc"

trap 'rm -rf "$WORK"' EXIT
echo
echo "RESULT: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
