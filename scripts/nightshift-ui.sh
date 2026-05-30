#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# nightshift ui — interactive terminal dashboard for a live nightshift run
# ----------------------------------------------------------------------------
# Bidirectional, Claude-Code-style TUI:
#   - SEE progress live   (tasks, phase, validation, chrome, cost, log tail)
#   - WRITE to the run     (send a message/instruction straight to the agent,
#                           pause/resume/skip/stop) without killing it
#
# It reads run state from .agent-logs/run_state.json + run_events.jsonl and
# writes operator commands to .agent-logs/ui_control, which the runner drains
# at every claude call. No new dependencies (bash 4+, coreutils, python3).
# ============================================================================

LOG_DIR=".agent-logs"
STATE_FILE="$LOG_DIR/run_state.json"
EVENTS_FILE="$LOG_DIR/run_events.jsonl"
PID_FILE="$LOG_DIR/runner.pid"
CONTROL_FILE="$LOG_DIR/ui_control"

STATE_status=""
STATE_phase=""
STATE_task_index=0
STATE_task_total=0
STATE_task_name=""
STATE_iteration=0
STATE_max_iterations=0
STATE_last_error=""
STATE_validation_attempt=0
STATE_validation_max=0
STATE_chrome_enabled="false"
STATE_chrome_attempt=0
STATE_chrome_max=0
STATE_summary_log=""
STATE_todo_file=""
STATE_plan_file=""
STATE_cost=""

SUMMARY_LOG=""
TASK_FILE=""
SHOW_HELP=false
SELECTED_INDEX=0
LOG_MODE="summary"
MODE="nav"            # nav | input
INPUT_BUFFER=""
LAST_ACTION="ready"
TASK_TITLES=()
TASK_STATES=()
TASK_LINES=()
# Right-pane commit preview cache. Keyed by selected task index — when the
# selected row is a done task, the right pane shows that task's commit (subject
# + diffstat) instead of the log tail. git is hit once per selection change.
LAST_PREVIEW_INDEX=-1
LAST_PREVIEW_SHA=""
PREVIEW_LINES=()

die() { echo "error: $*" >&2; exit 1; }

# Preflight checks (dir/tty/python) run inside run_ui, not at source time, so the
# functions can be sourced for testing with NIGHTSHIFT_UI_LIB_ONLY=1.

