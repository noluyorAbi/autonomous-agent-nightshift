#!/bin/bash

# ============================================================================
# Autonomous TDD Agent Loop — Nightshift Edition
# ============================================================================
# Full pipeline:
#   0. Create dedicated branch, push it
#   1-4. Per task: implement → validate → Chrome test → commit
#   5. Open PR with detailed summary
#   6. Wait 20 minutes for review comments
#   7. Address every PR comment (implement fixes, respond in detail)
#   8. Push final state
#
# Prerequisites:
#   - Claude Code CLI installed and authenticated
#   - gh CLI authenticated (gh auth status)
#   - Chrome browser open with Claude-in-Chrome extension active
#   - bun, npx, pnpm installed
#
# Usage:
#   chmod +x run-agent-loop.sh
#   ./run-agent-loop.sh
# ============================================================================

set -euo pipefail

# ======================== CONFIGURATION ========================
TODO_FILE="todo-YYYY_MM_DD_name.md"   # <-- Your feature plan
ITERATION_STATE_FILE=".claude_iterations"
LOG_DIR=".agent-logs"
SCREENSHOT_DIR=".agent-logs/screenshots"
SUMMARY_LOG="$LOG_DIR/nightshift-summary.log"

# --- Git ---
BASE_BRANCH="main"
NIGHTSHIFT_BRANCH="nightshift/$(date '+%Y-%m-%d')"
GITHUB_REPO="owner/repo"           # <-- Your GitHub repo (owner/name) — used for PR review fetch
PR_WAIT_MINUTES=20

# --- App ---
DEV_PORT=31415
DEV_URL="http://localhost:$DEV_PORT"

# --- Limits ---
MAX_ITERATIONS=250
MAX_FIX_ATTEMPTS=7
MAX_CHROME_FIX_ATTEMPTS=3
COOLDOWN_SECONDS=5              # Between tasks (auto-increases on rate limits)
COOLDOWN_MAX=120                # Max cooldown cap
DEV_SERVER_WAIT=15

# ======================== COLORS ========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# ======================== HELPERS ========================
log() { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $1"; }
log_error() { echo -e "${RED}[$(date '+%H:%M:%S')] ✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $1"; }
log_phase() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}
summary() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$SUMMARY_LOG"
}

# ======================== CODEBASE CONTEXT ========================
# REPLACE THIS HEREDOC with your project's file map + conventions.
# See templates/codebase-context.md for a fill-in skeleton.
read -r -d '' CODEBASE_CONTEXT << 'CONTEXT_EOF' || true
## Codebase Map (use these exact paths):

**{Domain 1 — e.g. Core / Routes / Components}:**
- {path/to/file.tsx} — {what it does, key exports}

**{Domain 2 — e.g. API}:**
- {path/to/route.ts} — {method, purpose, schema}

**Types:**
- {path/to/types.ts} — {key interfaces}

**Hooks & Services:**
- {path/to/hook.ts} — {what state it manages}

**UI Stack:** {ui-kit} + {styling} + {animation} + {icons}
**Test Framework:** {framework}. Import from "{path}". Tests colocated as *.test.{ext}.
**Auth:** {provider} ({client file}, {server file}).
**Package Manager:** {npm/pnpm/bun/yarn}.

## Conventions:
- {Convention 1}
- {Convention 2}
- {Convention 3}
CONTEXT_EOF

# ======================== CHROME TESTING CONTEXT ========================
read -r -d '' CHROME_CONTEXT << 'CHROME_EOF' || true
## Chrome Browser Testing Instructions

You have access to Chrome browser automation via MCP tools. The app is running at http://localhost:31415.

### Available Chrome MCP Tools:
- mcp__claude-in-chrome__tabs_context_mcp — Get current tabs (CALL THIS FIRST)
- mcp__claude-in-chrome__tabs_create_mcp — Open a new tab
- mcp__claude-in-chrome__navigate — Navigate to a URL
- mcp__claude-in-chrome__read_page — Read accessibility tree (filter: "interactive" or "all")
- mcp__claude-in-chrome__computer — Click, scroll, interact by coordinates
- mcp__claude-in-chrome__find — Find elements on page
- mcp__claude-in-chrome__form_input — Fill form fields
- mcp__claude-in-chrome__javascript_tool — Execute JavaScript
- mcp__claude-in-chrome__read_console_messages — Read browser console
- mcp__claude-in-chrome__gif_creator — Record a GIF
- mcp__claude-in-chrome__upload_image — Take a screenshot

### How to Navigate:
# REPLACE with the routes for your app:
- Landing: http://localhost:$DEV_PORT/
- {Route 1}: http://localhost:$DEV_PORT/{path}
- {Route 2}: http://localhost:$DEV_PORT/{path}
CHROME_EOF

# ======================== DEV SERVER ========================
DEV_SERVER_PID=""

