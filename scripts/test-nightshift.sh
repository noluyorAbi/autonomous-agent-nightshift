#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# test-nightshift.sh — Recursive test runner for bulletproof CI
#
# Runs the full verification suite (tests, types, lint, format) in
# a loop at a configurable interval. Logs every run with timestamps.
# Designed to be left running overnight or during long dev sessions.
#
# Usage:
#   ./scripts/test-nightshift.sh              # defaults: 3 rounds, 5min interval
#   ./scripts/test-nightshift.sh -n 10 -i 60  # 10 rounds, 60s interval
#   ./scripts/test-nightshift.sh --forever     # infinite loop until failure
#
# Options:
#   -n, --rounds   Number of rounds (default: 3, 0 = infinite)
#   -i, --interval Seconds between rounds (default: 300)
#   -f, --forever  Run forever until a failure (same as -n 0)
#   -q, --quick    Skip interval between rounds (back-to-back)
#   --fail-fast    Stop on first failure (default: true)
#   --no-fail-fast Continue even after failures
#   -h, --help     Show this help
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Defaults ──
ROUNDS=3
INTERVAL=300
FAIL_FAST=true
QUICK=false

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Log directory ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/.agent-logs"
LOG_FILE="$LOG_DIR/test-nightshift-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"

# ── Parse args ──
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--rounds)   ROUNDS="$2"; shift 2 ;;
    -i|--interval) INTERVAL="$2"; shift 2 ;;
    -f|--forever)  ROUNDS=0; shift ;;
    -q|--quick)    QUICK=true; shift ;;
    --fail-fast)   FAIL_FAST=true; shift ;;
    --no-fail-fast) FAIL_FAST=false; shift ;;
    -h|--help)
      head -24 "$0" | tail -18
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ── Helpers ──
ts() { date "+%Y-%m-%d %H:%M:%S"; }

log() {
  local msg="[$(ts)] $*"
  echo -e "$msg" | tee -a "$LOG_FILE"
}

separator() {
  echo -e "${BLUE}════════════════════════════════════════════════════════════${RESET}" | tee -a "$LOG_FILE"
}

# ── Check: step name, command ──
run_check() {
  local step_name="$1"
  shift
  local start_time
  start_time=$(date +%s)

  log "  ${CYAN}RUN${RESET}  $step_name"

  local output
  local exit_code=0
  output=$("$@" 2>&1) || exit_code=$?

  local end_time
  end_time=$(date +%s)
  local duration=$(( end_time - start_time ))

  if [[ $exit_code -eq 0 ]]; then
    log "  ${GREEN}PASS${RESET} $step_name (${duration}s)"
    return 0
  else
    log "  ${RED}FAIL${RESET} $step_name (${duration}s, exit=$exit_code)"
    echo "$output" >> "$LOG_FILE"
    # Show last 20 lines of failure output to terminal
    echo "$output" | tail -20
    return 1
  fi
}

# ── Single round ──
run_round() {
  local round_num="$1"
  local round_start
  round_start=$(date +%s)
  local failures=0

  separator
  log "${BOLD}Round $round_num${RESET} started"
  separator

  # 1. Unit tests (bun test)
  run_check "Unit tests (bun test)" bun test || failures=$(( failures + 1 ))
  if [[ $FAIL_FAST == true && $failures -gt 0 ]]; then return 1; fi

  # 2. TypeScript type-check
  run_check "TypeScript (tsc --noEmit)" npx tsc --noEmit || failures=$(( failures + 1 ))
  if [[ $FAIL_FAST == true && $failures -gt 0 ]]; then return 1; fi

  # 3. ESLint
  run_check "ESLint" bun run lint:check || failures=$(( failures + 1 ))
  if [[ $FAIL_FAST == true && $failures -gt 0 ]]; then return 1; fi

  # 4. Prettier format check
  run_check "Prettier" npx prettier --check . || failures=$(( failures + 1 ))
  if [[ $FAIL_FAST == true && $failures -gt 0 ]]; then return 1; fi

  # 5. Next.js build (most thorough — catches runtime issues)
  run_check "Next.js build" bun run build || failures=$(( failures + 1 ))
  if [[ $FAIL_FAST == true && $failures -gt 0 ]]; then return 1; fi

  local round_end
  round_end=$(date +%s)
  local round_duration=$(( round_end - round_start ))

  if [[ $failures -eq 0 ]]; then
    log "${GREEN}${BOLD}Round $round_num PASSED${RESET} (${round_duration}s)"
  else
    log "${RED}${BOLD}Round $round_num FAILED${RESET} ($failures failures, ${round_duration}s)"
  fi

  return $failures
}

# ── Main loop ──
main() {
  local total_start
  total_start=$(date +%s)
  local total_pass=0
  local total_fail=0
  local round=0
  local max_display
  if [[ $ROUNDS -eq 0 ]]; then max_display="inf"; else max_display="$ROUNDS"; fi

  separator
  log "${BOLD}TEST NIGHTSHIFT STARTED${RESET}"
  log "Rounds: $max_display | Interval: ${INTERVAL}s | Fail-fast: $FAIL_FAST"
  log "Branch: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo 'unknown')"
  log "Log: $LOG_FILE"
  separator

  while true; do
    round=$(( round + 1 ))

    # Check if we've hit the round limit (0 = infinite)
    if [[ $ROUNDS -gt 0 && $round -gt $ROUNDS ]]; then
      break
    fi

    local round_label="$round/$max_display"

    if run_round "$round_label"; then
      total_pass=$(( total_pass + 1 ))
    else
      total_fail=$(( total_fail + 1 ))
      if [[ $FAIL_FAST == true ]]; then
        log "${RED}Stopping: fail-fast enabled${RESET}"
        break
      fi
    fi

    # Wait between rounds (skip if last round or quick mode)
    local is_last=false
    if [[ $ROUNDS -gt 0 && $round -ge $ROUNDS ]]; then is_last=true; fi

    if [[ $is_last == false && $QUICK == false ]]; then
      log "${YELLOW}Next round in ${INTERVAL}s ($(date -v+${INTERVAL}S "+%H:%M:%S" 2>/dev/null || date -d "+${INTERVAL} seconds" "+%H:%M:%S" 2>/dev/null || echo "soon"))${RESET}"
      sleep "$INTERVAL"
    fi
  done

  local total_end
  total_end=$(date +%s)
  local total_duration=$(( total_end - total_start ))
  local total_min=$(( total_duration / 60 ))
  local total_sec=$(( total_duration % 60 ))

  separator
  log "${BOLD}TEST NIGHTSHIFT FINISHED${RESET}"
  log "Rounds: $round | Pass: ${GREEN}$total_pass${RESET} | Fail: ${RED}$total_fail${RESET} | Time: ${total_min}m${total_sec}s"
  separator

  if [[ $total_fail -gt 0 ]]; then
    exit 1
  fi
}

main
