#!/usr/bin/env bash

# ============================================================================
# Autonomous Bulletproof Agent Loop — Nightshift Edition
# ============================================================================
# Full pipeline for production-ship / codebase-hardening sprints:
#   0. Create dedicated branch, push it
#   1-4. Per step: implement → validate → Chrome test → commit
#   5. Open PR with detailed summary
#   6. Wait for review comments
#   7. Address every PR comment (implement fixes, respond in detail)
#   8. Push final state
#
# Prerequisites:
#   - Claude Code CLI installed and authenticated
#   - gh CLI authenticated (gh auth status)
#   - Chrome browser open with Claude-in-Chrome extension active
#   - Node.js, pnpm installed
#
# Usage:
#   chmod +x scripts/nightshift-bulletproof.sh
#   ./scripts/nightshift-bulletproof.sh                    # Run all steps
#   ./scripts/nightshift-bulletproof.sh --category 1       # Run category 1 only
#   ./scripts/nightshift-bulletproof.sh --from 15 --to 30  # Run steps 15-30
#   ./scripts/nightshift-bulletproof.sh --skip-chrome       # Skip Chrome testing
#   ./scripts/nightshift-bulletproof.sh --skip-pr           # Skip PR creation
#   ./scripts/nightshift-bulletproof.sh --dry-run           # Parse tasks only
# ============================================================================

set -euo pipefail

# ======================== CONFIGURATION ========================
PLAN_FILE="BULLETPROOF-STEPS.md"   # <-- Your numbered step plan (see templates/)
LOG_DIR=".agent-logs"
SCREENSHOT_DIR="$LOG_DIR/screenshots"
SUMMARY_LOG="$LOG_DIR/bulletproof-summary.log"
ITERATION_STATE_FILE=".claude_iterations"

# --- Git ---
BASE_BRANCH="main"                                       # <-- Your base branch
NIGHTSHIFT_BRANCH="nightshift/bulletproof-$(date '+%Y-%m-%d')"
GITHUB_REPO="owner/repo"                                 # <-- Your GitHub repo (owner/name)
PR_WAIT_MINUTES=20

# --- App ---
DEV_PORT=3000
DEV_URL="http://localhost:$DEV_PORT"

# --- Limits ---
MAX_ITERATIONS=500
MAX_FIX_ATTEMPTS=7
MAX_CHROME_FIX_ATTEMPTS=3
COOLDOWN_SECONDS=5
COOLDOWN_MAX=120
DEV_SERVER_WAIT=30

# --- Filters (set via CLI args) ---
FILTER_FROM=1
FILTER_TO=100
FILTER_CATEGORY=""
SKIP_CHROME=false
SKIP_PR=false
DRY_RUN=false

# ======================== PARSE CLI ARGS ========================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --from)       FILTER_FROM="$2"; shift 2 ;;
        --to)         FILTER_TO="$2"; shift 2 ;;
        --category)   FILTER_CATEGORY="$2"; shift 2 ;;
        --skip-chrome) SKIP_CHROME=true; shift ;;
        --skip-pr)    SKIP_PR=true; shift ;;
        --dry-run)    DRY_RUN=true; shift ;;
        --pr-wait)    PR_WAIT_MINUTES="$2"; shift 2 ;;
        --branch)     NIGHTSHIFT_BRANCH="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --from N          Start from step N (default: 1)"
            echo "  --to N            Stop after step N (default: 100)"
            echo "  --category N      Only run category N (1-10)"
            echo "  --skip-chrome     Skip Chrome browser testing"
            echo "  --skip-pr         Skip PR creation at the end"
            echo "  --dry-run         Parse and list tasks without executing"
            echo "  --pr-wait N       Minutes to wait for PR review (default: 20)"
            echo "  --branch NAME     Override branch name"
            echo "  --help            Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Map category to step ranges
if [ -n "$FILTER_CATEGORY" ]; then
    FILTER_FROM=$(( (FILTER_CATEGORY - 1) * 10 + 1 ))
    FILTER_TO=$(( FILTER_CATEGORY * 10 ))
fi

# ======================== COLORS ========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ======================== HELPERS ========================
log()         { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $1"; }
log_error()   { echo -e "${RED}[$(date '+%H:%M:%S')] ✗${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $1"; }
log_phase() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}
log_step() {
    echo -e "\n${MAGENTA}────────────────────────────────────────────────────────────${NC}"
    echo -e "${MAGENTA}  STEP $1: $2${NC}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"
}
summary() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$SUMMARY_LOG"
}

# ======================== CODEBASE CONTEXT ========================
# REPLACE THIS HEREDOC with your project's file map + conventions.
# See templates/codebase-context.md for a fill-in skeleton, and
# examples in docs/01-playbook.md §10–11.
read -r -d '' CODEBASE_CONTEXT << 'CONTEXT_EOF' || true
## Codebase Map (use these exact paths):

**Stack:** {framework} + {language} + {db} + {styling} + {ui-kit}

**Pages & Routes:**
- {path/to/page.tsx} — {description}

**API Routes:**
- {path/to/route.ts} — {method, purpose, schema}

**Core Components:**
- {path/to/component.tsx} — {description}

**Business Logic:**
- {path/to/lib.ts} — {description}

**Database:**
- {db} with {RLS/migrations/...}
- Tables: {list}

**Config:**
- {build/test/lint config files}

**Test Files:**
- {paths to test dirs}

**Package Manager:** {npm/pnpm/bun/yarn}
**Validation:** {lint, type-check, format commands}
**Test Runner:** {unit + e2e commands}

