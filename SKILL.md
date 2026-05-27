---
name: autonomous-agent-nightshift
description: Use when the user wants to run Claude Code agents overnight on a multi-task batch — set up a nightshift, write a todo file with Implementation+Validation pairs, configure an agent loop that implements/tests/validates/retries, or run a bulletproof PR-review loop. Triggers on "nightshift", "autonomous agent", "overnight agent", "bulletproof PR", "let Claude work overnight", "todo file for Claude", "run agents while I sleep". NOT for: single bugfixes (just have Claude do it directly), architecture decisions (discuss first), one-shot refactors, single-task automation, or work that doesn't have 5+ independently-verifiable tasks.
---

# Autonomous Agent Nightshift

A playbook + reusable bash harness for running Claude Code agents overnight. The user writes a feature plan (todo file with checkboxes), the harness orchestrates implement → validate → fix loop → mark done, and the user wakes up to a validated diff (or a PR with review feedback already addressed, in Bulletproof mode).

This skill drives three core workflows:

1. **Setup** — initialize a new nightshift run on the user's project
2. **Morning review** — triage results after a completed run
3. **Bulletproof** — production-hardening sweep with branch + PR + review-comment healing

All bundled assets live under this skill's directory:

```
scripts/
  run-agent-loop.sh         Classic feature-implementation runner
  nightshift-bulletproof.sh Branch + commit + PR + review variant
  start-nightshift.sh       start/stop/status/tail launcher
  test-nightshift.sh        Recursive validation loop (no Claude)
templates/
  todo-template.md          Feature-plan skeleton
  codebase-context.md       Heredoc fill-in for the runner
  qa-checklist-template.md  Production-ship checklist
  runner-config.env         Tuning presets
docs/
  01-playbook.md            Full master guide (read first)
  02-bulletproof-mode.md    PR-loop variant
  03-chrome-testing.md      Live browser MCP testing
  04-qa-checklist.md        Writing production checklists
  05-failure-modes.md       Cheatsheet of seen failures
  06-test-loop.md           Recursive validation loop
examples/
  todo-simple-example.md      Synthetic 5-task dark-mode toggle (start here)
  bulletproof-steps-example.md Synthetic 10-step production hardening sweep
  qa-checklist-saas.md        Real 22-section SaaS checklist (sanitized)
  bulletproof-summary.log     Real 100-step run timeline (sanitized)
```

---

## Workflow 1 — Setup (new run)

**Trigger:** user says "set up nightshift", "I want to run an agent overnight to build X", "let's automate this feature build", or similar.

### Step 1: Detect project stack

Read these files (if present) to detect framework, test runner, package manager, lint/format tools:

- `package.json` (look at scripts, dependencies)
- `tsconfig.json`
- `requirements.txt` / `pyproject.toml` / `Cargo.toml` / `go.mod`
- `vitest.config.*`, `jest.config.*`, `playwright.config.*`, `bun.lockb`
- `.eslintrc.*`, `.prettierrc*`, `biome.json`

Record: stack, package manager (`npm` / `pnpm` / `bun` / `yarn`), lint command, type-check command, test command, dev-server command + port.

### Step 2: Clarify the feature plan

Ask the user **what they want built**. Aim for:

- One sentence per task: a specific outcome, not a vague goal
- Each task small enough to fit in one Claude session (~5–15 min)
- No task depends on more than 2 prior tasks
- Number tasks sequentially across phases

If the user gives a vague request ("polish the dashboard"), help them split it into specific tasks. Bad: "improve the UI." Good: "Add a stop button that aborts the SSE stream and shows during generation."

### Step 3: Write the todo file

Use `templates/todo-template.md` as the structure. Create `todo-{YYYY_MM_DD}_{name}.md` at the project root. For each task, fill both **Implementation** and **Validation** with specifics:

- **Implementation** must name the exact files, functions, props, classes to touch — and reference any existing hook/pattern the agent should reuse
- **Validation** must be a testable assertion ("Assert that X returns Y when given Z"), not "make sure it works"

### Step 4: Generate the codebase context

Explore the user's repo (Glob + key file reads) and produce a `CODEBASE_CONTEXT` heredoc following `templates/codebase-context.md`. Include:

- File paths the agent might touch, one-liner per file
- Architecture patterns (state management, data flow)
- Conventions (formatting, naming, testing imports)
- Forbidden patterns (no `any`, no `@ts-ignore`, etc.)

### Step 5: Copy + customize the runner

Copy `scripts/run-agent-loop.sh` and `scripts/start-nightshift.sh` into the project root. Edit `run-agent-loop.sh`:

1. Set `TODO_FILE` to the file you just created
2. Paste the codebase context into the `CODEBASE_CONTEXT` heredoc
3. Update `run_full_validation()` for the user's toolchain. Per-stack patterns:
   - **Node/TS:** `npx prettier --write . && npx tsc --noEmit && npx eslint . --quiet && bun test`
   - **Python:** `black . && mypy . && ruff check . && pytest`
   - **Go:** `gofmt -w . && go vet ./... && golangci-lint run && go test ./...`
   - **Rust:** `cargo fmt && cargo clippy -- -D warnings && cargo test`
