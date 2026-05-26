#!/usr/bin/env bash
# Launcher for run-agent-loop.sh
# Usage:
#   ./start-nightshift.sh          # start
#   ./start-nightshift.sh status   # is it running?
#   ./start-nightshift.sh stop     # kill it
#   ./start-nightshift.sh tail     # follow the summary log

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

LOG_DIR=".agent-logs"
PID_FILE="$LOG_DIR/runner.pid"
STDOUT_LOG="$LOG_DIR/stdout.log"
SUMMARY_LOG="$LOG_DIR/nightshift-summary.log"

mkdir -p "$LOG_DIR"

cmd="${1:-start}"

case "$cmd" in
    start)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "Already running (PID $(cat "$PID_FILE")). Use './start-nightshift.sh stop' first."
            exit 1
        fi
        [ -x ./run-agent-loop.sh ] || chmod +x ./run-agent-loop.sh
        nohup ./run-agent-loop.sh >"$STDOUT_LOG" 2>&1 &
        echo $! >"$PID_FILE"
        sleep 1
        if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "Started. PID $(cat "$PID_FILE")"
            echo "  stdout: $STDOUT_LOG"
            echo "  tail:   ./start-nightshift.sh tail"
        else
            echo "Failed to start. See $STDOUT_LOG"
            rm -f "$PID_FILE"
            exit 1
        fi
        ;;
    status)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "Running (PID $(cat "$PID_FILE"))."
            tail -5 "$SUMMARY_LOG" 2>/dev/null || true
        else
            echo "Not running."
            rm -f "$PID_FILE" 2>/dev/null || true
        fi
        ;;
    stop)
        if [ -f "$PID_FILE" ]; then
            pid="$(cat "$PID_FILE")"
            if kill -0 "$pid" 2>/dev/null; then
                pkill -TERM -P "$pid" 2>/dev/null || true
                kill -TERM "$pid" 2>/dev/null || true
                sleep 2
                kill -KILL "$pid" 2>/dev/null || true
                echo "Stopped PID $pid."
            else
                echo "No live process for PID $pid."
            fi
            rm -f "$PID_FILE"
        else
            echo "No PID file."
        fi
        ;;
    tail)
        [ -f "$SUMMARY_LOG" ] || { echo "No summary log yet."; exit 1; }
        tail -f "$SUMMARY_LOG"
        ;;
    *)
        echo "usage: $0 {start|status|stop|tail}" >&2
        exit 2
        ;;
esac
