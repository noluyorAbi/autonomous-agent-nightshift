# Autonomous Agent Nightshift

A complete playbook + reusable harness for running Claude Code agents overnight: write a feature plan, hit launch, wake up to merged PRs.

Built from real production runs on multiple SaaS codebases (Next.js, Bun, Supabase, Stripe). The patterns generalize — Python, Go, Rust adaptations are documented.

---

## What This Is

Three components working together:

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   FEATURE PLAN  │────▶│  RUNNER SCRIPT   │────▶│  CODEBASE CTX   │
│  (todo file)    │     │  (bash harness)  │     │  (embedded map) │
│                 │     │                  │     │                 │
│ What to build   │     │ How to loop      │     │ Where things are│
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

- **You** write the WHAT (todo file with checkboxes + validation criteria).
- **The harness** orchestrates: extract task → call Claude → validate → fix loop → mark done → next.
- **The agent** writes the HOW: code + tests, with the codebase map as its only memory between fresh sessions.

---

## Two Modes

| Mode | Script | Use case |
|------|--------|----------|
| **Classic** | `scripts/run-agent-loop.sh` | Feature implementation. Loops todo file, runs validation, optional Chrome browser test, marks checkboxes. No git. You review and commit in the morning. |
| **Bulletproof** | `scripts/nightshift-bulletproof.sh` | Production hardening. Same loop but: creates dedicated branch, commits per task, opens PR at end, optionally waits for review and addresses comments. |

Both share the same validation pipeline: **prettier → tsc → eslint → tests → (optional) Chrome browser test**.

---

## Quickstart

```bash
# 1. Clone this repo or copy scripts/ + templates/ into your project
cp scripts/run-agent-loop.sh your-project/
cp scripts/start-nightshift.sh your-project/
cp templates/todo-template.md your-project/todo-2026_05_26_my-feature.md

# 2. Edit the todo file — add tasks with Implementation + Validation
$EDITOR your-project/todo-2026_05_26_my-feature.md

# 3. Edit the runner script — paste your codebase context into the heredoc
$EDITOR your-project/run-agent-loop.sh
#    Update TODO_FILE="todo-2026_05_26_my-feature.md"

# 4. Pre-flight check
cd your-project
chmod +x run-agent-loop.sh start-nightshift.sh
bun test && npx tsc --noEmit    # clean baseline

# 5. Launch
./start-nightshift.sh start
./start-nightshift.sh tail       # follow the summary log

# 6. Sleep

# 7. Morning review
./start-nightshift.sh status
cat .agent-logs/nightshift-summary.log
grep 'REVIEW' todo-*.md          # tasks that need eyes
git diff --stat                  # what changed
git add -p && git commit         # ship what you like
```

---

## Repo Layout

```
docs/
├── 01-playbook.md           Main guide — read this first
├── 02-bulletproof-mode.md   PR-loop variant (commit per task, open PR, address review)
├── 03-chrome-testing.md     Live browser verification via MCP
├── 04-qa-checklist.md       Writing a production-ship checklist
├── 05-failure-modes.md      Common failures + prevention
└── 06-test-loop.md          Recursive validation loop (no Claude — just CI-as-a-loop)

scripts/
├── run-agent-loop.sh        Generic feature-implementation runner (no git)
├── start-nightshift.sh      start/stop/status/tail wrapper
├── nightshift-bulletproof.sh Branch + commit + PR + review variant
└── test-nightshift.sh       Recursive validation loop (no Claude, just checks)

templates/
├── todo-template.md         Blank feature-plan skeleton
├── codebase-context.md      Heredoc filler for the runner
├── qa-checklist-template.md Production-ship checklist skeleton
└── runner-config.env        Example tuning per scenario

examples/
├── todo-design-nightshift.md  Real (sanitized) overnight design-system overhaul
├── qa-checklist-saas.md       Real (sanitized) production-ship checklist
└── bulletproof-summary.log    Real (sanitized) event timeline from a 100-step run
```

---

## Pipeline Per Task

```
Phase 1: Implement   → Claude writes code + tests using the codebase context
Phase 2: Validate    → prettier · tsc · eslint · test runner
  └─ Fix loop        → up to MAX_FIX_ATTEMPTS (default 7) code-fix rounds
Phase 3: Chrome      → optional live browser test via Claude-in-Chrome MCP
  └─ Fix loop        → up to MAX_CHROME_FIX_ATTEMPTS (default 3) visual-fix rounds
Phase 4: Mark done   → checkbox [x] in todo file (Bulletproof: also git commit)
```

If all retries fail, the task is marked `[x] — NEEDS MANUAL REVIEW` and the loop moves on. You triage in the morning.

---

## Tuning

| Scenario | MAX_ITERATIONS | MAX_FIX_ATTEMPTS | COOLDOWN |
|----------|----------------|------------------|----------|
| 5 easy tasks | 50 | 3 | 2s |
| 16 mixed tasks (default) | 200 | 7 | 5s |
| 30+ ambitious tasks | 400 | 10 | 8s |
| Quick prototype | 40 | 2 | 2s |

Formula: `MAX_ITERATIONS >= NUM_TASKS × (1 + MAX_FIX_ATTEMPTS + 2)`

---

## Prerequisites

- `claude` CLI installed and authenticated
- `bun` (or your test runner — the validation function is editable)
- `gh` CLI authenticated (Bulletproof mode only, for PR creation)
- Chrome + [Claude-in-Chrome extension](https://chromewebstore.google.com/) (only if Phase 3 enabled)
- A project with: linter, type checker, test runner, dev server

---

## Adapting to Other Stacks

The validation function is a single bash function. Replace it:

```bash
# Python
run_full_validation() {
    black . && mypy . && ruff check . && pytest
}

# Go
run_full_validation() {
    gofmt -w . && go vet ./... && golangci-lint run && go test ./...
}

# Rust
run_full_validation() {
    cargo fmt && cargo clippy -- -D warnings && cargo test
}
```

Full per-stack examples in `docs/01-playbook.md` §13.

---

## License

MIT. Distilled from production use across multiple closed-source projects; the patterns are intentionally generic.

## Credits

Originally extracted from `better-llm-interface` and `bmw-fastlane-ai-coach` private repos. This consolidation generalizes the playbook so anyone can run nightshift on their codebase.