4. Adjust `DEV_PORT` to match the user's dev server
5. Tune limits using the formula `MAX_ITERATIONS >= NUM_TASKS × (1 + MAX_FIX_ATTEMPTS + 2)`. Default for overnight: `MAX_ITERATIONS=200`, `MAX_FIX_ATTEMPTS=7`.

### Step 6: Pre-flight check

Verify (and report each as ✓ or ✗):

- [ ] `claude` CLI authenticated (`claude --version`)
- [ ] Test runner installed and clean baseline (`bun test && npx tsc --noEmit` returns 0)
- [ ] No uncommitted changes the user cares about (the agent will modify files)
- [ ] `.agent-logs/` and `.claude_iterations` added to `.gitignore`
- [ ] (If Chrome testing) Chrome open with Claude-in-Chrome extension showing "Connected"
- [ ] (If Chrome testing) User logged into the app for any auth-walled routes
- [ ] (If Bulletproof) `gh auth status` green; `GITHUB_REPO` config set

### Step 7: Launch instructions

Don't launch for the user. Tell them:

```bash
chmod +x run-agent-loop.sh start-nightshift.sh
./start-nightshift.sh start          # detached, survives terminal close
./start-nightshift.sh tail           # follow the summary log
```

Then `./start-nightshift.sh stop` to halt.

---

## Workflow 2 — Morning review

**Trigger:** user says "review my nightshift", "what happened overnight", "check the agent's work", or runs `./start-nightshift.sh status` and asks for help interpreting.

### Step 1: Read the summary log

```
cat .agent-logs/nightshift-summary.log
```

Identify:

- Tasks completed on first try
- Tasks completed after N fix attempts
- Tasks marked `FAILED` (exhausted retries)
- Tasks with `CHROME REVIEW NEEDED` (code passed, visual unverified)
- Total runtime, total iterations used

### Step 2: Find the manual-review tasks

```
grep 'NEEDS MANUAL REVIEW' todo-*.md
grep 'CHROME REVIEW NEEDED' todo-*.md
```

For each, read the task's body + `.agent-logs/task-{N}.log` to understand why it failed.

### Step 3: Surface the diff

```
git diff --stat
git diff --stat ${BASE_BRANCH:-main}..HEAD   # if a branch was created
```

Summarize what changed by area (routes, components, tests, configs).

### Step 4: Spot-check visual evidence

If Chrome testing ran:

```
ls .agent-logs/screenshots/
```

For each REVIEW-flagged UI task, open the screenshot/GIF and verify visually (or instruct the user to).

### Step 5: Report

Produce a structured summary:

```
Completed: N tasks (M on first try, K with fixes)
Failed: N tasks — [list with file:line of the issue]
Chrome review needed: N tasks — [list]
Diff: +X / -Y across Z files
Suggested next steps:
  1. Verify [task N] manually — [why]
  2. Run `bun test` to confirm clean baseline
  3. Commit accepted work: git add -p && git commit
```

Do **not** auto-commit. The human stages and commits.

---

## Workflow 3 — Bulletproof (production hardening sweep)

**Trigger:** user says "bulletproof my codebase", "production-ship sweep", "harden before launch", "run an overnight PR loop", or similar.

### Step 1: Audit and propose steps

Read the codebase. Produce a `BULLETPROOF-STEPS.md` organized by category:

```
## Category 1 — Styling & Design System
### Step 1 — {specific hardening action}
**Implementation:** ...
**Validation:** ...
```

