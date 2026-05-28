#!/usr/bin/env bash
set -euo pipefail

LOG_DIR=".agent-logs"
STATE_FILE="$LOG_DIR/run_state.json"
EVENTS_FILE="$LOG_DIR/run_events.jsonl"
PID_FILE="$LOG_DIR/runner.pid"

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
STATUS_OVERRIDE=""
UI_PAUSED=false
SELECTED_INDEX=0
LOG_MODE="summary"

die() { echo "error: $*" >&2; exit 1; }

if [ ! -d "$LOG_DIR" ]; then
    die "no $LOG_DIR in current directory"
fi

if [ ! -t 1 ]; then
    echo "Non-TTY detected. Use: nightshift tail"
    exit 0
fi

if ! command -v python3 >/dev/null; then
    die "python3 is required for ui state parsing"
fi

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
    if [ ! -f "$STATE_FILE" ]; then
        return 1
    fi
    local out
    out=$(json_kv 2>/dev/null || true)
    if [ -z "$out" ]; then
        return 1
    fi
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
    if [ -z "$TASK_FILE" ] || [ ! -f "$TASK_FILE" ]; then
        return 0
    fi
    while IFS= read -r line; do
        if [[ "$line" =~ ^-\ \[[[:space:]xX]\]\  ]]; then
            local status title
            status="${line:3:1}"
            # Checkbox prefix "- [x] " is always exactly 6 chars. Strip by
            # fixed offset — pattern strip with "[ ]" mis-parses as a glob
            # character class (matches one space), not literal brackets.
            title="${line:6}"
            title="${title//\*\*/}"
            TASK_LINES+=("$line")
            TASK_STATES+=("$status")
            TASK_TITLES+=("$title")
        fi
    done < "$TASK_FILE"
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

repeat_char() {
    local ch="$1" count="$2"
    printf '%*s' "$count" '' | tr ' ' "$ch"
}

truncate_pad() {
    local s="$1" width="$2"
    if [ "${#s}" -gt "$width" ]; then
        s="${s:0:$width}"
    fi
    printf "%-${width}s" "$s"
}

render() {
    local rows cols
    read -r rows cols < <(stty size)
    [ "$rows" -lt 10 ] && rows=10
    [ "$cols" -lt 60 ] && cols=60

    local header status phase iter max_iters task_idx task_total cost
    status="${STATUS_OVERRIDE:-$STATE_status}"
    phase="$STATE_phase"
    iter="$STATE_iteration"
    max_iters="$STATE_max_iterations"
    task_idx="$STATE_task_index"
    task_total="$STATE_task_total"
    cost="$STATE_cost"
    [ -z "$status" ] && status="unknown"
    [ -z "$phase" ] && phase="n/a"
    [ -z "$cost" ] && cost="n/a"

    if [ "$task_total" -eq 0 ]; then
        task_total="${#TASK_TITLES[@]}"
    fi
    if [ "$task_idx" -eq 0 ]; then
        task_idx="$SELECTED_INDEX"
    fi
    header="nightshift ui  status: $status  phase: $phase  task: ${task_idx}/${task_total}  iter: ${iter}/${max_iters}  cost: ${cost}"

    local left_width right_width body_rows
    left_width=$((cols / 2))
    right_width=$((cols - left_width - 3))
    body_rows=$((rows - 5))
    [ "$body_rows" -lt 4 ] && body_rows=4

    printf '\033[2J\033[H'
    truncate_pad "$header" "$cols"; echo ""
    repeat_char "-" "$cols"; echo ""

    if $SHOW_HELP; then
        local help_lines=(
            "Keys:"
            "  j/k or arrows  move selection"
            "  p              pause/resume"
            "  s              stop runner"
            "  t              toggle log source"
            "  ?              help"
            "  q              quit ui"
        )
        local i
        for ((i=0; i<body_rows; i++)); do
            local line="${help_lines[$i]:-}"
            truncate_pad "$line" "$cols"; echo ""
        done
    else
        local i
        local log_lines=()
        if [ "$LOG_MODE" = "events" ] && [ -f "$EVENTS_FILE" ]; then
            mapfile -t log_lines < <(tail -n "$body_rows" "$EVENTS_FILE" 2>/dev/null || true)
        elif [ -n "$SUMMARY_LOG" ] && [ -f "$SUMMARY_LOG" ]; then
            mapfile -t log_lines < <(tail -n "$body_rows" "$SUMMARY_LOG" 2>/dev/null || true)
        fi

        local start_index=1
        if [ "$SELECTED_INDEX" -gt "$body_rows" ]; then
            start_index=$((SELECTED_INDEX - body_rows + 1))
        fi

        for ((i=0; i<body_rows; i++)); do
            local left_line right_line
            local task_pos=$((start_index + i))
            if [ "$task_pos" -le "${#TASK_TITLES[@]}" ]; then
                local title="${TASK_TITLES[$((task_pos - 1))]}"
                local state="${TASK_STATES[$((task_pos - 1))]}"
                local marker=" "
                [ "$task_pos" -eq "$SELECTED_INDEX" ] && marker=">"
                local box="[ ]"
                [ "$state" = "x" ] || [ "$state" = "X" ] && box="[x]"
                left_line="$marker $box $title"
            else
                left_line=""
            fi

            right_line="${log_lines[$i]:-}"
            truncate_pad "$left_line" "$left_width"
            printf " | "
            truncate_pad "$right_line" "$right_width"
            echo ""
        done
    fi

    repeat_char "-" "$cols"; echo ""

    local status_line1 status_line2
    local log_label="summary"
    [ "$LOG_MODE" = "events" ] && log_label="events"
    local chrome_flag="off"
    [ "$STATE_chrome_enabled" = "true" ] && chrome_flag="on"
    status_line1="validation: ${STATE_validation_attempt}/${STATE_validation_max}  chrome: ${chrome_flag} ${STATE_chrome_attempt}/${STATE_chrome_max}  logs: ${log_label}"
    status_line2="task: ${STATE_task_name:-n/a}  last error: ${STATE_last_error:-n/a}"
    truncate_pad "$status_line1" "$cols"; echo ""
    truncate_pad "$status_line2" "$cols"; echo ""
}