# ======================== COLORS ========================
if [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_INV=$'\033[7m'
    C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'; C_MAG=$'\033[35m'; C_GREY=$'\033[90m'
    C_BLACK=$'\033[30m'; C_WHITE=$'\033[97m'
    C_BG_GREEN=$'\033[42m'; C_BG_YELLOW=$'\033[43m'; C_BG_RED=$'\033[41m'
    C_BG_BLUE=$'\033[44m'; C_BG_CYAN=$'\033[46m'
else
    C_RESET=""; C_BOLD=""; C_DIM=""; C_INV=""
    C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_MAG=""; C_GREY=""
    C_BLACK=""; C_WHITE=""
    C_BG_GREEN=""; C_BG_YELLOW=""; C_BG_RED=""; C_BG_BLUE=""; C_BG_CYAN=""
fi

# ======================== STATE PARSING ========================
json_kv() {
    python3 - "$STATE_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception:
    sys.exit(1)

def get(d, *keys):
    for k in keys:
        if not isinstance(d, dict):
            return ""
        d = d.get(k)
        if d is None:
            return ""
    return d

fields = {
    "status": get(data, "status"),
    "phase": get(data, "phase"),
    "task_index": get(data, "task_index") or 0,
    "task_total": get(data, "task_total") or 0,
    "task_name": get(data, "task_name"),
    "iteration": get(data, "iteration") or 0,
    "max_iterations": get(data, "max_iterations") or 0,
    "last_error": get(data, "validation", "last_error"),
    "validation_attempt": get(data, "validation", "attempt") or 0,
    "validation_max": get(data, "validation", "max_attempts") or 0,
    "chrome_enabled": get(data, "chrome", "enabled"),
    "chrome_attempt": get(data, "chrome", "attempt") or 0,
    "chrome_max": get(data, "chrome", "max_attempts") or 0,
    "summary_log": get(data, "summary_log"),
    "todo_file": get(data, "todo_file"),
    "plan_file": get(data, "plan_file"),
    "cost": get(data, "cost_usd_estimate"),
}

for k, v in fields.items():
    if isinstance(v, bool):
        v = "true" if v else "false"
    print(f"{k}\t{v}")
PYEOF
}

load_state() {
    [ -f "$STATE_FILE" ] || return 1
    local out
    out=$(json_kv 2>/dev/null || true)
    [ -z "$out" ] && return 1
    while IFS=$'\t' read -r key val; do
        case "$key" in
            status) STATE_status="$val" ;;
            phase) STATE_phase="$val" ;;
            task_index) STATE_task_index="${val:-0}" ;;
            task_total) STATE_task_total="${val:-0}" ;;
            task_name) STATE_task_name="$val" ;;
            iteration) STATE_iteration="${val:-0}" ;;
            max_iterations) STATE_max_iterations="${val:-0}" ;;
            last_error) STATE_last_error="$val" ;;
            validation_attempt) STATE_validation_attempt="${val:-0}" ;;
            validation_max) STATE_validation_max="${val:-0}" ;;
            chrome_enabled) STATE_chrome_enabled="$val" ;;
            chrome_attempt) STATE_chrome_attempt="${val:-0}" ;;
            chrome_max) STATE_chrome_max="${val:-0}" ;;
            summary_log) STATE_summary_log="$val" ;;
            todo_file) STATE_todo_file="$val" ;;
            plan_file) STATE_plan_file="$val" ;;
            cost) STATE_cost="$val" ;;
        esac
    done <<< "$out"
}

detect_files() {
    SUMMARY_LOG=""
    TASK_FILE=""
    if [ -n "$STATE_summary_log" ] && [ -f "$STATE_summary_log" ]; then
        SUMMARY_LOG="$STATE_summary_log"
    elif [ -f "$LOG_DIR/nightshift-summary.log" ]; then
        SUMMARY_LOG="$LOG_DIR/nightshift-summary.log"
    elif [ -f "$LOG_DIR/bulletproof-summary.log" ]; then
        SUMMARY_LOG="$LOG_DIR/bulletproof-summary.log"
    fi

    if [ -n "$STATE_todo_file" ] && [ -f "$STATE_todo_file" ]; then
        TASK_FILE="$STATE_todo_file"
    elif [ -n "$STATE_plan_file" ] && [ -f "$STATE_plan_file" ]; then
        TASK_FILE="$STATE_plan_file"
    else
        local todo
        todo=$(ls -1 todo-*.md 2>/dev/null | head -1 || true)
        if [ -n "$todo" ]; then
            TASK_FILE="$todo"
        elif [ -f "BULLETPROOF-STEPS.md" ]; then
            TASK_FILE="BULLETPROOF-STEPS.md"
        fi
    fi
}

read_tasks() {
    TASK_LINES=()
    TASK_STATES=()
    TASK_TITLES=()
    [ -z "$TASK_FILE" ] || [ ! -f "$TASK_FILE" ] && return 0
    while IFS= read -r line; do
        if [[ "$line" =~ ^-\ \[[[:space:]xX]\]\  ]]; then
            local status title
            status="${line:3:1}"
            # "- [x] " is always exactly 6 chars; strip by fixed offset.
            title="${line:6}"
            title="${title//\*\*/}"
            TASK_LINES+=("$line")
            TASK_STATES+=("$status")
            TASK_TITLES+=("$title")
        fi
    done < "$TASK_FILE"
}

# Parse a task/step number from a title like "Task 12: foo" or "Step 3 — bar".
parse_task_num() {
    local s="$1"
    if [[ "$s" =~ (Task|Step)[[:space:]]+([0-9]+) ]]; then
        printf '%s' "${BASH_REMATCH[2]}"
    fi
}