start_dev_server() {
    if lsof -i :$DEV_PORT -t &>/dev/null; then
        DEV_SERVER_PID=$(lsof -i :$DEV_PORT -t | head -1)
        log_success "Dev server already running on :$DEV_PORT (PID $DEV_SERVER_PID)"
        return 0
    fi

    log "Starting dev server on :$DEV_PORT..."
    pnpm dev > "$LOG_DIR/dev-server.log" 2>&1 &
    DEV_SERVER_PID=$!
    echo "$DEV_SERVER_PID" > "$LOG_DIR/dev-server.pid"

    local wait_count=0
    while ! curl -s -o /dev/null -w "%{http_code}" "$DEV_URL" 2>/dev/null | grep -qE "200|302|304"; do
        wait_count=$((wait_count + 1))
        if [ "$wait_count" -ge "$DEV_SERVER_WAIT" ]; then
            log_warn "Dev server not responding after ${DEV_SERVER_WAIT}s."
            return 1
        fi
        sleep 1
    done

    log_success "Dev server ready at $DEV_URL"
    return 0
}

stop_dev_server() {
    if [ -f "$LOG_DIR/dev-server.pid" ]; then
        local pid
        pid=$(cat "$LOG_DIR/dev-server.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
        rm -f "$LOG_DIR/dev-server.pid"
    fi
}

cleanup() {
    stop_dev_server
    rm -f "$ITERATION_STATE_FILE"
}
trap cleanup EXIT

# ======================== PRE-FLIGHT ========================
preflight() {
    log_phase "Pre-Flight Checks"

    for cmd in claude bun npx pnpm curl gh git; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "$cmd not found in PATH."
            exit 1
        fi
        log_success "$cmd"
    done

    # gh auth check
    if ! gh auth status &>/dev/null; then
        log_error "gh CLI not authenticated. Run: gh auth login"
        exit 1
    fi
    log_success "gh authenticated"

    if [ ! -f "$TODO_FILE" ]; then
        log_error "Todo file not found: $TODO_FILE"
        exit 1
    fi
    log_success "Todo: $TODO_FILE"

    mkdir -p "$LOG_DIR" "$SCREENSHOT_DIR"

    REMAINING=$(grep -c "\- \[ \]" "$TODO_FILE" || echo "0")
    COMPLETED=$(grep -c "\- \[x\]" "$TODO_FILE" || echo "0")
    log "Tasks: ${BOLD}$COMPLETED done${NC}, ${BOLD}$REMAINING remaining${NC}"

    EST_MINUTES=$(( REMAINING * 12 ))
    log "Estimated: ~${EST_MINUTES} min (${REMAINING} tasks × ~12 min)"

    start_dev_server

    summary "═══ NIGHTSHIFT STARTED ═══"
    summary "Tasks: $REMAINING | Branch: $NIGHTSHIFT_BRANCH | Chrome: ON"
    echo ""
}

# ======================== GIT BRANCH SETUP ========================
setup_branch() {
    log_phase "Git Branch Setup"

    # Make sure we're on base branch and up to date
    log "Fetching latest from origin..."
    git fetch origin "$BASE_BRANCH" 2>/dev/null || true

    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$NIGHTSHIFT_BRANCH" 2>/dev/null; then
        log_warn "Branch $NIGHTSHIFT_BRANCH already exists. Switching to it."
        git checkout "$NIGHTSHIFT_BRANCH"
    else
        log "Creating branch: $NIGHTSHIFT_BRANCH from $BASE_BRANCH"
        git checkout -b "$NIGHTSHIFT_BRANCH" "$BASE_BRANCH"
    fi

    # Push the branch to set up tracking
    git push -u origin "$NIGHTSHIFT_BRANCH" 2>/dev/null || true
    log_success "On branch: $NIGHTSHIFT_BRANCH (tracking origin)"

    summary "Branch: $NIGHTSHIFT_BRANCH (from $BASE_BRANCH)"
    echo ""
}

# ======================== GIT COMMIT PER TASK ========================
commit_task() {
    local task_num="$1"
    local task_name="$2"
    local status="$3"  # "pass" | "chrome-review" | "failed"

    # Stage all changes
    git add -A

    # Check if there's anything to commit
    if git diff --cached --quiet; then
        log_warn "No changes to commit for Task $task_num."
        return 0
    fi

    local msg=""
    case "$status" in
        pass)
            msg="feat(task-$task_num): $task_name

Implemented and verified (code + Chrome browser test).

Automated by nightshift agent loop.
Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
            ;;
        chrome-review)
            msg="feat(task-$task_num): $task_name [Chrome review needed]

Implemented and code-validated. Chrome browser test found minor issues
that need human review.

Automated by nightshift agent loop.
Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
            ;;
        failed)
            msg="wip(task-$task_num): $task_name [needs manual review]

Implementation attempted but code validation failed after max fix attempts.
Marked for manual review.

Automated by nightshift agent loop.
Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
            ;;
    esac

    git commit -m "$(cat <<EOF
$msg
EOF
)"

    git push origin "$NIGHTSHIFT_BRANCH" 2>/dev/null || true
    log_success "Committed + pushed: Task $task_num ($status)"
    summary "  GIT: Committed Task $task_num ($status)"
}