toggle_pause() {
    if [ ! -f "$PID_FILE" ]; then
        return 0
    fi
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || true)
    [ -z "$pid" ] && return 0
    if kill -0 "$pid" 2>/dev/null; then
        if $UI_PAUSED; then
            kill -CONT "$pid" 2>/dev/null || true
            UI_PAUSED=false
            STATUS_OVERRIDE=""
        else
            kill -STOP "$pid" 2>/dev/null || true
            UI_PAUSED=true
            STATUS_OVERRIDE="paused"
        fi
    fi
}

stop_runner() {
    if [ ! -f "$PID_FILE" ]; then
        return 0
    fi
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || true)
    [ -z "$pid" ] && return 0
    if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
        sleep 1
        kill -KILL "$pid" 2>/dev/null || true
        STATUS_OVERRIDE="stopped"
    fi
}

cleanup() {
    printf '\033[?25h'
    stty echo icanon 2>/dev/null || true
}

trap cleanup EXIT
stty -echo -icanon 2>/dev/null || true
printf '\033[?25l'

while true; do
    load_state || true
    detect_files
    read_tasks
    choose_selected_index
    render

    key=""
    read -rsn1 -t 0.2 key || true
    if [ -n "$key" ]; then
        case "$key" in
            q) break ;;
            "?")
                if $SHOW_HELP; then
                    SHOW_HELP=false
                else
                    SHOW_HELP=true
                fi
                ;;
            t)
                if [ "$LOG_MODE" = "summary" ]; then
                    LOG_MODE="events"
                else
                    LOG_MODE="summary"
                fi
                ;;
            j) [ "$SELECTED_INDEX" -lt "${#TASK_TITLES[@]}" ] && SELECTED_INDEX=$((SELECTED_INDEX + 1)) ;;
            k) [ "$SELECTED_INDEX" -gt 1 ] && SELECTED_INDEX=$((SELECTED_INDEX - 1)) ;;
            p) toggle_pause ;;
            s) stop_runner ;;
            $'\x1b')
                read -rsn2 -t 0.05 key2 || true
                case "$key2" in
                    "[A") [ "$SELECTED_INDEX" -gt 1 ] && SELECTED_INDEX=$((SELECTED_INDEX - 1)) ;;
                    "[B") [ "$SELECTED_INDEX" -lt "${#TASK_TITLES[@]}" ] && SELECTED_INDEX=$((SELECTED_INDEX + 1)) ;;
                esac
                ;;
        esac
    fi
done