# Resolve a task number to its commit SHA, if any. Matches the bulletproof /
# classic commit convention `feat(task-N): ...` or `feat(step-N): ...`.
find_task_commit() {
    local num="$1"
    [ -z "$num" ] && return 0
    command -v git >/dev/null 2>&1 || return 0
    git log --all --pretty=%H -n 1 --grep="(task-${num}):\\|(step-${num}):" 2>/dev/null
}

# Pretty short header + diffstat for a commit. Empty output if the sha is bad.
build_commit_preview() {
    local sha="$1"
    [ -z "$sha" ] && return 0
    git show -s --pretty='%h · %an · %ad · %s' --date=format:'%H:%M:%S' "$sha" 2>/dev/null
    git show --stat --format='' "$sha" 2>/dev/null | sed '/^$/d'
}

choose_selected_index() {
    if [ "$SELECTED_INDEX" -gt 0 ]; then
        local count="${#TASK_TITLES[@]}"
        if [ "$count" -gt 0 ] && [ "$SELECTED_INDEX" -gt "$count" ]; then
            SELECTED_INDEX="$count"
        fi
        return 0
    fi
    if [ "${STATE_task_index}" -gt 0 ]; then
        SELECTED_INDEX="$STATE_task_index"
        return 0
    fi
    local i
    for i in "${!TASK_STATES[@]}"; do
        if [ "${TASK_STATES[$i]}" = " " ]; then
            SELECTED_INDEX=$((i + 1))
            return 0
        fi
    done
    SELECTED_INDEX=1
}

# ======================== DRAWING HELPERS ========================
hrule() {
    local n="$1" ch="${2:-─}" i out=""
    for ((i = 0; i < n; i++)); do out+="$ch"; done
    printf '%s' "$out"
}

progress_bar() {
    local cur="$1" total="$2" width="$3" filled i out=""
    [ "$total" -le 0 ] && total=1
    [ "$cur" -lt 0 ] && cur=0
    [ "$cur" -gt "$total" ] && cur="$total"
    filled=$((cur * width / total))
    for ((i = 0; i < width; i++)); do
        if [ "$i" -lt "$filled" ]; then out+="█"; else out+="░"; fi
    done
    printf '%s' "$out"
}

# Truncate + pad PLAIN text to a fixed width (color is applied afterwards so
# the escape bytes never throw off the column math).
fit() {
    local s="$1" width="$2"
    [ "${#s}" -gt "$width" ] && s="${s:0:$width}"
    printf "%-${width}s" "$s"
}

# Print one screen line: content + clear-to-end-of-line + newline.
putline() { printf '%s\033[K\n' "${1-}"; }

status_badge() {
    case "$1" in
        running)   printf '%s RUNNING %s'  "${C_BG_GREEN}${C_BLACK}${C_BOLD}" "$C_RESET" ;;
        paused)    printf '%s PAUSED %s'   "${C_BG_YELLOW}${C_BLACK}${C_BOLD}" "$C_RESET" ;;
        stopped)   printf '%s STOPPED %s'  "${C_BG_RED}${C_WHITE}${C_BOLD}" "$C_RESET" ;;
        completed) printf '%s DONE %s'     "${C_BG_BLUE}${C_WHITE}${C_BOLD}" "$C_RESET" ;;
        starting)  printf '%s STARTING %s' "${C_BG_CYAN}${C_BLACK}${C_BOLD}" "$C_RESET" ;;
        *)         printf '%s %s %s' "$C_INV" "${1:-unknown}" "$C_RESET" ;;
    esac
}