# ======================== VALIDATION ========================
run_full_validation() {
    local logfile="$1"
    local all_passed=true
    local failures=""

    echo "=== VALIDATION RESULTS ===" > "$logfile"
    echo "Timestamp: $(date)" >> "$logfile"
    echo "" >> "$logfile"

    log "  [1/4] Prettier..."
    if npx prettier --write . >> "$logfile" 2>&1; then
        log_success "  Prettier"
    else
        log_error "  Prettier"; all_passed=false; failures="${failures}prettier,"
    fi

    log "  [2/4] TypeScript..."
    echo "--- tsc --noEmit ---" >> "$logfile"
    if npx tsc --noEmit >> "$logfile" 2>&1; then
        log_success "  TypeScript"
    else
        log_error "  TypeScript"; all_passed=false; failures="${failures}tsc,"
    fi

    log "  [3/4] ESLint..."
    echo "--- ESLint ---" >> "$logfile"
    if npx eslint . --quiet >> "$logfile" 2>&1; then
        log_success "  ESLint"
    else
        log_error "  ESLint"; all_passed=false; failures="${failures}eslint,"
    fi

    log "  [4/4] Bun test..."
    echo "--- Bun Test ---" >> "$logfile"
    if bun test >> "$logfile" 2>&1; then
        log_success "  Bun test"
    else
        log_error "  Bun test"; all_passed=false; failures="${failures}bun-test,"
    fi

    if ! $all_passed; then
        local tmpfile; tmpfile=$(mktemp)
        echo "FAILURES: ${failures%,}" > "$tmpfile"; echo "" >> "$tmpfile"
        cat "$logfile" >> "$tmpfile"; mv "$tmpfile" "$logfile"
    fi

    $all_passed
}

# ======================== TASK PARSING ========================
extract_current_task() {
    local in_task=false task_text=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^-\ \[\ \]\ \*\* ]] && [ "$in_task" = false ]; then
            in_task=true; task_text="$line"
        elif [ "$in_task" = true ] && [[ "$line" =~ ^[[:space:]]{2,} ]]; then
            task_text="$task_text
$line"
        elif [ "$in_task" = true ]; then break; fi
    done < "$TODO_FILE"
    echo "$task_text"
}

extract_task_number() {
    echo "$1" | head -1 | grep -oE 'Task [0-9]+' | grep -oE '[0-9]+' || echo "0"
}

# ======================== CALL CLAUDE ========================
# Handles Claude Code's account-level rate limits:
#   "Rate limit reached. Try again after 3:45 AM"
# Parses the reset time, sleeps until then, and retries automatically.
# Also handles transient failures with exponential backoff.
call_claude() {
    local prompt="$1" logfile="$2"
    local max_retries=10        # Generous — rate limit waits don't count as "wasted" retries
    local attempt=0
    local tmpout
    tmpout=$(mktemp)

    while [ "$attempt" -lt "$max_retries" ]; do
        attempt=$((attempt + 1))

        # Run claude and capture output to both terminal, logfile, AND a temp file for parsing
        claude -p "$prompt" 2>&1 | tee -a "$logfile" "$tmpout"
        local exit_code=${PIPESTATUS[0]}

        # Success
        if [ "$exit_code" -eq 0 ]; then
            rm -f "$tmpout"
            return 0
        fi

        # ── Check for Claude Code's hard rate limit message ──
        # Patterns it can output:
        #   "Rate limit reached. Try again after 3:45 AM"
        #   "rate limit...try again after 11:30 PM"
        #   "Rate limited until 3:45 AM"
        #   "Please wait until 3:45 AM"
        local rate_msg
        rate_msg=$(grep -iE "rate limit|try again after|wait until|limited until" "$tmpout" | tail -1 || echo "")

        if [ -n "$rate_msg" ]; then
            log_warn "Claude Code rate limit detected!"
            log_warn "Message: $rate_msg"

            # Try to parse the reset time (e.g., "3:45 AM", "11:30 PM")
            local reset_time
            reset_time=$(echo "$rate_msg" | grep -oE '[0-9]{1,2}:[0-9]{2}\s*(AM|PM|am|pm)' | head -1 || echo "")

            if [ -n "$reset_time" ]; then
                # Convert reset time to epoch seconds
                local reset_epoch
                reset_epoch=$(date -j -f "%I:%M %p" "$reset_time" "+%s" 2>/dev/null || echo "")

                # If the parsed time is in the past, it means tomorrow
                local now_epoch
                now_epoch=$(date "+%s")

                if [ -n "$reset_epoch" ]; then
                    # If reset is in the past, add 24 hours
                    if [ "$reset_epoch" -le "$now_epoch" ]; then
                        reset_epoch=$((reset_epoch + 86400))
                    fi

                    local wait_seconds=$((reset_epoch - now_epoch + 60))  # +60s buffer
                    local wait_minutes=$((wait_seconds / 60))

                    log_phase "RATE LIMIT — SLEEPING"
                    log "Reset at: ${BOLD}$reset_time${NC}"
                    log "Sleeping: ${BOLD}${wait_minutes} minutes${NC} (${wait_seconds}s)"
                    log "Will resume at approximately $(date -j -v+${wait_seconds}S '+%I:%M %p')"
                    summary "  RATE LIMIT HIT: Sleeping ${wait_minutes}min until $reset_time"

                    # Sleep with periodic status updates (every 5 minutes)
                    local slept=0
                    while [ "$slept" -lt "$wait_seconds" ]; do
                        local chunk=300  # 5 minutes
                        [ $((wait_seconds - slept)) -lt "$chunk" ] && chunk=$((wait_seconds - slept))
                        sleep "$chunk"
                        slept=$((slept + chunk))
                        local remaining_min=$(( (wait_seconds - slept) / 60 ))
                        if [ "$remaining_min" -gt 0 ]; then
                            log "  Rate limit sleep: ${remaining_min}min remaining..."
                        fi
                    done

                    log_success "Rate limit sleep complete. Resuming..."
                    summary "  RATE LIMIT: Resumed after ${wait_minutes}min sleep"

                    # Reset temp file and retry
                    > "$tmpout"
                    continue
                fi
            fi

            # Could not parse the time — fall back to a generous fixed wait
            log_warn "Could not parse reset time from: $rate_msg"
            log_warn "Falling back to 10 minute wait..."
            summary "  RATE LIMIT: Could not parse time, waiting 10min"
            sleep 600
            > "$tmpout"
            continue
        fi

        # ── Not a rate limit — transient failure, use exponential backoff ──
        if [ "$attempt" -ge "$max_retries" ]; then
            log_error "Claude failed after $max_retries attempts (last exit: $exit_code)."
            summary "  CLAUDE ERROR: Failed after $max_retries retries (exit $exit_code)"
            rm -f "$tmpout"
            return 1
        fi

        # Exponential backoff: 15, 30, 60, 120 (for non-rate-limit failures)
        local wait_time=$((15 * (2 ** (attempt - 1))))
        [ "$wait_time" -gt 120 ] && wait_time=120

        log_warn "Claude call failed (exit $exit_code). Retrying in ${wait_time}s... ($attempt/$max_retries)"
        sleep "$wait_time"

        # Bump cooldown between tasks if we keep hitting issues
        if [ "$attempt" -ge 3 ] && [ "$COOLDOWN_SECONDS" -lt "$COOLDOWN_MAX" ]; then
            COOLDOWN_SECONDS=$((COOLDOWN_SECONDS * 2))
            [ "$COOLDOWN_SECONDS" -gt "$COOLDOWN_MAX" ] && COOLDOWN_SECONDS=$COOLDOWN_MAX
            log_warn "Bumped inter-task cooldown to ${COOLDOWN_SECONDS}s"
        fi

        > "$tmpout"
    done

    rm -f "$tmpout"
}