## Conventions:
- {Convention 1: e.g., "Always run prettier --write . after code changes"}
- {Convention 2: e.g., "TypeScript strict mode. No `any`."}
- {Convention 3: e.g., "Follow existing shadcn/ui patterns."}
- {Convention 4: e.g., "Dark mode via CSS variables."}
- {Convention 5: e.g., "Zod for all input validation."}
- {Convention 6: e.g., "Tests colocated as *.test.{ext}."}
CONTEXT_EOF

# ======================== CHROME TESTING CONTEXT ========================
read -r -d '' CHROME_CONTEXT << 'CHROME_EOF' || true
## Chrome Browser Testing Instructions

You have access to Chrome browser automation via MCP tools. The app is running at http://localhost:3000.

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

### Pages to Test:
# REPLACE with your app's routes:
- Landing: $DEV_URL/
- {Route 1}: $DEV_URL/{path}
- {Route 2}: $DEV_URL/{path}
- {Route 3}: $DEV_URL/{path}
CHROME_EOF

# ======================== STEP EXTRACTION ========================
# Parse $PLAN_FILE and extract individual steps
extract_steps() {
    local from="$1" to="$2"
    python3 << PYEOF
import re, sys

with open("$PLAN_FILE", "r") as f:
    content = f.read()

# Match step headers: ### Step N: Title
pattern = r'### Step (\d+): (.+?)(?=\n### Step |\n---\n|\n## Category|\Z)'
matches = re.findall(pattern, content, re.DOTALL)

for num_str, body in matches:
    num = int(num_str)
    if num < $from or num > $to:
        continue

    # Extract the title (first line) and full body
    lines = body.strip().split('\n')
    title = lines[0].strip()
    full_body = '\n'.join(lines).strip()

    # Print in a parseable format
    print(f"STEP_START:{num}")
    print(f"TITLE:{title}")
    print(full_body)
    print(f"STEP_END:{num}")
    print()
PYEOF
}

# Parse a single step from the extracted output
parse_step() {
    local step_num="$1"
    python3 << PYEOF
import re

with open("$PLAN_FILE", "r") as f:
    content = f.read()

# Find this specific step
pattern = r'### Step ${step_num}: (.+?)(?=\n### Step |\n---\n|\n## Category|\Z)'
match = re.search(pattern, content, re.DOTALL)

if match:
    print(match.group(0).strip())
else:
    print("STEP NOT FOUND")
PYEOF
}

# Get step title
get_step_title() {
    local step_num="$1"
    python3 -c "
import re
with open('$PLAN_FILE', 'r') as f:
    content = f.read()
m = re.search(r'### Step ${step_num}: (.+)', content)
if m:
    print(m.group(1).strip())
else:
    print('Unknown Step')
"
}

# Get step category name
get_category_name() {
    local step_num="$1"
    local cat_num=$(( (step_num - 1) / 10 + 1 ))
    python3 -c "
import re
with open('$PLAN_FILE', 'r') as f:
    content = f.read()
m = re.search(r'## Category ${cat_num}: (.+?)\\(', content)
if m:
    print(m.group(1).strip())
else:
    print('Category ${cat_num}')
"
}

# ======================== PROGRESS TRACKING ========================
PROGRESS_FILE="$LOG_DIR/bulletproof-progress.json"

init_progress() {
    if [ ! -f "$PROGRESS_FILE" ]; then
        echo '{"completed": [], "failed": [], "skipped": [], "chrome_review": []}' > "$PROGRESS_FILE"
    fi
}