# ======================== RENDER ========================
render() {
    local rows cols
    read -r rows cols < <(stty size 2>/dev/null || echo "24 80")
    [ "$rows" -lt 14 ] && rows=14
    [ "$cols" -lt 50 ] && cols=50

    local status phase iter max_iters task_idx task_total cost
    status="$STATE_status"; [ -z "$status" ] && status="unknown"
    phase="$STATE_phase"; [ -z "$phase" ] && phase="n/a"
    iter="$STATE_iteration"; max_iters="$STATE_max_iterations"
    task_idx="$STATE_task_index"; task_total="$STATE_task_total"
    cost="$STATE_cost"; [ -z "$cost" ] && cost="n/a"
    [ "$task_total" -eq 0 ] && task_total="${#TASK_TITLES[@]}"
    [ "$task_idx" -eq 0 ] && task_idx="$SELECTED_INDEX"

    local left_width right_width body_rows
    left_width=$((cols / 2))
    [ "$left_width" -gt 48 ] && left_width=48
    right_width=$((cols - left_width - 3))
    [ "$right_width" -lt 10 ] && right_width=10
    body_rows=$((rows - 9))
    [ "$body_rows" -lt 3 ] && body_rows=3

    printf '\033[H'

    # --- Header ---
    local bar
    bar=$(progress_bar "$task_idx" "$task_total" 14)
    putline "${C_BOLD}${C_CYAN} nightshift${C_RESET}  $(status_badge "$status")  ${C_GREEN}${bar}${C_RESET} ${task_idx}/${task_total}  ${C_DIM}iter${C_RESET} ${iter}/${max_iters}  ${C_DIM}cost${C_RESET} ~\$${cost}"
    putline "${C_GREY}$(hrule "$cols")${C_RESET}"

    # --- Right pane source: commit preview for a selected done task, else log ---
    local loglabel="summary"; [ "$LOG_MODE" = "events" ] && loglabel="events"
    local pane_label="LOG (${loglabel})"
    local right_lines=()
    local show_commit=false
    if ! $SHOW_HELP \
        && [ "$LOG_MODE" = "summary" ] \
        && [ "${#TASK_TITLES[@]}" -gt 0 ] \
        && [ "$SELECTED_INDEX" -ge 1 ] \
        && [ "$SELECTED_INDEX" -le "${#TASK_TITLES[@]}" ]; then
        local sel_state="${TASK_STATES[$((SELECTED_INDEX - 1))]}"
        if [ "$sel_state" = "x" ] || [ "$sel_state" = "X" ]; then
            local sel_title num sha
            sel_title="${TASK_TITLES[$((SELECTED_INDEX - 1))]}"
            num=$(parse_task_num "$sel_title")
            if [ -n "$num" ]; then
                if [ "$SELECTED_INDEX" != "$LAST_PREVIEW_INDEX" ]; then
                    sha=$(find_task_commit "$num" | head -1)
                    LAST_PREVIEW_SHA="$sha"
                    if [ -n "$sha" ]; then
                        mapfile -t PREVIEW_LINES < <(build_commit_preview "$sha")
                    else
                        PREVIEW_LINES=()
                    fi
                    LAST_PREVIEW_INDEX="$SELECTED_INDEX"
                fi
                if [ "${#PREVIEW_LINES[@]}" -gt 0 ]; then
                    show_commit=true
                    pane_label="COMMIT ${LAST_PREVIEW_SHA:0:7}"
                    right_lines=("${PREVIEW_LINES[@]}")
                fi
            fi
        fi
    fi

    # --- Column heads ---
    putline "${C_BOLD}$(fit " TASKS" "$left_width")${C_RESET} ${C_GREY}│${C_RESET} ${C_BOLD}${pane_label}${C_RESET}"

    # --- Body ---
    if $SHOW_HELP; then
        local help_lines=(
            "${C_BOLD}Keybindings${C_RESET}"
            ""
            "  ${C_CYAN}i${C_RESET} / ${C_CYAN}/${C_RESET}   write a message to the running agent"
            "  ${C_CYAN}p${C_RESET}       pause   ${C_CYAN}r${C_RESET}  resume   ${C_CYAN}s${C_RESET}/${C_CYAN}x${C_RESET}  stop (graceful)"
            "  ${C_CYAN}n${C_RESET}       skip current task"
            "  ${C_CYAN}K${C_RESET}       force-kill runner (signal, last resort)"
            "  ${C_CYAN}j/k${C_RESET} ${C_CYAN}↑/↓${C_RESET} move task selection"
            "  ${C_CYAN}t${C_RESET}       toggle log source (summary/events)"
            "  ${C_CYAN}?${C_RESET}       close this help    ${C_CYAN}q${C_RESET}  quit ui"
            ""
            "${C_DIM}Messages and pause/skip/stop are cooperative: the runner${C_RESET}"
            "${C_DIM}picks them up at the next agent call, so nothing is frozen${C_RESET}"
            "${C_DIM}mid-task. Quitting the ui does NOT stop the run.${C_RESET}"
        )
        local i
        for ((i = 0; i < body_rows; i++)); do
            putline "${help_lines[$i]:-}"
        done
    else
        if ! $show_commit; then
            if [ "$LOG_MODE" = "events" ] && [ -f "$EVENTS_FILE" ]; then
                mapfile -t right_lines < <(tail -n "$body_rows" "$EVENTS_FILE" 2>/dev/null || true)
            elif [ -n "$SUMMARY_LOG" ] && [ -f "$SUMMARY_LOG" ]; then
                mapfile -t right_lines < <(tail -n "$body_rows" "$SUMMARY_LOG" 2>/dev/null || true)
            fi
        else
            # Show the tail of the commit preview if it overflows the pane.
            if [ "${#right_lines[@]}" -gt "$body_rows" ]; then
                right_lines=("${right_lines[@]: -body_rows}")
            fi
        fi

        local start_index=1
        [ "$SELECTED_INDEX" -gt "$body_rows" ] && start_index=$((SELECTED_INDEX - body_rows + 1))

        local i
        for ((i = 0; i < body_rows; i++)); do
            local left_plain left_colored right_line
            local task_pos=$((start_index + i))
            if [ "$task_pos" -le "${#TASK_TITLES[@]}" ]; then
                local title="${TASK_TITLES[$((task_pos - 1))]}"
                local state="${TASK_STATES[$((task_pos - 1))]}"
                local marker="  " box="[ ]" col="$C_RESET"
                [ "$task_pos" -eq "$SELECTED_INDEX" ] && marker="${C_CYAN}> ${C_RESET}"
                if [ "$state" = "x" ] || [ "$state" = "X" ]; then
                    box="[x]"; col="$C_GREEN"
                elif [ "$task_pos" -eq "$task_idx" ]; then
                    box="[~]"; col="${C_YELLOW}${C_BOLD}"
                fi
                left_plain="$(fit "$box $title" $((left_width - 2)))"
                if [ "$task_pos" -eq "$SELECTED_INDEX" ]; then
                    left_colored="${marker}${C_INV}${left_plain}${C_RESET}"
                else
                    left_colored="${marker}${col}${left_plain}${C_RESET}"
                fi
            else
                left_colored="$(fit "" "$left_width")"
            fi
            right_line="$(fit "${right_lines[$i]:-}" "$right_width")"
            putline "${left_colored} ${C_GREY}│${C_RESET} ${C_DIM}${right_line}${C_RESET}"
        done
    fi

    # --- Status footer ---
    putline "${C_GREY}$(hrule "$cols")${C_RESET}"
    local chrome_flag="${C_GREY}off${C_RESET}"
    [ "$STATE_chrome_enabled" = "true" ] && chrome_flag="${C_GREEN}on${C_RESET}"
    putline " ${C_DIM}phase${C_RESET} ${C_MAG}${phase}${C_RESET}   ${C_DIM}val${C_RESET} ${STATE_validation_attempt}/${STATE_validation_max}   ${C_DIM}chrome${C_RESET} ${chrome_flag} ${STATE_chrome_attempt}/${STATE_chrome_max}   ${C_DIM}·${C_RESET} ${C_CYAN}${LAST_ACTION}${C_RESET}"
    putline " ${C_DIM}task${C_RESET} ${STATE_task_name:-n/a}"
    local errcol="$C_GREY"; [ -n "$STATE_last_error" ] && errcol="$C_RED"
    putline " ${C_DIM}error${C_RESET} ${errcol}${STATE_last_error:-none}${C_RESET}"
    putline "${C_GREY}$(hrule "$cols")${C_RESET}"

    # --- Input / hint line ---
    if [ "$MODE" = "input" ]; then
        printf '%s\033[K' "${C_YELLOW}${C_BOLD}> ${C_RESET}${INPUT_BUFFER}${C_INV} ${C_RESET}  ${C_DIM}(Enter send · Esc cancel)${C_RESET}"
    else
        printf '%s\033[K' " ${C_CYAN}i${C_RESET} msg  ${C_CYAN}p${C_RESET} pause  ${C_CYAN}r${C_RESET} resume  ${C_CYAN}n${C_RESET} skip  ${C_CYAN}s${C_RESET} stop  ${C_CYAN}t${C_RESET} logs  ${C_CYAN}?${C_RESET} help  ${C_CYAN}q${C_RESET} quit"
    fi
    printf '\033[J'
}