Common categories (pick what applies to the user's codebase):

1. Styling & Design System
2. Performance
3. Accessibility
4. Security headers + CSP
5. Auth + session hardening
6. Rate limiting + quota
7. Error boundaries + observability
8. SEO + meta
9. Mobile + responsive
10. Legal + compliance copy

Each step must be atomic — one commit. Validate is a real assertion.

### Step 2: Configure + launch

Copy `scripts/nightshift-bulletproof.sh` to the project root and edit:

```bash
PLAN_FILE="BULLETPROOF-STEPS.md"
BASE_BRANCH="main"                              # or staging branch
NIGHTSHIFT_BRANCH="nightshift/bulletproof-$(date '+%Y-%m-%d')"
GITHUB_REPO="owner/repo"                         # exact match
PR_WAIT_MINUTES=20                               # how long to wait for review
```

Paste codebase context. Pre-flight per Workflow 1 Step 6, plus:

- [ ] `gh auth status` green
- [ ] `gh auth refresh -s repo` (token needs `repo` scope to reply to PR comments)
- [ ] Working tree clean (Bulletproof refuses to start dirty)

### Step 3: Launch

```bash
chmod +x nightshift-bulletproof.sh
nohup ./nightshift-bulletproof.sh > .agent-logs/stdout.log 2>&1 &
```

Filters available:

```
--from 15 --to 30      # Only steps 15-30
--category 1           # Whole category
--skip-chrome          # No browser test
--skip-pr              # Don't open PR
--dry-run              # Parse only
```

### Step 4: PR review (the killer feature)

After all steps complete, Bulletproof opens a PR and polls for comments. For each new comment it:

1. Reads the comment + the referenced file
2. Implements the fix
3. Runs the validation gate
4. Commits with a message referencing the comment
5. Replies inline: "Fixed in commit {sha} — {what changed and why}"
6. Pushes

In the morning the user has a PR with N+1 commits where the agent already addressed initial feedback. Read `examples/bulletproof-summary.log` for a real timeline.

---

## Key principles to honor (these make nightshift actually work)

When helping a user with any of the above workflows, internalize these rules from production experience (full discussion in `docs/01-playbook.md`):

### 1. The human writes the WHAT. The agent writes the HOW.

Your job (and the user's) is to write precise task specs with clear validation criteria. The agent figures out the code. Vague tasks fail. Specific tasks succeed.

### 2. Every task must be independently verifiable.

If you can't write a validation criterion for it, the agent can't know when it's done. No "make it look good" — only "assert X equals Y."

### 3. The agent has no memory between tasks.

Each `claude -p` call is a fresh session. The codebase context heredoc is the agent's only map. Keep it comprehensive and current. Stale context = agent writes code in the wrong place.

### 4. Tests are the contract.

The agent writes a test, implements the feature, then the harness independently validates. No trust — only proof. Never let the agent "fix" by deleting tests; the runner prompt enforces this, but spot-check the diff.

### 5. Failure is handled, not feared.

Tasks that exhaust retries get marked `[x] — NEEDS MANUAL REVIEW` and the loop moves on. The user deals with the hard ones in the morning. This is the correct trade-off.

### 6. Chrome testing catches what unit tests can't.

| Unit tests catch | Chrome catches |
|------------------|----------------|
| Wrong return values | Button invisible (z-index, opacity) |
| Type errors | Dark mode breaks colors |
| Logic bugs | Click handler fires but UI doesn't update |
| API schema mismatches | React hydration errors |

For UI tasks, always run Chrome testing. For backend-only tasks, skip it (`--skip-chrome`).

### 7. Per-stack validation is non-negotiable.

The `run_full_validation()` function must match the user's toolchain exactly. Mismatched validation = false PASS or false FAIL. Always confirm clean baseline (`bun test` etc.) before launching.

---

## Common pitfalls to warn the user about

When setting up or reviewing:

| Pitfall | Prevention |
|---------|------------|
| Vague tasks ("improve the dashboard") | Force a specific outcome with a testable assertion |
| Codebase context missing key files | Run a quick Glob over `src/` to confirm coverage |
| Validation function doesn't match project | Run each step manually before launch — if you can't run it, agent can't |
| Auth wall blocks Chrome testing | Log into the app in Chrome before launch (session persists) |
| `MAX_ITERATIONS` too low | Use formula: `tasks × (1 + fix_attempts + 2)` |
| Agent breaks earlier tasks | Full test suite runs on every validation — fix loop usually catches it. If chronic, tasks are too coupled |
| No `.gitignore` for `.agent-logs/` | Add before launch — these dirs get noisy |

---

## When NOT to use nightshift

This skill is for **multi-task overnight runs**. For:

- A single bugfix or one-shot feature → just have Claude do it directly
- Exploration / architecture decisions → discuss first, don't automate
- Code review of someone else's PR → use a review skill instead
- Refactors with broad cross-file changes → break into a todo plan first, but consider doing it interactively

Nightshift works when the WHAT is well-defined and the HOW is mechanical. Don't force it on ambiguous work.

---

## Quick prompt patterns

When the user starts ambiguously, redirect them to a workable shape:

**User:** "Help me automate building feature X."
**You:** Detect their stack. Then: "Let's write the todo file. What's the user-visible outcome? What files will it touch? What's the test that proves it works?"

**User:** "It worked! Now what?"
**You:** Run Workflow 2 — morning review. Don't auto-commit.

**User:** "It's been running for 6 hours, is it stuck?"
**You:** `./start-nightshift.sh status` + check the iteration counter + tail the latest task log. If genuinely stuck, `stop`, diagnose from logs, fix the codebase context or task spec, restart.

---

## Reference: full documentation index

- **`docs/01-playbook.md`** — The master guide. Read once cover-to-cover. Has every detail this skill summarizes.
- **`docs/02-bulletproof-mode.md`** — PR-loop variant deep dive.
- **`docs/03-chrome-testing.md`** — MCP browser testing setup and verdict contract.
- **`docs/04-qa-checklist.md`** — Writing production-ship checklists.
- **`docs/05-failure-modes.md`** — Cheatsheet for "agent did X, what now?"
- **`docs/06-test-loop.md`** — Recursive validation loop (no Claude, just CI as a loop — useful for long dev sessions where you want continuous verification).
- **`examples/`** — Real sanitized artifacts. Read these to see what "good" looks like at scale.