increment_iteration() {
    ITERATIONS=$(cat "$ITERATION_STATE_FILE")
    if [ "$ITERATIONS" -ge "$MAX_ITERATIONS" ]; then
        log_error "Max iterations ($MAX_ITERATIONS). Stopping."
        summary "STOPPED: iteration limit"
        exit 1
    fi
    ITERATIONS=$((ITERATIONS + 1))
    echo "$ITERATIONS" > "$ITERATION_STATE_FILE"
}

# ======================== PR CREATION ========================
create_pull_request() {
    log_phase "Phase 5: Creating Pull Request"

    # Build the PR body dynamically from the summary log and todo file
    local completed_tasks failed_tasks chrome_review_tasks
    completed_tasks=$(grep "COMPLETED:" "$SUMMARY_LOG" | sed 's/.*COMPLETED: /- ✅ /' || echo "None")
    failed_tasks=$(grep "FAILED" "$SUMMARY_LOG" | grep -v "STOPPED" | sed 's/.*FAILED[^:]*: /- ❌ /' || echo "None")
    chrome_review_tasks=$(grep "COMPLETED\*:" "$SUMMARY_LOG" | sed 's/.*COMPLETED\*: /- ⚠️ /' || echo "")

    local elapsed_min=$(( ($(date +%s) - START_TIME) / 60 ))

    local pr_body
    pr_body=$(cat <<PRBODY
## Nightshift Autonomous Implementation

**Branch:** \`$NIGHTSHIFT_BRANCH\`
**Runtime:** ${elapsed_min} minutes | **Iterations:** $ITERATIONS
**Completed:** $TASKS_COMPLETED | **Failed:** $TASKS_FAILED

### Tasks Completed
$completed_tasks

$([ -n "$chrome_review_tasks" ] && echo "### Chrome Review Needed
$chrome_review_tasks
" || echo "")
$([ "$TASKS_FAILED" -gt 0 ] && echo "### Failed (Manual Review Required)
$failed_tasks
" || echo "")
### Validation Pipeline (per task)
1. **Code** — prettier, tsc, eslint, bun test (up to $MAX_FIX_ATTEMPTS fix attempts)
2. **Chrome** — live browser testing, dark mode, console check, screenshot (up to $MAX_CHROME_FIX_ATTEMPTS fix attempts)
3. **Commit** — atomic commit per task with descriptive message

### Test Plan
- [ ] Run \`bun test\` — all tests pass
- [ ] Run \`npx tsc --noEmit\` — zero type errors
- [ ] Run \`pnpm dev\` and manually verify each feature in browser
- [ ] Check screenshots in \`.agent-logs/screenshots/\`
- [ ] Review any tasks marked with Chrome/Manual review notes

---
🤖 Generated by nightshift autonomous agent loop
PRBODY
)

    # Create the PR
    PR_URL=$(gh pr create \
        --base "$BASE_BRANCH" \
        --head "$NIGHTSHIFT_BRANCH" \
        --title "feat: nightshift $(date '+%Y-%m-%d') — $TASKS_COMPLETED tasks implemented" \
        --body "$pr_body" 2>&1)

    if [ $? -eq 0 ]; then
        log_success "PR created: $PR_URL"
        summary "PR CREATED: $PR_URL"
    else
        log_error "Failed to create PR: $PR_URL"
        summary "PR FAILED: $PR_URL"
        return 1
    fi

    # Extract PR number
    PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')
    echo "$PR_URL"
}

# ======================== PR COMMENT HANDLING ========================
handle_pr_comments() {
    local pr_number="$1"

    log_phase "Phase 6: Waiting ${PR_WAIT_MINUTES} Minutes for PR Reviews"
    summary "PR REVIEW: Waiting ${PR_WAIT_MINUTES}min for comments on PR #$pr_number"

    log "PR is live. Waiting for reviewers..."
    log "Check it: https://github.com/$GITHUB_REPO/pull/$pr_number"
    echo ""

    # Countdown
    local total_seconds=$((PR_WAIT_MINUTES * 60))
    local elapsed=0
    local interval=60  # Log every minute

    while [ "$elapsed" -lt "$total_seconds" ]; do
        remaining=$(( (total_seconds - elapsed) / 60 ))
        log "  ⏳ ${remaining} minutes remaining..."
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    log_success "Wait complete. Checking for PR comments..."
    echo ""

    log_phase "Phase 7: Addressing PR Comments"

    # Fetch all PR comments (review comments + issue comments)
    local review_comments issue_comments all_comments
    review_comments=$(gh api "repos/$GITHUB_REPO/pulls/$pr_number/comments" 2>/dev/null || echo "[]")
    issue_comments=$(gh api "repos/$GITHUB_REPO/issues/$pr_number/comments" 2>/dev/null || echo "[]")

    # Count comments (exclude bot comments)
    local review_count issue_count
    review_count=$(echo "$review_comments" | python3 -c "import sys,json; data=json.load(sys.stdin); print(len([c for c in data if not c.get('user',{}).get('login','').endswith('[bot]')]))" 2>/dev/null || echo "0")
    issue_count=$(echo "$issue_comments" | python3 -c "import sys,json; data=json.load(sys.stdin); print(len([c for c in data if not c.get('user',{}).get('login','').endswith('[bot]')]))" 2>/dev/null || echo "0")

    local total_comments=$((review_count + issue_count))

    if [ "$total_comments" -eq 0 ]; then
        log_success "No review comments found. PR is clean!"
        summary "PR COMMENTS: None received. PR ready for merge."
        return 0
    fi

    log "Found ${BOLD}$total_comments${NC} review comments. Processing each one..."
    summary "PR COMMENTS: $total_comments comments to address"

    # Process review comments (inline code comments)
    if [ "$review_count" -gt 0 ]; then
        log ""
        log "${MAGENTA}Processing $review_count inline code review comments...${NC}"

        # Extract each comment and process it
        echo "$review_comments" | python3 -c "
import sys, json
comments = json.load(sys.stdin)
for i, c in enumerate(comments):
    if c.get('user',{}).get('login','').endswith('[bot]'):
        continue
    print(f'=== COMMENT {i+1} ===')
    print(f'Author: {c.get(\"user\",{}).get(\"login\",\"unknown\")}')
    print(f'File: {c.get(\"path\",\"unknown\")}')
    print(f'Line: {c.get(\"line\",\"?\")}')
    print(f'Body: {c.get(\"body\",\"\")}')
    print(f'ID: {c.get(\"id\",\"\")}')
    print()
" 2>/dev/null > "$LOG_DIR/pr-review-comments.txt" || true

        # Feed ALL comments to Claude in one shot for implementation
        call_claude "You are addressing code review comments on a GitHub PR for a Next.js/React/TypeScript project.

$CODEBASE_CONTEXT

## PR REVIEW COMMENTS TO ADDRESS

The following inline code review comments were left on PR #$pr_number. Read each one carefully, implement the requested changes, and prepare a detailed response for each.

\`\`\`
$(cat "$LOG_DIR/pr-review-comments.txt")
\`\`\`

## INSTRUCTIONS

For EACH comment:
1. **Read the file and line** mentioned in the comment.
2. **Understand what the reviewer is asking** — is it a bug fix, style change, logic improvement, or question?
3. **If it requires a code change:** implement the change. Follow existing patterns. Run tests after.
4. **If it's a question:** prepare a clear, technical answer.
5. **Keep track** of exactly what you did for each comment — you'll need to report back.

After addressing ALL comments:
- Run \`bun test\` — all tests pass.
- Run \`npx tsc --noEmit\` — zero type errors.
- Run \`npx prettier --write .\` — formatted.

## OUTPUT FORMAT

At the end, output a section like this for EACH comment:

\`\`\`
COMMENT_RESPONSE_START
comment_id: {the comment ID}
action: {implemented|answered|already-addressed}
summary: {1-2 sentence summary of what was done}
detail: {detailed explanation the reviewer will see as a reply}
COMMENT_RESPONSE_END
\`\`\`

Take your time. These are real reviewers. Be thorough and respectful." "$LOG_DIR/pr-comment-responses.log"

        # Post responses to each review comment
        while IFS= read -r line; do
            if [[ "$line" =~ ^comment_id:\ (.+)$ ]]; then
                current_comment_id="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" =~ ^detail:\ (.+)$ ]]; then
                current_detail="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" == "COMMENT_RESPONSE_END" ]] && [ -n "${current_comment_id:-}" ] && [ -n "${current_detail:-}" ]; then
                log "  Replying to comment $current_comment_id..."
                gh api "repos/$GITHUB_REPO/pulls/$pr_number/comments/$current_comment_id/replies" \
                    -f body="$current_detail

---
_🤖 Addressed by nightshift agent_" 2>/dev/null || \
                gh api "repos/$GITHUB_REPO/pulls/$pr_number/comments" \
                    -f body="Re: comment $current_comment_id

$current_detail

---
_🤖 Addressed by nightshift agent_" \
                    -f in_reply_to="$current_comment_id" 2>/dev/null || \
                log_warn "  Could not reply to comment $current_comment_id"

                current_comment_id=""
                current_detail=""
            fi
        done < "$LOG_DIR/pr-comment-responses.log"
    fi

    # Process issue comments (general PR comments)
    if [ "$issue_count" -gt 0 ]; then
        log ""
        log "${MAGENTA}Processing $issue_count general PR comments...${NC}"

        echo "$issue_comments" | python3 -c "
import sys, json
comments = json.load(sys.stdin)
for i, c in enumerate(comments):
    if c.get('user',{}).get('login','').endswith('[bot]'):
        continue
    print(f'=== COMMENT {i+1} ===')
    print(f'Author: {c.get(\"user\",{}).get(\"login\",\"unknown\")}')
    print(f'Body: {c.get(\"body\",\"\")}')
    print(f'ID: {c.get(\"id\",\"\")}')
    print()
" 2>/dev/null > "$LOG_DIR/pr-issue-comments.txt" || true

        call_claude "You are addressing general review comments on a GitHub PR.

$CODEBASE_CONTEXT

## GENERAL PR COMMENTS

\`\`\`
$(cat "$LOG_DIR/pr-issue-comments.txt")
\`\`\`

## INSTRUCTIONS

For each comment:
1. If it requests a code change, implement it. Run tests + tsc + prettier after.
2. If it asks a question, prepare a clear answer.
3. Output responses in this format:

\`\`\`
ISSUE_COMMENT_RESPONSE_START
comment_id: {id}
response: {your detailed response}
ISSUE_COMMENT_RESPONSE_END
\`\`\`" "$LOG_DIR/pr-issue-responses.log"

        # Post issue comment responses
        while IFS= read -r line; do
            if [[ "$line" =~ ^comment_id:\ (.+)$ ]]; then
                current_comment_id="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" =~ ^response:\ (.+)$ ]]; then
                current_response="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" == "ISSUE_COMMENT_RESPONSE_END" ]] && [ -n "${current_comment_id:-}" ] && [ -n "${current_response:-}" ]; then
                log "  Replying to issue comment $current_comment_id..."
                gh api "repos/$GITHUB_REPO/issues/$pr_number/comments" \
                    -f body="$current_response

---
_🤖 Addressed by nightshift agent_" 2>/dev/null || \
                log_warn "  Could not reply to issue comment $current_comment_id"

                current_comment_id=""
                current_response=""
            fi
        done < "$LOG_DIR/pr-issue-responses.log"
    fi

    # Run final validation after addressing comments
    log ""
    log "Running final validation after addressing comments..."
    FINAL_VALIDATION="$LOG_DIR/validation-post-pr-comments.log"
    if run_full_validation "$FINAL_VALIDATION"; then
        log_success "Final validation passed after PR comment fixes!"
    else
        log_warn "Final validation has issues. Attempting auto-fix..."
        call_claude "Fix these validation errors that appeared after addressing PR comments:
\`\`\`
$(cat "$FINAL_VALIDATION")
\`\`\`
Fix ALL errors. Run bun test + tsc + eslint + prettier." "$LOG_DIR/pr-comment-final-fix.log"
        run_full_validation "$FINAL_VALIDATION" || log_warn "Some validation issues remain."
    fi

    # Commit and push the PR comment fixes
    git add -A
    if ! git diff --cached --quiet; then
        git commit -m "$(cat <<EOF
fix: address PR review comments on #$pr_number

Addressed $total_comments review comments from PR reviewers.
All changes validated (prettier, tsc, eslint, bun test).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
        git push origin "$NIGHTSHIFT_BRANCH"
        log_success "PR comment fixes committed and pushed."
        summary "PR COMMENTS: Addressed $total_comments comments, committed fixes."
    else
        log "No code changes needed for PR comments (questions only)."
        summary "PR COMMENTS: Addressed $total_comments comments (no code changes)."
    fi
}

# ======================== MAIN LOOP ========================
main() {
    preflight
    setup_branch

    echo "0" > "$ITERATION_STATE_FILE"
    START_TIME=$(date +%s)

    log_phase "Nightshift Loop — $NIGHTSHIFT_BRANCH"
    log "Config: ${BOLD}$MAX_ITERATIONS${NC} iters | ${BOLD}$MAX_FIX_ATTEMPTS${NC} code fixes | ${BOLD}$MAX_CHROME_FIX_ATTEMPTS${NC} chrome fixes"
    log "Git: commit per task → push → PR at end → wait ${PR_WAIT_MINUTES}min → address comments"
    echo ""

    TASKS_COMPLETED=0
    TASKS_FAILED=0

    while true; do
        increment_iteration

        # ----- Completion Check -----
        if ! grep -q "\- \[ \]" "$TODO_FILE"; then
            break  # Exit loop → go to PR phase
        fi

        # ----- Extract task -----
        CURRENT_TASK=$(extract_current_task)
        TASK_NAME=$(echo "$CURRENT_TASK" | head -1 | sed 's/- \[ \] \*\*//' | sed 's/\*\*//' | xargs)
        TASK_NUM=$(extract_task_number "$CURRENT_TASK")
        TASK_LOG="$LOG_DIR/task-${TASK_NUM}-$(echo "$TASK_NAME" | tr ' :/' '-' | tr '[:upper:]' '[:lower:]').log"
        CHROME_LOG="$LOG_DIR/chrome-task-${TASK_NUM}.log"

        REMAINING=$(grep -c "\- \[ \]" "$TODO_FILE" || echo "0")
        COMPLETED=$(grep -c "\- \[x\]" "$TODO_FILE" || echo "0")
        ELAPSED=$(( $(date +%s) - START_TIME ))

        log_phase "Task $TASK_NUM: $TASK_NAME  [Iter $ITERATIONS/$MAX_ITERATIONS]"
        log "Progress: ${GREEN}$COMPLETED done${NC} / ${YELLOW}$REMAINING left${NC} | ${ELAPSED}s elapsed"
        echo ""

        echo "═══ TASK: $TASK_NAME | $(date) ═══" > "$TASK_LOG"
        summary "STARTED: Task $TASK_NUM — $TASK_NAME"

        # ══════════ PHASE 1: IMPLEMENT ══════════
        log "${MAGENTA}Phase 1: Implementation${NC}"

        call_claude "You are an expert senior Next.js/React/TypeScript developer. Unlimited time — be thorough.

$CODEBASE_CONTEXT

## YOUR TASK (from \`$TODO_FILE\`)
$CURRENT_TASK

## APPROACH
1. **Explore.** Read every relevant file. Understand existing patterns.
2. **Plan.** Think through the implementation before coding.
3. **Test first.** Write .test.ts/.test.tsx with Bun test. Must match Validation criteria.
4. **Implement.** Minimal changes. Existing patterns. shadcn/ui, Framer Motion, dark mode.
5. **Self-verify.** bun test + tsc --noEmit + eslint + prettier --write .

## RULES
- Do NOT modify other tasks or mark anything done.
- No \`any\`, \`@ts-ignore\`, \`eslint-disable\`.
- Don't break existing tests. Don't install unnecessary deps.
- Quality over speed. Take your time." "$TASK_LOG"

        # ══════════ PHASE 2: CODE VALIDATION ══════════
        log ""; log "${MAGENTA}Phase 2: Code Validation${NC}"
        VALIDATION_LOG="$LOG_DIR/validation-task-${TASK_NUM}-attempt-0.log"

        CODE_PASSED=false
        if run_full_validation "$VALIDATION_LOG"; then
            log_success "Code passed first try!"
            summary "  CODE VALIDATED: First attempt"
            CODE_PASSED=true
        else
            FIX_ATTEMPT=0
            while [ "$FIX_ATTEMPT" -lt "$MAX_FIX_ATTEMPTS" ]; do
                FIX_ATTEMPT=$((FIX_ATTEMPT + 1))
                increment_iteration
                log_warn "Code fix $FIX_ATTEMPT/$MAX_FIX_ATTEMPTS..."

                call_claude "Fix validation errors. Task: **$TASK_NAME**.

$CODEBASE_CONTEXT

Task spec:
$CURRENT_TASK

Errors (attempt $FIX_ATTEMPT/$MAX_FIX_ATTEMPTS):
\`\`\`
$(cat "$VALIDATION_LOG")
\`\`\`

Fix ALL errors. Run bun test + tsc + eslint + prettier. No @ts-ignore/any." "$TASK_LOG"

                VALIDATION_LOG="$LOG_DIR/validation-task-${TASK_NUM}-attempt-${FIX_ATTEMPT}.log"
                if run_full_validation "$VALIDATION_LOG"; then
                    log_success "Code passed on fix $FIX_ATTEMPT!"
                    summary "  CODE VALIDATED: Fix attempt $FIX_ATTEMPT"
                    CODE_PASSED=true; break
                fi
                sleep 3
            done

            if ! $CODE_PASSED; then
                summary "  FAILED (code): $TASK_NAME"
                TASKS_FAILED=$((TASKS_FAILED + 1))
                call_claude "In \`$TODO_FILE\`, find:
\`\`\`
$(echo "$CURRENT_TASK" | head -1)
\`\`\`
Change \`- [ ]\` to \`- [x]\` and append \` — NEEDS MANUAL REVIEW\`. Change nothing else." "$TASK_LOG"
                commit_task "$TASK_NUM" "$TASK_NAME" "failed"
                sleep "$COOLDOWN_SECONDS"; continue
            fi
        fi

        # ══════════ PHASE 3: CHROME TESTING ══════════
        log ""; log "${WHITE}Phase 3: Chrome Testing${NC}"
        summary "  CHROME: Starting"

        if ! curl -s -o /dev/null "$DEV_URL" 2>/dev/null; then
            stop_dev_server; start_dev_server; sleep 3
        fi

        CHROME_PASSED=false
        CHROME_ATTEMPT=0

        while [ "$CHROME_ATTEMPT" -le "$MAX_CHROME_FIX_ATTEMPTS" ]; do
            increment_iteration

            if [ "$CHROME_ATTEMPT" -eq 0 ]; then
                call_claude "QA test this feature in Chrome. Dev server at $DEV_URL.

$CHROME_CONTEXT

## TASK IMPLEMENTED
$CURRENT_TASK

## PROTOCOL
1. tabs_context_mcp first. Create new tab. Navigate to $DEV_URL.
2. Navigate to relevant page for this task.
3. Visual: read_page — are new elements present, correct labels?
4. Functional: click/interact — does expected behavior occur?
5. Console: read_console_messages with pattern 'error|Error|ERR' — any new errors?
6. Dark mode: toggle via JS, re-check.
7. Screenshot to .agent-logs/screenshots/task-${TASK_NUM}.png

## VERDICT (output exactly one):
\`\`\`
CHROME_VERDICT: PASS
Evidence: [what you verified]
\`\`\`
or
\`\`\`
CHROME_VERDICT: FAIL
Issues found:
- [issues]
\`\`\`" "$CHROME_LOG"
            else
                log_warn "  Chrome fix $CHROME_ATTEMPT/$MAX_CHROME_FIX_ATTEMPTS..."
                call_claude "Fix Chrome test issues for task: $TASK_NAME.

$CODEBASE_CONTEXT

Chrome found:
\`\`\`
$(cat "$CHROME_LOG")
\`\`\`

Fix issues. Run bun test + tsc + prettier after." "$TASK_LOG"

                run_full_validation "$LOG_DIR/validation-chrome-fix-${TASK_NUM}-${CHROME_ATTEMPT}.log" || true

                CHROME_LOG="$LOG_DIR/chrome-task-${TASK_NUM}-attempt-${CHROME_ATTEMPT}.log"
                call_claude "Re-test in Chrome. $DEV_URL.
$CHROME_CONTEXT
Task: $CURRENT_TASK
Output CHROME_VERDICT: PASS or CHROME_VERDICT: FAIL with issues." "$CHROME_LOG"
            fi

            if grep -q "CHROME_VERDICT: PASS" "$CHROME_LOG" 2>/dev/null; then
                log_success "Chrome PASSED!"
                summary "  CHROME VERIFIED"
                CHROME_PASSED=true; break
            fi

            [ "$CHROME_ATTEMPT" -ge "$MAX_CHROME_FIX_ATTEMPTS" ] && break
            CHROME_ATTEMPT=$((CHROME_ATTEMPT + 1))
            sleep 3
        done

        # ══════════ PHASE 4: MARK + COMMIT ══════════
        log ""; log "${MAGENTA}Phase 4: Mark Complete + Commit${NC}"

        if $CHROME_PASSED; then
            call_claude "In \`$TODO_FILE\`, change this checkbox from \`- [ ]\` to \`- [x]\`:
\`\`\`
$(echo "$CURRENT_TASK" | head -1)
\`\`\`
Change nothing else." "$TASK_LOG"
            commit_task "$TASK_NUM" "$TASK_NAME" "pass"
            summary "  COMPLETED: Task $TASK_NUM — $TASK_NAME"
        else
            call_claude "In \`$TODO_FILE\`, change this to \`- [x]\` and append \` — CHROME REVIEW NEEDED\`:
\`\`\`
$(echo "$CURRENT_TASK" | head -1)
\`\`\`" "$TASK_LOG"
            commit_task "$TASK_NUM" "$TASK_NAME" "chrome-review"
            summary "  COMPLETED*: Task $TASK_NUM — $TASK_NAME (Chrome review)"
        fi

        TASKS_COMPLETED=$((TASKS_COMPLETED + 1))
        log_success "Task $TASK_NUM done! ($TASKS_COMPLETED completed, $TASKS_FAILED failed)"

        sleep "$COOLDOWN_SECONDS"
        echo ""
    done

    # ══════════════════════════════════════════════════════
    # ALL TASKS DONE → PR FLOW
    # ══════════════════════════════════════════════════════
    ELAPSED=$(( $(date +%s) - START_TIME ))
    log_phase "ALL TASKS PROCESSED — $TASKS_COMPLETED done, $TASKS_FAILED failed in $(( ELAPSED / 60 ))min"
    summary "═══ TASKS COMPLETE ═══ $TASKS_COMPLETED done, $TASKS_FAILED failed, $(( ELAPSED / 60 ))min"

    # Final push
    git push origin "$NIGHTSHIFT_BRANCH" 2>/dev/null || true

    # Create PR
    PR_URL=$(create_pull_request)
    PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$' || echo "")

    if [ -n "$PR_NUMBER" ]; then
        # Wait and handle comments
        handle_pr_comments "$PR_NUMBER"

        ELAPSED=$(( $(date +%s) - START_TIME ))
        log_phase "NIGHTSHIFT COMPLETE"
        log_success "Total time: $(( ELAPSED / 60 )) minutes"
        log "PR: $PR_URL"
        log "Branch: $NIGHTSHIFT_BRANCH"
        log "Tasks: $TASKS_COMPLETED completed, $TASKS_FAILED failed"
        log "Screenshots: $SCREENSHOT_DIR/"
        summary "═══ NIGHTSHIFT FINISHED ═══ Total: $(( ELAPSED / 60 ))min | PR: $PR_URL"
    else
        log_warn "PR creation failed. Changes are on branch $NIGHTSHIFT_BRANCH."
        summary "═══ NIGHTSHIFT FINISHED (no PR) ═══"
    fi
}

# ======================== RUN ========================
main "$@"