# ======================== CONTROL WRITERS ========================
control_send() {
    printf '%s\n' "$1" >> "$CONTROL_FILE"
    LAST_ACTION="sent: $1"
}

control_note() {
    local t="${1//$'\n'/ }"
    [ -z "$t" ] && return 0
    printf 'note:%s\n' "$t" >> "$CONTROL_FILE"
    LAST_ACTION="message sent to agent"
}

force_kill_runner() {
    [ -f "$PID_FILE" ] || { LAST_ACTION="no runner pid"; return 0; }
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || true)
    [ -z "$pid" ] && { LAST_ACTION="no runner pid"; return 0; }
    if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
        sleep 1
        kill -KILL "$pid" 2>/dev/null || true
        LAST_ACTION="force-killed runner $pid"
    else
        LAST_ACTION="runner not running"
    fi
}

# ======================== INPUT HANDLING ========================
handle_input_key() {
    local key="$1" rc="$2"
    # Enter (canonical-off terminals send \r; some send \n; read may yield empty)
    if [ "$rc" -eq 0 ] && { [ -z "$key" ] || [ "$key" = $'\r' ] || [ "$key" = $'\n' ]; }; then
        control_note "$INPUT_BUFFER"
        INPUT_BUFFER=""
        MODE="nav"
        return 0
    fi
    case "$key" in
        $'\x1b')   # Esc (or start of an arrow seq) — cancel input
            read -rsn2 -t 0.01 _ 2>/dev/null || true
            INPUT_BUFFER=""
            MODE="nav"
            LAST_ACTION="message cancelled"
            ;;
        $'\x7f'|$'\x08')   # Backspace / Delete
            INPUT_BUFFER="${INPUT_BUFFER%?}"
            ;;
        *)
            if [ -n "$key" ] && [[ "$key" == [[:print:]] ]]; then
                INPUT_BUFFER+="$key"
            fi
            ;;
    esac
}

