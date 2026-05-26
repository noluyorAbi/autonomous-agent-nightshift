# Autonomous Agent Playbook

A complete guide to planning features and having AI agents implement them overnight. Built from real production use on this codebase. Copy the templates, adapt the config, run the script, go to sleep.

---

## Table of Contents

1. [Philosophy](#1-philosophy)
2. [The Three Artifacts](#2-the-three-artifacts)
3. [Step 1: Write the Feature Plan (Todo File)](#3-step-1-write-the-feature-plan)
4. [Step 2: Write the Codebase Context](#4-step-2-write-the-codebase-context)
5. [Step 3: Configure the Runner Script](#5-step-3-configure-the-runner-script)
6. [Step 4: Launch](#6-step-4-launch)
7. [Step 5: Morning Review](#7-step-5-morning-review)
8. [The Runner Script Architecture](#8-the-runner-script-architecture)
9. [Chrome Browser Testing (Phase 3)](#9-chrome-browser-testing)
10. [Writing Good Tasks (The Hard Part)](#10-writing-good-tasks)
11. [Codebase Context Template](#11-codebase-context-template)
12. [Runner Script Template](#12-runner-script-template)
13. [Tuning Guide](#13-tuning-guide)
14. [Failure Modes & How to Avoid Them](#14-failure-modes)
15. [Checklist: Before You Hit Run](#15-pre-launch-checklist)
16. [Examples](#16-examples)

---

## 1. Philosophy

The autonomous agent loop is a **three-component system**:

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   FEATURE PLAN  │────▶│  RUNNER SCRIPT   │────▶│  CODEBASE CTX   │
│  (todo file)    │     │  (bash harness)  │     │  (embedded map)  │
│                 │     │                  │     │                  │
│ What to build   │     │ How to loop      │     │ Where things are │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

**Core principles:**

1. **The human writes the WHAT. The agent writes the HOW.** Your job is to write precise task specs with clear validation criteria. The agent figures out the code.

2. **Every task must be independently verifiable.** If you can't write a validation criterion for it, the agent can't know when it's done.

3. **The agent has no memory between tasks.** Each `claude -p` call is a fresh session. Everything the agent needs must be in the prompt: the task, the codebase map, and the conventions.

4. **Tests are the contract.** The agent writes a test, implements the feature, then the harness independently validates. No trust — only proof.

5. **Failure is handled, not feared.** Tasks that can't be fixed after N attempts get flagged for human review. The loop moves on. You deal with the hard ones in the morning.

---

## 2. The Three Artifacts

Every autonomous run requires exactly three things:

| Artifact             | File                      | Purpose                                                                           |
| -------------------- | ------------------------- | --------------------------------------------------------------------------------- |
| **Feature Plan**     | `todo-{date}_{name}.md`   | Ordered task list with checkboxes, implementation notes, validation criteria      |
| **Runner Script**    | `run-agent-loop.sh`       | Bash harness that orchestrates Claude, runs validation, manages retries           |
| **Codebase Context** | Embedded in runner script | File map, conventions, patterns — everything the agent needs to navigate the code |

The rest of this doc teaches you how to write each one.

---

## 3. Step 1: Write the Feature Plan

The feature plan is a markdown file with checkboxes. The runner script parses it to find the next unchecked task, feeds it to Claude, and checks it off when validation passes.

### Format

```markdown
# {Plan Title}: Autonomous Execution Plan

**Agent Instructions:** Process this list sequentially. For each item, you must:

1. Implement the required logic or UI change.
2. Write or update the corresponding unit/integration tests to validate the change.
3. Run the test suite.
4. Only mark the checkbox `[x]` as complete if the test suite passes and the validation criteria are strictly met.

## Phase 1: {Phase Name}

- [ ] **Task 1: {Task Title}**
  - **Implementation:** {Exactly what to build/change. Reference specific functions, components, files.}
  - **Validation:** {The test that must pass. Be specific about what to assert.}
- [ ] **Task 2: {Task Title}**
  - **Implementation:** {Details...}
  - **Validation:** {Details...}

## Phase 2: {Phase Name}

- [ ] **Task 3: {Task Title}**
      ...
```

### Rules for Task Writing

**DO:**

- Number tasks sequentially across phases (`Task 1`, `Task 2`, ... `Task N`).
- Reference specific function names, component names, file paths.
- Write validation criteria as if you're writing a test description: "Assert that X returns Y when given Z."
- Order tasks so dependencies come first (e.g., create the data model before the UI that uses it).
- Group related tasks into phases for readability.
- Keep each task small enough to implement in one Claude session (~5-15 minutes of agent work).

**DON'T:**

- Write vague tasks like "Improve the UI" or "Fix bugs."
- Combine multiple unrelated changes in one task.
- Skip validation criteria — this is what makes the whole system work.
- Create dependency chains longer than 3 tasks — if Task 8 depends on Tasks 1-7, the system is fragile.
- Use relative references like "the component we just created" — every task must be self-contained.

### Task Size Guide

| Size      | Example                                                                    | Fit?                                         |
| --------- | -------------------------------------------------------------------------- | -------------------------------------------- |
| Too small | "Add a CSS class to a button"                                              | Combine with related UI work                 |
| Good      | "Add a stop button that aborts the SSE stream and shows during generation" | Self-contained feature with clear validation |
| Good      | "Create a `/gallery` route that fetches and displays all user images"      | Full feature slice                           |
| Too large | "Rewrite the entire chat system to support threading"                      | Break into 5-8 smaller tasks                 |

### Naming Convention

```
todo-{YYYY_MM_DD}_{session-name}.md
```

Examples:

- `todo-2026_03_16_nightshift.md`
- `todo-2026_03_20_canvas-overhaul.md`
- `todo-2026_04_01_pre-submission-polish.md`

---

## 4. Step 2: Write the Codebase Context

This is the most important part. The agent starts fresh every invocation. It doesn't remember previous tasks. The codebase context is its only map.

### What to Include

1. **File paths and what they do** — every file the agent might need to read or modify.
2. **Architecture patterns** — state management, data flow, component hierarchy.
3. **Conventions** — formatting, naming, testing patterns, import styles.
4. **What NOT to do** — forbidden patterns, things that will break.

### How to Generate It

Run an exploration agent or do it manually:

```bash
# Option A: Have Claude explore and generate the map
claude -p "Explore this codebase thoroughly. List every important file with its path and a one-line description of what it does. Group by domain (chat, canvas, API, types, hooks, etc). Include the UI stack, test framework, package manager, and coding conventions."

# Option B: Manual (more reliable, you know your codebase)
# List your key directories and describe the files yourself.
```

### Context Template

See [Section 10](#10-codebase-context-template) for a copy-paste template.

### Keeping It Updated

The codebase context lives inside the runner script as a heredoc. When you add new files or change architecture, update the context. Stale context = agent writes code in the wrong place.

**Rule of thumb:** Update the codebase context whenever you:

- Add a new major component or route
- Change state management patterns
- Add or remove a dependency
- Move files around

---

## 5. Step 3: Configure the Runner Script

The runner script is a bash loop that:

1. Reads the todo file
2. Extracts the next unchecked task
3. Calls `claude -p` with the task + codebase context
4. Runs validation (prettier, tsc, eslint, tests)
5. On pass: marks the task `[x]`
6. On fail: retries with error output up to N times
7. On total failure: flags for manual review, moves on
8. Loops until all tasks are done or iteration limit is hit

### Configuration Variables

```bash
# ---- Required ----
TODO_FILE="todo-2026_03_20_canvas-overhaul.md"   # Your feature plan

# ---- Limits ----
MAX_ITERATIONS=200        # Total Claude calls allowed (safety cap)
MAX_FIX_ATTEMPTS=7        # Fix retries per task before giving up
COOLDOWN_SECONDS=5        # Pause between tasks (rate limit protection)

# ---- Validation ----
# The run_full_validation() function runs these in order:
# 1. npx prettier --write .
# 2. npx tsc --noEmit
# 3. npx eslint . --quiet
# 4. bun test
#
# Customize this function for your project's toolchain.
```

### Tuning the Limits

| Scenario                    | MAX_ITERATIONS | MAX_FIX_ATTEMPTS | Why                                |
| --------------------------- | -------------- | ---------------- | ---------------------------------- |
| 5 easy tasks                | 50             | 3                | Low risk, fast                     |
| 16 mixed tasks (nightshift) | 200            | 7                | Enough headroom for retries        |
| 30+ ambitious tasks         | 400            | 10               | Marathon run, expect some failures |
| Quick prototype (no tests)  | 40             | 2                | Fast iteration, review manually    |

**Formula:** `MAX_ITERATIONS >= NUM_TASKS × (1 + MAX_FIX_ATTEMPTS + 2)`

The `+2` accounts for the implementation call and the mark-complete call per task.

---

## 6. Step 4: Launch

### Foreground (watch it work)

```bash
chmod +x run-agent-loop.sh
./run-agent-loop.sh
```

### Background (go to sleep)

```bash
# Detached from terminal — survives closing the lid
nohup ./run-agent-loop.sh > .agent-logs/stdout.log 2>&1 &

# Save the PID so you can check on it
echo $! > .agent-logs/runner.pid
```

### Check on it remotely

```bash
# Is it still running?
ps -p $(cat .agent-logs/runner.pid)

# What's the latest progress?
tail -20 .agent-logs/nightshift-summary.log

# Full stdout output
tail -100 .agent-logs/stdout.log
```

---

## 7. Step 5: Morning Review

When you wake up, check three things:

### 1. Summary Log

```bash
cat .agent-logs/nightshift-summary.log
```

This gives you a one-line-per-event timeline:

```
[2026-03-16 23:14:02] ═══ NIGHTSHIFT STARTED ═══
[2026-03-16 23:14:02] Tasks remaining: 16 | Max iterations: 200
[2026-03-16 23:22:15] STARTED: Task 1 — Interrupt Generation
[2026-03-16 23:28:41]   VALIDATED: First attempt — all checks passed
[2026-03-16 23:28:55]   COMPLETED: Task 1 — Interrupt Generation
[2026-03-16 23:29:03] STARTED: Task 2 — Branch Navigation Sync
[2026-03-16 23:35:18]   VALIDATED: Passed on fix attempt 2
[2026-03-16 23:35:30]   COMPLETED: Task 2 — Branch Navigation Sync
...
[2026-03-17 01:45:00]   FAILED: Task 10 — Stricter Contextual Adherence — 7 fix attempts exhausted
...
[2026-03-17 03:12:44] ═══ NIGHTSHIFT COMPLETE ═══ All 16 tasks done in 233min
```

### 2. Todo File

```bash
cat todo-2026_03_16_nightshift.md | grep '\[x\]'
cat todo-2026_03_16_nightshift.md | grep 'MANUAL REVIEW'
```

Tasks marked with "NEEDS MANUAL REVIEW" need your attention.

### 3. Validation

Run the full check yourself:

```bash
npx prettier --write .
npx tsc --noEmit
npx eslint . --quiet
bun test
```

Then test the app manually:

```bash
pnpm dev
# Open localhost:31415 and spot-check each implemented feature
```

### 4. Git

The agent doesn't commit anything. Review the diff, then commit what you're happy with:

```bash
git diff --stat           # See what changed
git add -p                # Stage selectively
git commit -m "feat: implement nightshift tasks 1-16"
```

---

## 8. The Runner Script Architecture

```
run-agent-loop.sh
│
├── preflight()              Check tools, count tasks, estimate runtime
│
├── CODEBASE_CONTEXT         Heredoc with full file map + conventions
│
├── main loop ──────────────────────────────────────────────────────
│   │
│   ├── Iteration guardrail   Read counter from .claude_iterations
│   ├── Completion check       grep for unchecked boxes
│   ├── extract_current_task() Parse todo file for next task text
│   │
│   ├── PHASE 1: IMPLEMENT
│   │   └── call_claude()      claude -p with task + context + rules
│   │       └── Retries 3x on transient failures (rate limit, network)
│   │
│   ├── PHASE 2: VALIDATE
│   │   └── run_full_validation()
│   │       ├── prettier --write .
│   │       ├── tsc --noEmit
│   │       ├── eslint . --quiet
│   │       └── bun test
│   │
│   ├── PHASE 2b: FIX LOOP (if validation failed)
│   │   └── for attempt in 1..MAX_FIX_ATTEMPTS:
│   │       ├── call_claude() with error output
│   │       └── run_full_validation()
│   │
│   ├── PHASE 3: MARK COMPLETE
│   │   └── call_claude() to check off the box
│   │
│   └── cooldown + loop back
│
├── call_claude()            Wrapper with retry logic
├── extract_current_task()   Regex parser for todo format
├── extract_task_number()    Pulls "Task N" from heading
├── run_full_validation()    Four-stage check with logging
├── summary()                Append to nightshift-summary.log
└── log helpers              Colored terminal output
```

### File Outputs

| File                                              | Purpose                                   |
| ------------------------------------------------- | ----------------------------------------- |
| `.claude_iterations`                              | Iteration counter (deleted on completion) |
| `.agent-logs/nightshift-summary.log`              | One-line-per-event timeline               |
| `.agent-logs/task-{N}-{name}.log`                 | Full Claude output per task               |
| `.agent-logs/validation-task-{N}-attempt-{M}.log` | Validation results per attempt            |
| `.agent-logs/chrome-task-{N}.log`                 | Chrome browser test results per task      |
| `.agent-logs/screenshots/task-{N}-*.png`          | Screenshot evidence per task              |
| `.agent-logs/screenshots/task-{N}-demo.gif`       | GIF recordings of interactions            |
| `.agent-logs/dev-server.log`                      | Next.js dev server output                 |

---

## 9. Chrome Browser Testing (Phase 3)

After code validation passes (Phase 2), the runner launches **Phase 3: Chrome Browser Testing** — a live visual and functional verification of the feature in a real browser.

### Why Chrome Testing Matters

Unit tests verify logic. Chrome testing verifies reality:

| Unit tests catch          | Chrome testing catches                                         |
| ------------------------- | -------------------------------------------------------------- |
| Wrong return values       | Button is there but invisible (z-index, opacity)               |
| Missing function calls    | Dark mode breaks text color                                    |
| Type errors               | Click handler fires but UI doesn't update                      |
| API schema mismatches     | New component causes React hydration error                     |
| Logic bugs                | Element exists but is unreachable (covered by another element) |
| Regression in other tests | Console floods with warnings on every render                   |

### How It Works

```
Code validation passes
    │
    ▼
Dev server running? (auto-started on port 31415)
    │
    ▼
Claude opens Chrome via MCP tools
    │
    ├── 1. Get tab context (tabs_context_mcp)
    ├── 2. Create new tab (tabs_create_mcp)
    ├── 3. Navigate to app (localhost:31415)
    ├── 4. Navigate to relevant page
    ├── 5. Visual inspection (read_page — accessibility tree)
    ├── 6. Functional testing (click, type, interact)
    ├── 7. Console check (read_console_messages)
    ├── 8. Dark mode toggle + re-check
    ├── 9. Screenshot (evidence)
    └── 10. GIF recording (for interactions/animations)
    │
    ▼
Verdict: PASS or FAIL
    │
    ├── PASS → Mark task [x]
    │
    └── FAIL → Fix loop (up to MAX_CHROME_FIX_ATTEMPTS)
              │
              ├── Claude fixes the code based on Chrome findings
              ├── Re-run code validation (in case fix broke tests)
              ├── Re-test in Chrome
              └── Loop or give up with review note
```

### Prerequisites

1. **Chrome browser must be open** with the [Claude-in-Chrome extension](https://chromewebstore.google.com/) installed and active.
2. The extension exposes MCP tools that Claude Code can call.
3. The dev server runs automatically (the script starts `pnpm dev` on port 31415).

### Chrome Test Verdicts

The Chrome testing agent outputs a structured verdict:

```
CHROME_VERDICT: PASS
Evidence: Button renders correctly, onClick navigates to branch, dark mode OK, no console errors
```

or

```
CHROME_VERDICT: FAIL
Issues found:
- Stop button not visible during generation (opacity: 0 in dark mode)
- Console error: "Cannot read properties of undefined (reading 'id')"
Suggested fixes:
- Add dark:opacity-100 class to stop button
- Add null check in branch navigation handler
```

### What Gets Tested

For each task, the Chrome agent verifies:

| Check                       | How                                                                         |
| --------------------------- | --------------------------------------------------------------------------- |
| **Element exists**          | `read_page` accessibility tree — is the new button/panel/modal present?     |
| **Correct text/labels**     | Accessibility tree shows proper content and ARIA labels                     |
| **Interactions work**       | `computer` tool clicks buttons, `form_input` fills fields                   |
| **State changes**           | After interaction, re-read page to verify UI updated                        |
| **Dark mode**               | Toggle via JS `document.documentElement.classList.toggle('dark')`, re-check |
| **No console errors**       | `read_console_messages` with error/warning filter                           |
| **No network failures**     | `read_network_requests` for failed API calls                                |
| **Visual evidence**         | Screenshot saved to `.agent-logs/screenshots/`                              |
| **Animation/flow evidence** | GIF recorded for interactive features                                       |

### Task-Specific Navigation

The Chrome agent knows how to find features based on the task:

| Task domain                                     | Where to navigate                    |
| ----------------------------------------------- | ------------------------------------ |
| Chat features (input, suggestions, stop button) | `/chat` → open/create a chat         |
| Branch features                                 | `/chat/{id}` → create branch         |
| Canvas features                                 | `/chat/{id}` → click canvas toggle   |
| Timeline features                               | `/chat/{id}` → expand timeline panel |
| Media/gallery features                          | `/gallery` or media shelf in chat    |
| New routes                                      | Navigate directly to the new route   |

### Chrome Fix Loop

If Chrome testing finds issues, a separate fix loop runs:

1. Claude gets the Chrome test output (what's broken, suggested fixes)
2. Claude fixes the code
3. Code validation re-runs (to make sure the fix didn't break tests)
4. Chrome re-tests
5. Repeat up to `MAX_CHROME_FIX_ATTEMPTS` (default: 3)

If Chrome fixes can't resolve the issue, the task is marked done with a **"CHROME REVIEW NEEDED"** note — the code works, but the visual/functional aspect needs human eyes.

### Configuration

```bash
MAX_CHROME_FIX_ATTEMPTS=3   # Chrome-specific fix rounds per task
DEV_PORT=31415               # Port for Next.js dev server
DEV_SERVER_WAIT=15           # Seconds to wait for dev server startup
```

### Disabling Chrome Testing

If you don't have Chrome or don't need visual testing, you can skip Phase 3 by removing the Chrome testing block from the runner script. The code validation (Phase 2) still runs independently.

### Morning Review: Screenshots

Check the screenshots folder to visually verify what the agent saw:

```bash
# List all screenshots
ls -la .agent-logs/screenshots/

# Open them (macOS)
open .agent-logs/screenshots/*.png
open .agent-logs/screenshots/*.gif
```

---

## 10. Writing Good Tasks

This is the highest-leverage skill. A well-written task completes on the first attempt. A vague task burns 7 fix attempts and gets flagged for manual review.

### The Anatomy of a Perfect Task

```markdown
- [ ] **Task 5: Bidirectional Timeline State**
  - **Implementation:** Map the timeline UI to the active `messageId`. Apply an "active" CSS class (enlarged/highlighted) to the corresponding timeline dot in `components/chat-timeline/timeline-message-item.tsx`. Ensure scrolling the chat updates the active dot via the existing `useScrollToBottom` hook, and clicking a dot scrolls the chat via `scrollIntoView`.
  - **Validation:** Write a component test verifying that setting the active message state applies the correct highlight class to the specific timeline node.
```

**Why this works:**

- Names the exact file to modify
- References existing hooks/patterns the agent should use
- Describes the behavior, not just the UI
- Validation is a specific assertion, not "make sure it works"

### Bad Task → Good Task Rewrites

**Bad:**

```markdown
- [ ] **Task: Fix the timeline**
  - **Implementation:** Make the timeline work better.
  - **Validation:** It should look good.
```

**Good:**

```markdown
- [ ] **Task 5: Timeline Active State Sync**
  - **Implementation:** In `components/chat-timeline/timeline-message-item.tsx`, add a prop `isActive: boolean`. When true, apply `ring-2 ring-primary scale-110` classes to the dot element. In `app/chat/[chatId]/page.tsx`, track `activeMessageId` state. Update it via an IntersectionObserver on message elements. Pass it down to the timeline.
  - **Validation:** Write a test that renders TimelineMessageItem with `isActive={true}` and asserts the element has the `scale-110` class.
```

### Task Dependencies

If Task B depends on Task A's output, make it explicit:

```markdown
- [ ] **Task 7: Message Queue — Data Structure**
  - **Implementation:** In `lib/hooks/use-message-queue.ts`, create a hook that manages a `messageQueue: string[]` array. Expose `enqueue(msg)`, `dequeue()`, and `peek()` functions.
  - **Validation:** Test that enqueue adds to the array, dequeue removes and returns the first item, peek returns without removing.

- [ ] **Task 8: Message Queue — Integration**
  - **Implementation:** In `app/chat/[chatId]/page.tsx`, import `useMessageQueue`. When `isGenerating` is true, push new messages to the queue instead of calling `sendMessage`. When generation finishes (in the SSE `onComplete` callback), pop and send the next queued message.
  - **Validation:** Test that sending a message while `isGenerating=true` adds it to the queue, and that completing generation triggers the next message.
```

---

## 11. Codebase Context Template

Copy this template into your runner script's heredoc and fill it in:

```bash
read -r -d '' CODEBASE_CONTEXT << 'CONTEXT_EOF' || true
## Codebase Map (use these exact paths):

**{Domain 1}:**
- path/to/file.tsx — {What it does. Key functions/exports.}
- path/to/other.ts — {What it does.}

**{Domain 2}:**
- path/to/component.tsx — {What it does.}

**API Routes:**
- app/api/{route}/route.ts — {Method, purpose, schema.}

**Types:**
- lib/types/{name}.ts — {Key interfaces/types defined here.}

**Hooks & Services:**
- lib/hooks/{name}.ts — {What state it manages.}
- lib/contexts/{name}.tsx — {What context it provides.}

**UI Stack:** {component library} + {CSS framework} + {animation library} + {icon library}
**Test Framework:** {framework}. Import from "{import path}". Tests colocated as *.test.{ext}.
**Auth:** {auth provider} ({client file}, {server file}).
**Package Manager:** {manager}.

## Conventions:
- {Convention 1: e.g., "Always run prettier after changes."}
- {Convention 2: e.g., "Use TypeScript strict mode. No `any`."}
- {Convention 3: e.g., "Follow existing shadcn/ui patterns."}
- {Convention 4: e.g., "Dark mode via CSS variables."}
- {Convention 5: e.g., "Tests use `import { describe, ... } from 'bun:test'`."}
CONTEXT_EOF
```

### Context Quality Checklist

- [ ] Every file the agent might touch is listed with its path
- [ ] Key functions and exports are named (not just "the main component")
- [ ] The test framework and import syntax are specified
- [ ] UI library, styling approach, and animation library are stated
- [ ] Forbidden patterns are listed (no `any`, no `@ts-ignore`, etc.)
- [ ] The formatting command is included

---

## 12. Runner Script Template

This is a minimal, reusable version of `run-agent-loop.sh`. Copy it, update the three variables at the top, and paste your codebase context into the heredoc.

```bash
#!/bin/bash
set -euo pipefail

# ==================== CONFIG (EDIT THESE) ====================
TODO_FILE="todo-YYYY_MM_DD_name.md"          # <-- Your feature plan
MAX_ITERATIONS=200                            # <-- Safety cap
MAX_FIX_ATTEMPTS=7                            # <-- Retries per task
COOLDOWN_SECONDS=5                            # <-- Rate limit buffer
# =============================================================

ITERATION_STATE_FILE=".claude_iterations"
LOG_DIR=".agent-logs"
SUMMARY_LOG="$LOG_DIR/nightshift-summary.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

log() { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $1"; }
log_error() { echo -e "${RED}[$(date '+%H:%M:%S')] ✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $1"; }
log_phase() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}══════════════════════════════════════${NC}"; }
summary() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$SUMMARY_LOG"; }

# ==================== CODEBASE CONTEXT (EDIT THIS) ====================
read -r -d '' CODEBASE_CONTEXT << 'CONTEXT_EOF' || true
## Codebase Map
# PASTE YOUR CODEBASE MAP HERE (see Section 10)
CONTEXT_EOF

# ==================== VALIDATION (EDIT FOR YOUR TOOLCHAIN) ====================
run_full_validation() {
    local logfile="$1"
    local all_passed=true
    echo "=== VALIDATION ===" > "$logfile"

    # Add/remove/modify these for your project:
    log "  [1/4] Prettier..."
    npx prettier --write . >> "$logfile" 2>&1 || { all_passed=false; echo "[FAIL] prettier" >> "$logfile"; }

    log "  [2/4] TypeScript..."
    npx tsc --noEmit >> "$logfile" 2>&1 || { all_passed=false; echo "[FAIL] tsc" >> "$logfile"; }

    log "  [3/4] ESLint..."
    npx eslint . --quiet >> "$logfile" 2>&1 || { all_passed=false; echo "[FAIL] eslint" >> "$logfile"; }

    log "  [4/4] Tests..."
    bun test >> "$logfile" 2>&1 || { all_passed=false; echo "[FAIL] tests" >> "$logfile"; }

    $all_passed
}

# ==================== INTERNALS (DON'T EDIT BELOW) ====================
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

call_claude() {
    local prompt="$1" logfile="$2" attempt=0
    while [ "$attempt" -lt 3 ]; do
        attempt=$((attempt + 1))
        if claude -p "$prompt" 2>&1 | tee -a "$logfile"; then return 0; fi
        [ "$attempt" -lt 3 ] && { log_warn "Claude call failed. Retry in 15s..."; sleep 15; }
    done
    log_error "Claude failed after 3 retries."; return 1
}

main() {
    log_phase "Pre-Flight"
    for cmd in claude bun npx; do command -v "$cmd" &>/dev/null || { log_error "$cmd not found"; exit 1; }; done
    [ -f "$TODO_FILE" ] || { log_error "$TODO_FILE not found"; exit 1; }
    mkdir -p "$LOG_DIR"
    echo "0" > "$ITERATION_STATE_FILE"
    local START_TIME=$(date +%s) TASKS_COMPLETED=0 TASKS_FAILED=0
    summary "═══ RUN STARTED ═══ | $(grep -c '\- \[ \]' "$TODO_FILE" || echo 0) tasks"

    while true; do
        ITERATIONS=$(cat "$ITERATION_STATE_FILE")
        [ "$ITERATIONS" -ge "$MAX_ITERATIONS" ] && { log_error "Max iterations hit."; summary "STOPPED: iteration limit"; exit 1; }
        ITERATIONS=$((ITERATIONS + 1)); echo "$ITERATIONS" > "$ITERATION_STATE_FILE"

        grep -q "\- \[ \]" "$TODO_FILE" || { log_phase "ALL DONE"; summary "═══ COMPLETE ═══ $(( ($(date +%s)-START_TIME)/60 ))min"; exit 0; }

        CURRENT_TASK=$(extract_current_task)
        TASK_NAME=$(echo "$CURRENT_TASK" | head -1 | sed 's/- \[ \] \*\*//' | sed 's/\*\*//' | xargs)
        TASK_NUM=$(extract_task_number "$CURRENT_TASK")
        TASK_LOG="$LOG_DIR/task-${TASK_NUM}.log"
        log_phase "Task $TASK_NUM: $TASK_NAME [Iter $ITERATIONS/$MAX_ITERATIONS]"
        summary "STARTED: Task $TASK_NUM — $TASK_NAME"

        # IMPLEMENT
        call_claude "You are an expert developer. Take your time, be thorough.

$CODEBASE_CONTEXT

## YOUR TASK (from \`$TODO_FILE\`)
$CURRENT_TASK

## APPROACH
1. Read all relevant files first. Understand existing patterns.
2. Write the test first (colocated .test.ts/.test.tsx).
3. Implement the feature. Minimal changes. Follow existing patterns.
4. Self-verify: bun test, tsc --noEmit, eslint, prettier --write .
5. Fix any failures before exiting.

## RULES
- Do NOT modify other tasks. Do NOT mark anything done.
- No \`any\`, \`@ts-ignore\`, \`eslint-disable\`.
- Don't break existing tests.
- Don't install unnecessary dependencies.
- Take your time. Quality over speed." "$TASK_LOG"

        # VALIDATE
        VLOG="$LOG_DIR/validation-${TASK_NUM}-0.log"
        if run_full_validation "$VLOG"; then
            log_success "Passed first try!"
            summary "  VALIDATED: first attempt"
        else
            FIX=0; FIXED=false
            while [ "$FIX" -lt "$MAX_FIX_ATTEMPTS" ]; do
                FIX=$((FIX + 1))
                ITERATIONS=$(cat "$ITERATION_STATE_FILE"); ITERATIONS=$((ITERATIONS + 1)); echo "$ITERATIONS" > "$ITERATION_STATE_FILE"
                [ "$ITERATIONS" -ge "$MAX_ITERATIONS" ] && { log_error "Iteration limit in fix loop."; exit 1; }
                log_warn "Fix attempt $FIX/$MAX_FIX_ATTEMPTS..."

                call_claude "Fix these validation errors. Take your time.

$CODEBASE_CONTEXT

## TASK: $TASK_NAME
$CURRENT_TASK

## ERRORS (attempt $FIX/$MAX_FIX_ATTEMPTS)
\`\`\`
$(cat "$VLOG")
\`\`\`

Fix ALL errors. Run bun test + tsc + eslint + prettier. No @ts-ignore or any." "$TASK_LOG"

                VLOG="$LOG_DIR/validation-${TASK_NUM}-${FIX}.log"
                run_full_validation "$VLOG" && { FIXED=true; summary "  VALIDATED: fix attempt $FIX"; break; }
                sleep 3
            done

            if ! $FIXED; then
                TASKS_FAILED=$((TASKS_FAILED + 1))
                summary "  FAILED: $TASK_NAME"
                call_claude "In \`$TODO_FILE\`, change this line's checkbox from \`- [ ]\` to \`- [x]\` and append \` — NEEDS MANUAL REVIEW\`:
\`\`\`
$(echo "$CURRENT_TASK" | head -1)
\`\`\`" "$TASK_LOG"
                sleep "$COOLDOWN_SECONDS"; continue
            fi
        fi

        # MARK DONE
        call_claude "In \`$TODO_FILE\`, change this line's checkbox from \`- [ ]\` to \`- [x]\`. Change nothing else:
\`\`\`
$(echo "$CURRENT_TASK" | head -1)
\`\`\`" "$TASK_LOG"

        TASKS_COMPLETED=$((TASKS_COMPLETED + 1))
        log_success "Task $TASK_NUM done! ($TASKS_COMPLETED completed, $TASKS_FAILED failed)"
        summary "  COMPLETED: Task $TASK_NUM — $TASK_NAME"
        sleep "$COOLDOWN_SECONDS"
    done
}

main "$@"
```

---

## 13. Tuning Guide

### When tasks keep failing

| Symptom                                        | Cause                                        | Fix                                         |
| ---------------------------------------------- | -------------------------------------------- | ------------------------------------------- |
| Fails on tsc every time                        | Codebase context is missing types or imports | Add the type files to the context map       |
| Agent creates wrong file structure             | Conventions section is incomplete            | Add explicit file organization rules        |
| Test passes but feature doesn't work           | Validation criteria is too weak              | Write more specific assertions              |
| Agent rewrites unrelated code                  | Task description is ambiguous                | Add "ONLY modify X and Y files" to the task |
| Always fails on attempt 1, passes on attempt 2 | Normal — the fix loop is working as designed | No action needed                            |
| Fails all 7 attempts                           | Task is too complex or ambiguous             | Split into 2-3 smaller tasks                |

### Optimizing for speed vs quality

```bash
# Fast mode (prototyping, don't care about edge cases)
MAX_ITERATIONS=80
MAX_FIX_ATTEMPTS=2
COOLDOWN_SECONDS=2

# Balanced (default nightshift)
MAX_ITERATIONS=200
MAX_FIX_ATTEMPTS=7
COOLDOWN_SECONDS=5

# Maximum quality (critical features, lots of time)
MAX_ITERATIONS=400
MAX_FIX_ATTEMPTS=10
COOLDOWN_SECONDS=8
```

### Validation customization

For different project types, modify `run_full_validation()`:

```bash
# Python project
run_full_validation() {
    black . >> "$1" 2>&1 || return 1
    mypy . >> "$1" 2>&1 || return 1
    ruff check . >> "$1" 2>&1 || return 1
    pytest >> "$1" 2>&1 || return 1
}

# Go project
run_full_validation() {
    gofmt -w . >> "$1" 2>&1 || return 1
    go vet ./... >> "$1" 2>&1 || return 1
    golangci-lint run >> "$1" 2>&1 || return 1
    go test ./... >> "$1" 2>&1 || return 1
}

# Rust project
run_full_validation() {
    cargo fmt >> "$1" 2>&1 || return 1
    cargo clippy -- -D warnings >> "$1" 2>&1 || return 1
    cargo test >> "$1" 2>&1 || return 1
}
```

---

## 14. Failure Modes

### 1. Agent gets stuck in a loop

**Symptom:** Same error on every fix attempt.
**Cause:** The error is in a file not listed in the codebase context, so the agent can't find it.
**Prevention:** Keep the codebase context comprehensive. Include config files, type definitions, and utility modules.

### 2. Agent "fixes" by deleting tests

**Symptom:** Tests pass but the feature doesn't work.
**Cause:** Weak prompt rules.
**Prevention:** The runner script's prompt explicitly says "Do NOT delete or weaken existing tests." If this still happens, add task-specific "MUST NOT" rules.

### 3. Rate limiting

**Symptom:** Claude calls fail with 429 errors.
**Cause:** Too many calls too fast.
**Prevention:** Increase `COOLDOWN_SECONDS`. The `call_claude()` wrapper already retries with 15s backoff.

### 4. Iteration limit hit mid-task

**Symptom:** Script exits during a fix loop.
**Cause:** Too many tasks × too many retries.
**Prevention:** Increase `MAX_ITERATIONS` or reduce `MAX_FIX_ATTEMPTS`. Use the formula: `MAX_ITERATIONS >= NUM_TASKS × (1 + MAX_FIX_ATTEMPTS + 2)`.

### 5. Agent breaks a previous task

**Symptom:** Task 8's implementation breaks Task 3's test.
**Cause:** Tasks have hidden dependencies.
**Prevention:** The full test suite runs on EVERY validation. If a previous test breaks, the fix loop catches it. But if this happens often, your tasks are too coupled — restructure them.

### 6. Stale codebase context

**Symptom:** Agent creates duplicate components or puts code in wrong files.
**Cause:** You added new files but didn't update the context.
**Prevention:** Re-run the codebase exploration before each major run.

### 7. Chrome extension not connected

**Symptom:** Chrome testing phase fails immediately with MCP tool errors.
**Cause:** Chrome browser is closed, extension is disabled, or extension lost connection.
**Prevention:** Before launching, verify Chrome is open and the Claude-in-Chrome extension shows "Connected." Leave Chrome open for the entire run.

### 8. Dev server crashes mid-run

**Symptom:** Chrome tests fail with "connection refused" after working earlier.
**Cause:** A code change introduced a build error that crashed the Next.js dev server.
**Prevention:** The runner script auto-detects this and restarts the dev server. If it keeps crashing, the root cause is a build-time error — check `.agent-logs/dev-server.log`.

### 9. Auth wall blocks Chrome testing

**Symptom:** Chrome test sees a login page instead of the app.
**Cause:** The app requires authentication and there's no active session in the Chrome tab.
**Prevention:** Log into the app in Chrome before starting the run. Session cookies persist across tabs. Alternatively, if your app has a demo/bypass mode, enable it.

### 10. Chrome test always says PASS even when broken

**Symptom:** Features have obvious visual bugs but Chrome phase reports PASS.
**Cause:** The Chrome testing prompt isn't strict enough, or the feature can't be meaningfully tested from the accessibility tree alone.
**Prevention:** This is why screenshots exist — review them in the morning. For highly visual features (animations, precise layouts), always manually review the GIFs.

---

## 15. Pre-Launch Checklist

Run through this before every autonomous session:

```
Before writing the plan:
  [ ] Clear about what features/fixes need to be built
  [ ] Each feature can be broken into independent, testable tasks
  [ ] No task depends on more than 2 prior tasks

The feature plan (todo file):
  [ ] Every task has an **Implementation** section with specific files/functions
  [ ] Every task has a **Validation** section with a testable assertion
  [ ] Tasks are ordered so dependencies come first
  [ ] Task names include numbers (Task 1, Task 2, ...)
  [ ] File saved as todo-{date}_{name}.md

The codebase context:
  [ ] All files the agent might touch are listed
  [ ] Key functions and exports are named
  [ ] Test framework, import syntax, and conventions are specified
  [ ] Forbidden patterns are listed
  [ ] Context reflects the current state of the codebase (not stale)

The runner script:
  [ ] TODO_FILE points to the correct plan
  [ ] MAX_ITERATIONS is high enough (formula: tasks × 10)
  [ ] MAX_FIX_ATTEMPTS is 7+ for overnight runs
  [ ] run_full_validation() matches your project's toolchain
  [ ] Codebase context heredoc is up to date

The environment:
  [ ] `claude` CLI is installed and authenticated
  [ ] `bun` (or your test runner) is installed
  [ ] All project dependencies are installed (pnpm install / npm install)
  [ ] No uncommitted changes you care about (the agent will modify files)
  [ ] .agent-logs/ is in .gitignore
  [ ] .claude_iterations is in .gitignore

Chrome testing (if enabled):
  [ ] Chrome browser is open
  [ ] Claude-in-Chrome extension is installed and active
  [ ] Extension shows "Connected" status
  [ ] Port 31415 (or your DEV_PORT) is not already in use by another process
  [ ] You are logged into the app (if auth is required) — or accept that auth-gated pages won't be testable

Launch:
  [ ] chmod +x run-agent-loop.sh
  [ ] (Optional) Run a quick `bun test && tsc --noEmit` to confirm clean baseline
  [ ] nohup ./run-agent-loop.sh > .agent-logs/stdout.log 2>&1 &
```

---

## 16. Examples

### Example A: Bug fix batch (small, focused)

```markdown
# Bugfix Sprint: 2026-03-20

**Agent Instructions:** Process sequentially. Write tests. Only mark done when tests pass.

## Critical Fixes

- [ ] **Task 1: Fix suggestion click sending message**
  - **Implementation:** In `components/chat-suggestions.tsx`, change the `onClick` handler from calling `sendMessage(suggestion.text)` to calling `setInputValue(suggestion.text)`. The `setInputValue` prop is already passed to the component.
  - **Validation:** Test that clicking a suggestion calls `setInputValue` and does NOT call `sendMessage`.

- [ ] **Task 2: Fix branch navigation not redirecting**
  - **Implementation:** In `app/chat/[chatId]/page.tsx`, in the `createBranchFromNode()` function, add `router.push(\`/chat/\${newChatId}\`)` after the Supabase insert call returns the new chat ID.
  - **Validation:** Test that `createBranchFromNode()` calls `router.push` with the new chat ID.
```

Config: `MAX_ITERATIONS=30`, `MAX_FIX_ATTEMPTS=3`

### Example B: Feature expansion (large, overnight)

```markdown
# Gallery & Resources: 2026-03-25

**Agent Instructions:** Process sequentially. Write tests. Only mark done when tests pass.

## Phase 1: Data Layer

- [ ] **Task 1: Gallery data fetcher**
  - **Implementation:** Create `lib/hooks/use-gallery.ts`. Fetch all messages with image content from Supabase for the current user. Return `{ images: GalleryImage[], isLoading: boolean }`.
  - **Validation:** Test with mocked Supabase client returning 3 images. Assert hook returns array of 3.

- [ ] **Task 2: Resource URL parser**
  - **Implementation:** Create `lib/utils/resource-parser.ts`. Export `parseResources(text: string): Resource[]` that extracts URLs and book titles (pattern: "Title" by Author) from markdown text.
  - **Validation:** Feed text with 3 URLs and 1 book title. Assert array has 4 items with correct types.

## Phase 2: UI

- [ ] **Task 3: Gallery page**
  - **Implementation:** Create `app/gallery/page.tsx`. Use `useGallery()` hook. Render images in a responsive grid using shadcn Card components. Each card shows the image, the chat title it came from, and a date.
  - **Validation:** Test that the component renders the correct number of Card elements given mock data.
    ...
```

Config: `MAX_ITERATIONS=150`, `MAX_FIX_ATTEMPTS=7`

### Example C: Adapting for a Python project

```bash
# In run_full_validation():
run_full_validation() {
    local logfile="$1" all_passed=true
    echo "=== VALIDATION ===" > "$logfile"

    black --check . >> "$logfile" 2>&1 || { all_passed=false; black . >> "$logfile" 2>&1; }
    mypy src/ >> "$logfile" 2>&1 || all_passed=false
    ruff check src/ >> "$logfile" 2>&1 || all_passed=false
    pytest -x --tb=short >> "$logfile" 2>&1 || all_passed=false

    $all_passed
}
```

```bash
# In CODEBASE_CONTEXT, change the conventions:
## Conventions:
- Run `black .` after code changes.
- Type hints on all function signatures.
- Tests in tests/ directory, use pytest fixtures.
- Import order: stdlib, third-party, local (enforced by ruff).
```

---

## Quick Reference Card

```
┌────────────────────────────────────────────────────────────┐
│           AUTONOMOUS AGENT QUICK REF (v2 + Chrome)         │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Setup:                                                    │
│  1. Write todo file    todo-YYYY_MM_DD_name.md             │
│  2. Update context     Codebase map in runner script       │
│  3. Set config         TODO_FILE, limits                   │
│                                                            │
│  Pre-launch (Chrome):                                      │
│  4. Open Chrome        Claude-in-Chrome extension active   │
│  5. Log into app       Session cookies persist for tests   │
│                                                            │
│  Run:                                                      │
│  6. Launch             nohup ./run-agent-loop.sh &         │
│  7. Sleep                                                  │
│                                                            │
│  Morning:                                                  │
│  8. Summary            cat .agent-logs/*summary*           │
│  9. Screenshots        open .agent-logs/screenshots/*.png  │
│  10. Review flags      grep 'REVIEW' todo-*.md             │
│  11. Verify            bun test && tsc --noEmit            │
│  12. Commit            git add -p && git commit            │
│                                                            │
│  Pipeline per task:                                        │
│  Phase 1: Implement  → Claude writes code + tests          │
│  Phase 2: Validate   → prettier, tsc, eslint, bun test    │
│    └─ Fix loop       → up to 7 code fix attempts          │
│  Phase 3: Chrome     → browser visual + functional test    │
│    └─ Fix loop       → up to 3 chrome fix attempts        │
│  Phase 4: Mark done  → checkbox [x] in todo file          │
│                                                            │
│  Formula:                                                  │
│  MAX_ITERATIONS >= TASKS × (CODE_FIXES + CHROME_FIXES + 5)│
│                                                            │
│  Files:                                                    │
│  .agent-logs/nightshift-summary.log  — event timeline      │
│  .agent-logs/task-{N}-*.log          — per-task output     │
│  .agent-logs/chrome-task-{N}.log     — Chrome test results │
│  .agent-logs/screenshots/            — visual evidence     │
│  .agent-logs/validation-*.log        — code check results  │
│  .agent-logs/dev-server.log          — Next.js dev output  │
│  .claude_iterations                  — iteration counter   │
│                                                            │
│  Task outcomes:                                            │
│  [x] Task N: Name              — fully verified            │
│  [x] Task N: Name — CHROME..   — code OK, visual review   │
│  [x] Task N: Name — NEEDS..    — code failed, skip        │
│                                                            │
└────────────────────────────────────────────────────────────┘
```