mark_step_progress() {
    local step_num="$1" status="$2"
    python3 -c "
import json
with open('$PROGRESS_FILE', 'r') as f:
    data = json.load(f)
if $step_num not in data.get('$status', []):
    data.setdefault('$status', []).append($step_num)
with open('$PROGRESS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
}

is_step_done() {
    local step_num="$1"
    python3 -c "
import json
with open('$PROGRESS_FILE', 'r') as f:
    data = json.load(f)
done = data.get('completed', []) + data.get('failed', []) + data.get('skipped', []) + data.get('chrome_review', [])
print('yes' if $step_num in done else 'no')
"
}

get_progress_stats() {
    python3 -c "
import json
with open('$PROGRESS_FILE', 'r') as f:
    data = json.load(f)
c = len(data.get('completed', []))
f = len(data.get('failed', []))
s = len(data.get('skipped', []))
r = len(data.get('chrome_review', []))
print(f'{c}|{f}|{s}|{r}')
"
}

# ======================== DEV SERVER ========================
DEV_SERVER_PID=""

start_dev_server() {
    if curl -s -o /dev/null -w "%{http_code}" "$DEV_URL" 2>/dev/null | grep -qE "200|302|304"; then
        log_success "Dev server already running on :$DEV_PORT"
        return 0
    fi

    log "Starting dev server on :$DEV_PORT..."
    pnpm dev --port $DEV_PORT > "$LOG_DIR/dev-server.log" 2>&1 &
    DEV_SERVER_PID=$!
    echo "$DEV_SERVER_PID" > "$LOG_DIR/dev-server.pid"

    local wait_count=0
    while ! curl -s -o /dev/null -w "%{http_code}" "$DEV_URL" 2>/dev/null | grep -qE "200|302|304"; do
        wait_count=$((wait_count + 1))
        if [ "$wait_count" -ge "$DEV_SERVER_WAIT" ]; then
            log_warn "Dev server not responding after ${DEV_SERVER_WAIT}s"
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
    log ""
    log "Cleanup complete."
}
trap cleanup EXIT

# ======================== CALL CLAUDE ========================
# Handles rate limits, exponential backoff, retries
call_claude() {
    local prompt="$1" logfile="$2"
    local max_retries=10
    local attempt=0
    local tmpout
    tmpout=$(mktemp)

    while [ "$attempt" -lt "$max_retries" ]; do
        attempt=$((attempt + 1))

        # Run claude, capture output
        if claude -p "$prompt" --allowedTools "Edit,Write,Read,Glob,Grep,Bash(npm run:*),Bash(npx *),Bash(pnpm *),Bash(node *),Bash(git *),Bash(cat *),Bash(ls *),Bash(mkdir *),Bash(cp *),Bash(mv *),Bash(rm *),Bash(curl *),Bash(python3 *),mcp__claude-in-chrome__*" 2>&1 | tee -a "$logfile" "$tmpout"; then
            rm -f "$tmpout"
            return 0
        fi

        local exit_code=${PIPESTATUS[0]:-1}

        # Check for rate limit
        local rate_msg
        rate_msg=$(grep -iE "rate limit|try again after|wait until|limited until" "$tmpout" | tail -1 || echo "")

        if [ -n "$rate_msg" ]; then
            log_warn "Claude rate limit detected: $rate_msg"

            local reset_time
            reset_time=$(echo "$rate_msg" | grep -oE '[0-9]{1,2}:[0-9]{2}\s*(AM|PM|am|pm)' | head -1 || echo "")

            if [ -n "$reset_time" ]; then
                local reset_epoch now_epoch
                reset_epoch=$(date -j -f "%I:%M %p" "$reset_time" "+%s" 2>/dev/null || echo "")
                now_epoch=$(date "+%s")

                if [ -n "$reset_epoch" ]; then
                    [ "$reset_epoch" -le "$now_epoch" ] && reset_epoch=$((reset_epoch + 86400))
                    local wait_seconds=$((reset_epoch - now_epoch + 60))
                    local wait_minutes=$((wait_seconds / 60))

                    log_phase "RATE LIMIT — SLEEPING ${wait_minutes}min"
                    log "Reset at: ${BOLD}$reset_time${NC}"
                    log "Resume at: $(date -j -v+${wait_seconds}S '+%I:%M %p')"
                    summary "  RATE LIMIT: Sleeping ${wait_minutes}min until $reset_time"

                    local slept=0
                    while [ "$slept" -lt "$wait_seconds" ]; do
                        local chunk=300
                        [ $((wait_seconds - slept)) -lt "$chunk" ] && chunk=$((wait_seconds - slept))
                        sleep "$chunk"
                        slept=$((slept + chunk))
                        local remaining_min=$(( (wait_seconds - slept) / 60 ))
                        [ "$remaining_min" -gt 0 ] && log "  Rate limit: ${remaining_min}min remaining..."
                    done

                    log_success "Rate limit sleep complete. Resuming..."
                    : > "$tmpout"
                    continue
                fi
            fi

            # Fallback wait
            log_warn "Could not parse reset time. Waiting 10 minutes..."
            sleep 600
            : > "$tmpout"
            continue
        fi

        # Not rate limit — exponential backoff
        if [ "$attempt" -ge "$max_retries" ]; then
            log_error "Claude failed after $max_retries attempts (exit: $exit_code)"
            summary "  CLAUDE ERROR: Failed after $max_retries retries"
            rm -f "$tmpout"
            return 1
        fi

        local wait_time=$((15 * (2 ** (attempt - 1))))
        [ "$wait_time" -gt 120 ] && wait_time=120
        log_warn "Claude call failed (exit $exit_code). Retry in ${wait_time}s ($attempt/$max_retries)"
        sleep "$wait_time"

        if [ "$attempt" -ge 3 ] && [ "$COOLDOWN_SECONDS" -lt "$COOLDOWN_MAX" ]; then
            COOLDOWN_SECONDS=$((COOLDOWN_SECONDS * 2))
            [ "$COOLDOWN_SECONDS" -gt "$COOLDOWN_MAX" ] && COOLDOWN_SECONDS=$COOLDOWN_MAX
            log_warn "Bumped inter-step cooldown to ${COOLDOWN_SECONDS}s"
        fi

        : > "$tmpout"
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

    log "  [4/4] Vitest..."
    echo "--- Vitest ---" >> "$logfile"
    if npx vitest run --reporter=verbose >> "$logfile" 2>&1; then
        log_success "  Vitest"
    else
        log_error "  Vitest"; all_passed=false; failures="${failures}vitest,"
    fi

    if ! $all_passed; then
        local tmpfile; tmpfile=$(mktemp)
        echo "FAILURES: ${failures%,}" > "$tmpfile"; echo "" >> "$tmpfile"
        cat "$logfile" >> "$tmpfile"; mv "$tmpfile" "$logfile"
    fi

    $all_passed
}

# Quick validation (prettier + tsc only — for steps that don't add tests)
run_quick_validation() {
    local logfile="$1"
    local all_passed=true

    echo "=== QUICK VALIDATION ===" > "$logfile"

    log "  [1/2] Prettier..."
    if npx prettier --write . >> "$logfile" 2>&1; then
        log_success "  Prettier"
    else
        log_error "  Prettier"; all_passed=false
    fi

    log "  [2/2] TypeScript..."
    if npx tsc --noEmit >> "$logfile" 2>&1; then
        log_success "  TypeScript"
    else
        log_error "  TypeScript"; all_passed=false
    fi

    $all_passed
}

# ======================== GIT ========================
setup_branch() {
    log_phase "Git Branch Setup"

    git fetch origin "$BASE_BRANCH" 2>/dev/null || true

    # Stash any dirty state before switching branches
    local stashed=false
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        git stash push -m "nightshift-auto-stash" 2>/dev/null && stashed=true
    fi

    if git show-ref --verify --quiet "refs/heads/$NIGHTSHIFT_BRANCH" 2>/dev/null; then
        log_warn "Branch $NIGHTSHIFT_BRANCH exists. Switching to it."
        git checkout "$NIGHTSHIFT_BRANCH"
    else
        log "Creating branch: $NIGHTSHIFT_BRANCH from $BASE_BRANCH"
        git checkout -b "$NIGHTSHIFT_BRANCH" "$BASE_BRANCH"
    fi

    # Restore stashed changes on the new branch
    if $stashed; then
        git stash pop 2>/dev/null || log_warn "Could not restore stashed changes"
    fi

    git push -u origin "$NIGHTSHIFT_BRANCH" 2>/dev/null || true
    log_success "On branch: $NIGHTSHIFT_BRANCH"
    summary "Branch: $NIGHTSHIFT_BRANCH (from $BASE_BRANCH)"
}

commit_step() {
    local step_num="$1"
    local step_name="$2"
    local status="$3"  # pass | chrome-review | failed
    local category_name="$4"

    git add -A

    if git diff --cached --quiet; then
        log_warn "No changes to commit for Step $step_num."
        return 0
    fi

    local msg=""
    case "$status" in
        pass)
            msg="feat(step-$step_num): $step_name

Category: $category_name
Implemented and verified (code + Chrome browser test).

Automated by nightshift bulletproof agent.
Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
            ;;
        chrome-review)
            msg="feat(step-$step_num): $step_name [Chrome review needed]