handle_nav_key() {
    local key="$1"
    case "$key" in
        q) return 1 ;;
        i|/) MODE="input"; INPUT_BUFFER=""; LAST_ACTION="typing message…" ;;
        p) control_send "pause" ;;
        r) control_send "resume" ;;
        n) control_send "skip" ;;
        s|x) control_send "stop" ;;
        K) force_kill_runner ;;
        "?") if $SHOW_HELP; then SHOW_HELP=false; else SHOW_HELP=true; fi ;;
        t) if [ "$LOG_MODE" = "summary" ]; then LOG_MODE="events"; else LOG_MODE="summary"; fi ;;
        j) [ "$SELECTED_INDEX" -lt "${#TASK_TITLES[@]}" ] && SELECTED_INDEX=$((SELECTED_INDEX + 1)) ;;
        k) [ "$SELECTED_INDEX" -gt 1 ] && SELECTED_INDEX=$((SELECTED_INDEX - 1)) ;;
        $'\x1b')
            local key2=""
            read -rsn2 -t 0.05 key2 || true
            case "$key2" in
                "[A") [ "$SELECTED_INDEX" -gt 1 ] && SELECTED_INDEX=$((SELECTED_INDEX - 1)) ;;
                "[B") [ "$SELECTED_INDEX" -lt "${#TASK_TITLES[@]}" ] && SELECTED_INDEX=$((SELECTED_INDEX + 1)) ;;
            esac
            ;;
    esac
    return 0
}