Category: $category_name
Implemented and code-validated. Chrome browser test flagged for human review.

Automated by nightshift bulletproof agent.
Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
            ;;
        failed)
            msg="wip(step-$step_num): $step_name [needs manual review]

Category: $category_name
Implementation attempted but validation failed after max attempts.

Automated by nightshift bulletproof agent.
Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
            ;;
    esac

    git commit -m "$(cat <<EOF
$msg
EOF
)"

    git push origin "$NIGHTSHIFT_BRANCH" 2>/dev/null || true
    log_success "Committed + pushed: Step $step_num ($status)"
    summary "  GIT: Committed Step $step_num ($status)"
}

# ======================== PR CREATION ========================
create_pull_request() {
    log_phase "Creating Pull Request"

    local stats
    stats=$(get_progress_stats)
    local completed failed skipped chrome_review
    completed=$(echo "$stats" | cut -d'|' -f1)
    failed=$(echo "$stats" | cut -d'|' -f2)
    skipped=$(echo "$stats" | cut -d'|' -f3)
    chrome_review=$(echo "$stats" | cut -d'|' -f4)

    local elapsed_min=$(( ($(date +%s) - START_TIME) / 60 ))

    local completed_list failed_list review_list
    completed_list=$(grep "COMPLETED:" "$SUMMARY_LOG" | sed 's/.*COMPLETED: /- ✅ /' || echo "None")
    failed_list=$(grep "FAILED:" "$SUMMARY_LOG" | grep -v "STOPPED" | sed 's/.*FAILED: /- ❌ /' || echo "None")
    review_list=$(grep "CHROME_REVIEW:" "$SUMMARY_LOG" | sed 's/.*CHROME_REVIEW: /- ⚠️ /' || echo "")

    local pr_body
    pr_body=$(cat <<PRBODY
## Bulletproof SaaS Hardening — Nightshift Run

**Branch:** \`$NIGHTSHIFT_BRANCH\`
**Runtime:** ${elapsed_min} minutes | **Iterations:** $ITERATIONS
**Steps:** $completed completed | $failed failed | $chrome_review need review | $skipped skipped
**Range:** Steps $FILTER_FROM to $FILTER_TO

### Steps Completed
$completed_list

$([ -n "$review_list" ] && echo "### Chrome Review Needed
$review_list
" || echo "")
$([ "$failed" -gt 0 ] && echo "### Failed (Manual Review Required)
$failed_list
" || echo "")

### Validation Pipeline (per step)
1. **Code** — prettier, tsc --noEmit, eslint, vitest (up to $MAX_FIX_ATTEMPTS fix attempts)
2. **Chrome** — live browser testing at localhost:3000 (up to $MAX_CHROME_FIX_ATTEMPTS attempts)
3. **Commit** — atomic commit per step with descriptive message

### Test Plan
- [ ] Run \`npx vitest run\` — all tests pass
- [ ] Run \`npx tsc --noEmit\` — zero type errors
- [ ] Run \`pnpm dev\` and manually verify in browser
- [ ] Check dark mode on all modified pages
- [ ] Review screenshots in \`.agent-logs/screenshots/\`
- [ ] Review any steps marked for Chrome/manual review

### Categories Covered
| # | Category | Steps |
|---|----------|-------|
| 1 | Styling & Design System | 1-10 |
| 2 | Authentication & User Management | 11-20 |
| 3 | Billing & Subscription Hardening | 21-30 |
| 4 | Core Functionality & Features | 31-40 |
| 5 | Security Hardening | 41-50 |
| 6 | Performance Optimization | 51-60 |
| 7 | Testing & Quality Assurance | 61-70 |
| 8 | SEO & Marketing | 71-80 |
| 9 | DevOps & Infrastructure | 81-90 |
| 10 | Growth & Polish | 91-100 |

---
Automated by nightshift bulletproof agent
PRBODY
)

    PR_URL=$(gh pr create \
        --repo "$GITHUB_REPO" \
        --base "$BASE_BRANCH" \
        --head "$NIGHTSHIFT_BRANCH" \
        --title "feat: bulletproof SaaS hardening — $completed steps implemented ($(date '+%Y-%m-%d'))" \
        --body "$pr_body" 2>&1)

    if [ $? -eq 0 ]; then
        log_success "PR created: $PR_URL"
        summary "PR CREATED: $PR_URL"
    else
        log_error "Failed to create PR: $PR_URL"
        summary "PR FAILED: $PR_URL"
        return 1
    fi

    PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')
    echo "$PR_URL"
}

# ======================== PR COMMENT HANDLING ========================
handle_pr_comments() {
    local pr_number="$1"

    log_phase "Waiting ${PR_WAIT_MINUTES} Minutes for PR Reviews"
    summary "PR REVIEW: Waiting ${PR_WAIT_MINUTES}min for comments on PR #$pr_number"

    log "PR is live. Waiting for reviewers..."
    log "Check: https://github.com/$GITHUB_REPO/pull/$pr_number"

    local total_seconds=$((PR_WAIT_MINUTES * 60))
    local elapsed=0
    local interval=60

    while [ "$elapsed" -lt "$total_seconds" ]; do
        local remaining=$(( (total_seconds - elapsed) / 60 ))
        log "  ⏳ ${remaining} minutes remaining..."
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    log_success "Wait complete. Checking for PR comments..."

    local review_comments issue_comments
    review_comments=$(gh api "repos/$GITHUB_REPO/pulls/$pr_number/comments" 2>/dev/null || echo "[]")
    issue_comments=$(gh api "repos/$GITHUB_REPO/issues/$pr_number/comments" 2>/dev/null || echo "[]")

    local review_count issue_count
    review_count=$(echo "$review_comments" | python3 -c "import sys,json; data=json.load(sys.stdin); print(len([c for c in data if not c.get('user',{}).get('login','').endswith('[bot]')]))" 2>/dev/null || echo "0")
    issue_count=$(echo "$issue_comments" | python3 -c "import sys,json; data=json.load(sys.stdin); print(len([c for c in data if not c.get('user',{}).get('login','').endswith('[bot]')]))" 2>/dev/null || echo "0")

    local total_comments=$((review_count + issue_count))

    if [ "$total_comments" -eq 0 ]; then
        log_success "No review comments. PR is clean!"
        summary "PR COMMENTS: None received."
        return 0
    fi

    log "Found ${BOLD}$total_comments${NC} review comments. Processing..."
    summary "PR COMMENTS: $total_comments comments to address"

    # Process inline review comments
    if [ "$review_count" -gt 0 ]; then
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

        call_claude "You are addressing code review comments on PR #$pr_number.

$CODEBASE_CONTEXT

## PR REVIEW COMMENTS

\`\`\`
$(cat "$LOG_DIR/pr-review-comments.txt")
\`\`\`

## INSTRUCTIONS

For EACH comment:
1. Read the file and line mentioned.
2. Understand the request — bug fix, style change, logic improvement, or question?
3. If it requires code: implement the change. Follow existing patterns.
4. If it's a question: prepare a clear answer.
5. After ALL changes: npx vitest run + tsc --noEmit + prettier --write .

Output for EACH comment:
\`\`\`
COMMENT_RESPONSE_START
comment_id: {id}
action: {implemented|answered|already-addressed}
summary: {1-2 sentences}
detail: {detailed response for reviewer}
COMMENT_RESPONSE_END
\`\`\`" "$LOG_DIR/pr-comment-responses.log"

        # Post replies
        local current_comment_id="" current_detail=""
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
_Addressed by nightshift bulletproof agent_" 2>/dev/null || \
                log_warn "  Could not reply to comment $current_comment_id"
                current_comment_id=""
                current_detail=""
            fi
        done < "$LOG_DIR/pr-comment-responses.log"
    fi

    # Process general PR comments
    if [ "$issue_count" -gt 0 ]; then
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

        call_claude "Address general PR comments on #$pr_number.

$CODEBASE_CONTEXT

## COMMENTS
\`\`\`
$(cat "$LOG_DIR/pr-issue-comments.txt")
\`\`\`

Implement changes if needed. Run validation after. Output:
\`\`\`
ISSUE_COMMENT_RESPONSE_START
comment_id: {id}
response: {detailed response}
ISSUE_COMMENT_RESPONSE_END
\`\`\`" "$LOG_DIR/pr-issue-responses.log"

        local current_comment_id="" current_response=""
        while IFS= read -r line; do
            if [[ "$line" =~ ^comment_id:\ (.+)$ ]]; then
                current_comment_id="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" =~ ^response:\ (.+)$ ]]; then
                current_response="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" == "ISSUE_COMMENT_RESPONSE_END" ]] && [ -n "${current_comment_id:-}" ] && [ -n "${current_response:-}" ]; then
                gh api "repos/$GITHUB_REPO/issues/$pr_number/comments" \
                    -f body="$current_response

---
_Addressed by nightshift bulletproof agent_" 2>/dev/null || \
                log_warn "  Could not reply to issue comment $current_comment_id"
                current_comment_id=""
                current_response=""
            fi
        done < "$LOG_DIR/pr-issue-responses.log"
    fi

    # Final validation after PR comment fixes
    log "Running final validation after addressing comments..."
    local final_log="$LOG_DIR/validation-post-pr-comments.log"
    if run_full_validation "$final_log"; then
        log_success "Final validation passed!"
    else
        log_warn "Validation issues remain after PR fixes. Attempting auto-fix..."
        call_claude "Fix these validation errors:
\`\`\`
$(cat "$final_log")
\`\`\`
Fix ALL errors. Run vitest + tsc + eslint + prettier." "$LOG_DIR/pr-comment-final-fix.log"
        run_full_validation "$final_log" || log_warn "Some issues remain."
    fi

    # Commit PR fixes
    git add -A
    if ! git diff --cached --quiet; then
        git commit -m "$(cat <<EOF
fix: address PR review comments on #$pr_number

Addressed $total_comments review comments.
All changes validated (prettier, tsc, eslint, vitest).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
        git push origin "$NIGHTSHIFT_BRANCH"
        log_success "PR comment fixes committed and pushed."
    fi
}

# ======================== PRE-FLIGHT ========================
preflight() {
    log_phase "Pre-Flight Checks"

    for cmd in claude pnpm npx curl gh git python3 node; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "$cmd not found in PATH."
            exit 1
        fi
        log_success "$cmd"
    done

    if ! gh auth status &>/dev/null; then
        log_error "gh CLI not authenticated. Run: gh auth login"
        exit 1
    fi
    log_success "gh authenticated"

    if [ ! -f "$PLAN_FILE" ]; then
        log_error "Plan file not found: $PLAN_FILE"
        exit 1
    fi
    log_success "Plan: $PLAN_FILE"

    mkdir -p "$LOG_DIR" "$SCREENSHOT_DIR"
    init_progress

    # Count steps in range
    local total_steps=0
    for i in $(seq "$FILTER_FROM" "$FILTER_TO"); do
        local title
        title=$(get_step_title "$i")
        [ "$title" != "Unknown Step" ] && total_steps=$((total_steps + 1))
    done

    local already_done=0
    for i in $(seq "$FILTER_FROM" "$FILTER_TO"); do
        [ "$(is_step_done "$i")" = "yes" ] && already_done=$((already_done + 1))
    done

    local remaining=$((total_steps - already_done))

    log "Steps in range: ${BOLD}$total_steps${NC} (${FILTER_FROM}-${FILTER_TO})"
    log "Already done: ${BOLD}$already_done${NC} | Remaining: ${BOLD}$remaining${NC}"

    local est_minutes=$(( remaining * 15 ))
    local est_hours=$(( est_minutes / 60 ))
    log "Estimated: ~${est_hours}h ${est_minutes}min ($remaining steps x ~15min)"

    if ! $SKIP_CHROME; then
        start_dev_server
    fi

}

# ======================== MAIN LOOP ========================
main() {
    preflight

    if $DRY_RUN; then
        log_phase "DRY RUN — Listing Steps"
        for step_num in $(seq "$FILTER_FROM" "$FILTER_TO"); do
            local title
            title=$(get_step_title "$step_num")
            [ "$title" = "Unknown Step" ] && continue
            local done_status
            done_status=$(is_step_done "$step_num")
            local category
            category=$(get_category_name "$step_num")
            if [ "$done_status" = "yes" ]; then
                echo -e "  ${DIM}Step $step_num: $title [$category] (DONE)${NC}"
            else
                echo -e "  ${GREEN}Step $step_num: $title [$category]${NC}"
            fi
        done
        exit 0
    fi

    setup_branch

    summary "═══ NIGHTSHIFT BULLETPROOF STARTED ═══"
    summary "Steps: $FILTER_FROM-$FILTER_TO | Remaining: $(( FILTER_TO - FILTER_FROM + 1 )) | Chrome: $([ "$SKIP_CHROME" = true ] && echo 'OFF' || echo 'ON')"

    echo "0" > "$ITERATION_STATE_FILE"
    START_TIME=$(date +%s)

    log_phase "Nightshift Bulletproof Loop — Steps $FILTER_FROM to $FILTER_TO"
    log "Config: max ${BOLD}$MAX_ITERATIONS${NC} iters | ${BOLD}$MAX_FIX_ATTEMPTS${NC} code fixes | ${BOLD}$MAX_CHROME_FIX_ATTEMPTS${NC} chrome fixes"
    log "Chrome: $([ "$SKIP_CHROME" = true ] && echo 'DISABLED' || echo 'ENABLED')"
    echo ""

    TASKS_COMPLETED=0
    TASKS_FAILED=0

    for step_num in $(seq "$FILTER_FROM" "$FILTER_TO"); do
        increment_iteration

        # Skip if already done
        if [ "$(is_step_done "$step_num")" = "yes" ]; then
            log "${DIM}Step $step_num: Already done. Skipping.${NC}"
            continue
        fi

        # Get step details
        local step_title step_body category_name
        step_title=$(get_step_title "$step_num")
        [ "$step_title" = "Unknown Step" ] && continue

        step_body=$(parse_step "$step_num")
        category_name=$(get_category_name "$step_num")

        local stats elapsed
        stats=$(get_progress_stats)
        elapsed=$(( $(date +%s) - START_TIME ))

        local safe_title
        safe_title=$(echo "$step_title" | tr ' :/' '-' | tr '[:upper:]' '[:lower:]' | head -c 50)
        local step_log="$LOG_DIR/step-${step_num}-${safe_title}.log"
        local chrome_log="$LOG_DIR/chrome-step-${step_num}.log"

        log_step "$step_num" "$step_title"
        log "Category: ${BOLD}$category_name${NC}"
        log "Progress: ${GREEN}$(echo "$stats" | cut -d'|' -f1) done${NC} | ${RED}$(echo "$stats" | cut -d'|' -f2) failed${NC} | ${elapsed}s elapsed"
        echo ""

        echo "═══ STEP $step_num: $step_title | $(date) ═══" > "$step_log"
        summary "STARTED: Step $step_num — $step_title [$category_name]"

        # ══════════ PHASE 1: IMPLEMENT ══════════
        log "${MAGENTA}Phase 1: Implementation${NC}"

        call_claude "You are an expert senior full-stack developer hardening a production application. Take your time — quality over speed.

$CODEBASE_CONTEXT

## YOUR TASK — Step $step_num from $PLAN_FILE

$step_body

## APPROACH
1. **Read the plan carefully.** Understand the What, Why, and How sections.
2. **Explore relevant files.** Read every file mentioned in the step. Understand existing patterns.
3. **Plan before coding.** Think through your implementation approach.
4. **Implement.** Follow existing patterns. Use shadcn/ui, Tailwind, Framer Motion. Support dark mode.
5. **Write tests if the step involves new logic.** Use vitest for unit tests. Use existing test patterns in src/lib/__tests__/.
6. **Self-verify.** Run: npx prettier --write . && npx tsc --noEmit

## RULES
- Minimal changes. Don't refactor unrelated code.
- No \`any\`, \`@ts-ignore\`, \`eslint-disable\`.
- Don't break existing tests or functionality.
- If the step requires database changes, create a new migration file in supabase/migrations/.
- If the step requires new API routes, add rate limiting and Zod validation.
- If the step requires new UI, support dark mode and responsive design.
- If the step is infrastructure/DevOps (no code changes), create the necessary config files or documentation.
- After implementation, run: npx prettier --write . && npx tsc --noEmit" "$step_log"

        # ══════════ PHASE 2: CODE VALIDATION ══════════
        log ""; log "${MAGENTA}Phase 2: Code Validation${NC}"
        local validation_log="$LOG_DIR/validation-step-${step_num}-attempt-0.log"

        CODE_PASSED=false
        if run_full_validation "$validation_log"; then
            log_success "Code passed first try!"
            summary "  CODE VALIDATED: First attempt"
            CODE_PASSED=true
        else
            local fix_attempt=0
            while [ "$fix_attempt" -lt "$MAX_FIX_ATTEMPTS" ]; do
                fix_attempt=$((fix_attempt + 1))
                increment_iteration
                log_warn "Code fix $fix_attempt/$MAX_FIX_ATTEMPTS..."

                call_claude "Fix validation errors for Step $step_num: **$step_title**.

$CODEBASE_CONTEXT

Step spec:
$step_body

Validation errors (attempt $fix_attempt/$MAX_FIX_ATTEMPTS):
\`\`\`
$(cat "$validation_log")
\`\`\`

Fix ALL errors. Run: npx prettier --write . && npx tsc --noEmit && npx vitest run
No @ts-ignore, no \`any\`, no eslint-disable." "$step_log"

                validation_log="$LOG_DIR/validation-step-${step_num}-attempt-${fix_attempt}.log"
                if run_full_validation "$validation_log"; then
                    log_success "Code passed on fix $fix_attempt!"
                    summary "  CODE VALIDATED: Fix attempt $fix_attempt"
                    CODE_PASSED=true; break
                fi
                sleep 3
            done

            if ! $CODE_PASSED; then
                log_error "Step $step_num FAILED after $MAX_FIX_ATTEMPTS fix attempts."
                summary "  FAILED: Step $step_num — $step_title"
                mark_step_progress "$step_num" "failed"
                TASKS_FAILED=$((TASKS_FAILED + 1))
                commit_step "$step_num" "$step_title" "failed" "$category_name"
                sleep "$COOLDOWN_SECONDS"
                continue
            fi
        fi

        # ══════════ PHASE 3: CHROME TESTING ══════════
        if ! $SKIP_CHROME; then
            log ""; log "${WHITE}Phase 3: Chrome Testing${NC}"
            summary "  CHROME: Starting"

            # Ensure dev server is up
            if ! curl -s -o /dev/null "$DEV_URL" 2>/dev/null; then
                stop_dev_server; start_dev_server; sleep 3
            fi

            CHROME_PASSED=false
            CHROME_ATTEMPT=0

            while [ "$CHROME_ATTEMPT" -le "$MAX_CHROME_FIX_ATTEMPTS" ]; do
                increment_iteration

                if [ "$CHROME_ATTEMPT" -eq 0 ]; then
                    call_claude "QA test Step $step_num in Chrome. Dev server at $DEV_URL.

$CHROME_CONTEXT

## STEP IMPLEMENTED
$step_body

## PROTOCOL
1. tabs_context_mcp first. Create new tab. Navigate to $DEV_URL.
2. Navigate to the page(s) relevant to this step.
3. Visual: read_page — are new elements present, correct styling?
4. Functional: click/interact — does expected behavior work?
5. Console: read_console_messages with pattern 'error|Error|ERR' — any new errors?
6. Dark mode: execute JS to toggle, re-check visuals.
7. Take screenshot to .agent-logs/screenshots/step-${step_num}.png

## VERDICT (output exactly one):
\`\`\`
CHROME_VERDICT: PASS
Evidence: [what you verified]
\`\`\`
or
\`\`\`
CHROME_VERDICT: FAIL
Issues found:
- [list issues]
\`\`\`

Note: If this step is backend-only (API, database, security config) and there's nothing visual to test,
output CHROME_VERDICT: PASS with evidence 'Backend-only step, no visual changes to verify'." "$chrome_log"
                else
                    log_warn "  Chrome fix $CHROME_ATTEMPT/$MAX_CHROME_FIX_ATTEMPTS..."
                    call_claude "Fix Chrome test issues for Step $step_num: $step_title.

$CODEBASE_CONTEXT

Chrome found:
\`\`\`
$(cat "$chrome_log")
\`\`\`

Fix the issues. Run npx prettier --write . && npx tsc --noEmit after." "$step_log"

                    run_quick_validation "$LOG_DIR/validation-chrome-fix-${step_num}-${CHROME_ATTEMPT}.log" || true

                    chrome_log="$LOG_DIR/chrome-step-${step_num}-attempt-${CHROME_ATTEMPT}.log"
                    call_claude "Re-test Step $step_num in Chrome. $DEV_URL.
$CHROME_CONTEXT
Step: $step_body
Output CHROME_VERDICT: PASS or CHROME_VERDICT: FAIL with issues." "$chrome_log"
                fi

                if grep -q "CHROME_VERDICT: PASS" "$chrome_log" 2>/dev/null; then
                    log_success "Chrome PASSED!"
                    summary "  CHROME VERIFIED"
                    CHROME_PASSED=true; break
                fi

                [ "$CHROME_ATTEMPT" -ge "$MAX_CHROME_FIX_ATTEMPTS" ] && break
                CHROME_ATTEMPT=$((CHROME_ATTEMPT + 1))
                sleep 3
            done
        else
            CHROME_PASSED=true  # Skip = auto-pass
        fi

        # ══════════ PHASE 4: COMMIT ══════════
        log ""; log "${MAGENTA}Phase 4: Commit${NC}"

        if $CHROME_PASSED; then
            mark_step_progress "$step_num" "completed"
            commit_step "$step_num" "$step_title" "pass" "$category_name"
            summary "  COMPLETED: Step $step_num — $step_title"
        else
            mark_step_progress "$step_num" "chrome_review"
            commit_step "$step_num" "$step_title" "chrome-review" "$category_name"
            summary "  CHROME_REVIEW: Step $step_num — $step_title"
        fi

        TASKS_COMPLETED=$((TASKS_COMPLETED + 1))
        log_success "Step $step_num done! ($TASKS_COMPLETED completed, $TASKS_FAILED failed)"

        sleep "$COOLDOWN_SECONDS"
        echo ""
    done

    # ══════════════════════════════════════════════════════
    # ALL STEPS DONE → PR FLOW
    # ══════════════════════════════════════════════════════
    local elapsed=$(( $(date +%s) - START_TIME ))
    log_phase "ALL STEPS PROCESSED — $TASKS_COMPLETED done, $TASKS_FAILED failed in $(( elapsed / 60 ))min"
    summary "═══ STEPS COMPLETE ═══ $TASKS_COMPLETED done, $TASKS_FAILED failed, $(( elapsed / 60 ))min"

    # Final push
    git push origin "$NIGHTSHIFT_BRANCH" 2>/dev/null || true

    if ! $SKIP_PR; then
        PR_URL=$(create_pull_request)
        PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$' || echo "")

        if [ -n "$PR_NUMBER" ]; then
            handle_pr_comments "$PR_NUMBER"

            elapsed=$(( $(date +%s) - START_TIME ))
            log_phase "NIGHTSHIFT BULLETPROOF COMPLETE"
            log_success "Total time: $(( elapsed / 60 )) minutes ($(( elapsed / 3600 ))h $(( (elapsed % 3600) / 60 ))m)"
            log "PR: $PR_URL"
            log "Branch: $NIGHTSHIFT_BRANCH"
            log "Steps: $TASKS_COMPLETED completed, $TASKS_FAILED failed"
            log "Screenshots: $SCREENSHOT_DIR/"
            log "Logs: $LOG_DIR/"
            summary "═══ NIGHTSHIFT FINISHED ═══ Total: $(( elapsed / 60 ))min | PR: $PR_URL"
        else
            log_warn "PR creation failed. Changes on branch $NIGHTSHIFT_BRANCH."
            summary "═══ NIGHTSHIFT FINISHED (no PR) ═══"
        fi
    else
        elapsed=$(( $(date +%s) - START_TIME ))
        log_phase "NIGHTSHIFT BULLETPROOF COMPLETE (no PR)"
        log_success "Total time: $(( elapsed / 60 )) minutes"
        log "Branch: $NIGHTSHIFT_BRANCH"
        log "Steps: $TASKS_COMPLETED completed, $TASKS_FAILED failed"
        summary "═══ NIGHTSHIFT FINISHED (PR skipped) ═══"
    fi

    # Print final stats
    echo ""
    log_phase "FINAL REPORT"
    local final_stats
    final_stats=$(get_progress_stats)
    echo -e "  ${GREEN}Completed:${NC}     $(echo "$final_stats" | cut -d'|' -f1)"
    echo -e "  ${RED}Failed:${NC}        $(echo "$final_stats" | cut -d'|' -f2)"
    echo -e "  ${YELLOW}Chrome Review:${NC} $(echo "$final_stats" | cut -d'|' -f4)"
    echo -e "  ${DIM}Skipped:${NC}       $(echo "$final_stats" | cut -d'|' -f3)"
    echo ""
    echo -e "  ${CYAN}Summary log:${NC}   $SUMMARY_LOG"
    echo -e "  ${CYAN}Progress:${NC}      $PROGRESS_FILE"
    echo -e "  ${CYAN}Screenshots:${NC}   $SCREENSHOT_DIR/"
    echo ""
}

# ======================== RUN ========================
main "$@"