# ======================== ARG PARSING ========================
print_ui_help() {
    cat <<'EOF'
nightshift ui — interactive dashboard for a live nightshift run

Usage: nightshift ui [DIR]
       nightshift ui --attach DIR

  DIR            project dir to watch (defaults to the current directory)
  --attach DIR   same as DIR; watch a run in another repo
  -C DIR         same as --attach
  -h, --help     show this help

Keys: i/  message agent · p pause · r resume · n skip · s/x stop · K force-kill
      j/k move · t toggle logs · ? help · q quit
EOF
}

# Parse args and cd into the target project so the relative .agent-logs paths
# resolve there. Honors `--attach DIR`, `-C DIR`, or a positional DIR.
resolve_target() {
    local dir=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --attach|-C) dir="${2:-}"; shift 2 || shift ;;
            --attach=*)  dir="${1#*=}"; shift ;;
            -h|--help)   print_ui_help; exit 0 ;;
            -*)          shift ;;
            *)           [ -z "$dir" ] && dir="$1"; shift ;;
        esac
    done
    if [ -n "$dir" ]; then
        [ -d "$dir" ] || die "attach dir not found: $dir"
        cd "$dir" || die "cannot cd to $dir"
    fi
}

# ======================== MAIN ========================
interactive_loop() {
    cleanup() {
        printf '\033[?25h\033[2J\033[H'
        stty echo icanon 2>/dev/null || true
    }
    trap cleanup EXIT
    stty -echo -icanon 2>/dev/null || true
    printf '\033[?25l\033[2J'

    while true; do
        load_state || true
        detect_files
        read_tasks
        choose_selected_index
        render

        local key="" rc=0
        if IFS= read -rsn1 -t 0.2 key; then rc=0; else rc=$?; fi

        if [ "$MODE" = "input" ]; then
            handle_input_key "$key" "$rc"
        elif [ "$rc" -eq 0 ] && [ -n "$key" ]; then
            handle_nav_key "$key" || break
        fi
    done
}

run_ui() {
    resolve_target "$@"
    [ -d "$LOG_DIR" ] || die "no $LOG_DIR in $(pwd) (run nightshift start first)"
    command -v python3 >/dev/null || die "python3 is required for ui state parsing"

    if [ ! -t 1 ] && [ -z "${NIGHTSHIFT_UI_SELFTEST:-}" ]; then
        echo "Non-TTY detected. Use: nightshift tail"
        exit 0
    fi

    # Self-test: render one frame to stdout and exit (CI renderer check).
    # NIGHTSHIFT_UI_SELFTEST=<key> also injects a single nav key first.
    if [ -n "${NIGHTSHIFT_UI_SELFTEST:-}" ]; then
        load_state || true
        detect_files
        read_tasks
        choose_selected_index
        [ "$NIGHTSHIFT_UI_SELFTEST" != "1" ] && handle_nav_key "$NIGHTSHIFT_UI_SELFTEST" || true
        render
        printf '\n'
        return 0
    fi

    interactive_loop
}

# Set NIGHTSHIFT_UI_LIB_ONLY=1 to source this file for its functions without
# launching the UI (used by the control-protocol test).
if [ "${NIGHTSHIFT_UI_LIB_ONLY:-}" != "1" ]; then
    run_ui "$@"
fi
