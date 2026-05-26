# Autonomous Agent Nightshift

> **A Claude Code skill + reusable bash harness for running AI agents overnight on your codebase.**
> Write a todo file with checkboxes. Hit launch. Wake up to validated code (or a PR with review feedback already addressed).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Skill](https://img.shields.io/badge/Claude%20Code-Skill-orange)](https://docs.claude.com/en/docs/claude-code)
[![Bash](https://img.shields.io/badge/Bash-5.0+-green)](https://www.gnu.org/software/bash/)

Built from real production runs on multiple SaaS codebases (Next.js, Bun, Supabase, Stripe, real-estate websites, design-system overhauls). The patterns generalize — Python, Go, Rust adaptations are documented.

---

## What is this?

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

Per-task pipeline:

```
Phase 1: Implement   → Claude writes code + tests
Phase 2: Validate    → prettier · tsc · eslint · test runner
  └─ Fix loop        → up to MAX_FIX_ATTEMPTS (default 7) code-fix rounds
Phase 3: Chrome      → optional live browser test via Claude-in-Chrome MCP
  └─ Fix loop        → up to MAX_CHROME_FIX_ATTEMPTS (default 3) visual-fix rounds
Phase 4: Mark done   → checkbox [x] in todo file
```

Failed tasks get `[x] — NEEDS MANUAL REVIEW` and the loop moves on. You triage in the morning.

---

## Install

### As a Claude Code skill (recommended)

Drop this repo into your Claude Code skills directory and Claude will load it automatically when you ask anything nightshift-related.

```bash
# User-level (available across all projects)
git clone https://github.com/noluyorAbi/autonomous-agent-nightshift ~/.claude/skills/autonomous-agent-nightshift

# Or project-level (only this project)
cd your-project
git clone https://github.com/noluyorAbi/autonomous-agent-nightshift .claude/skills/autonomous-agent-nightshift
```

Then in Claude Code:

> "Set up a nightshift run to build {feature}."
>
> "Help me write a todo file for tonight's agent run."
>
> "Review last night's nightshift results."
>
> "Bulletproof this codebase before launch."

The skill triggers on those phrases and walks you through setup, launch, or review. See `SKILL.md` for the full skill contract.

### As a plugin

If your Claude Code plugin marketplace is configured:

```bash
/plugin install autonomous-agent-nightshift
```

The plugin manifest is at `.claude-plugin/plugin.json`.

### Manual (no skill, just bash)

Copy the scripts and templates into your project:

```bash
git clone https://github.com/noluyorAbi/autonomous-agent-nightshift /tmp/nightshift
cp /tmp/nightshift/scripts/run-agent-loop.sh ./
cp /tmp/nightshift/scripts/start-nightshift.sh ./
cp /tmp/nightshift/templates/todo-template.md ./todo-$(date +%Y_%m_%d)_my-feature.md
```

Then edit per `docs/01-playbook.md`.

---

## Quickstart (with the skill)

After installing the skill, just talk to Claude:

```
> Set up a nightshift to add a stop button to my chat UI, plus
  branch navigation, plus a media gallery page.

Claude reads your package.json, detects your stack, writes
todo-2026_05_26_chat-features.md with three properly-spec'd tasks,
generates the codebase context heredoc by exploring src/, copies
and customizes run-agent-loop.sh, runs preflight checks, and tells
you the exact launch command.
```

```
> Launch it.

You run: ./start-nightshift.sh start
```

```
> [Next morning] Show me what happened overnight.

Claude reads .agent-logs/nightshift-summary.log, greps the todo
for REVIEW flags, summarizes the diff by area, shows screenshots
for any CHROME REVIEW NEEDED tasks, and produces a structured
report with suggested commits.
```

---

## Quickstart (manual)

```bash
# 1. Copy scripts + a todo template into your project
cp scripts/run-agent-loop.sh your-project/
cp scripts/start-nightshift.sh your-project/
cp templates/todo-template.md your-project/todo-$(date +%Y_%m_%d)_my-feature.md

# 2. Edit the todo file — add tasks with Implementation + Validation
$EDITOR your-project/todo-*.md

# 3. Edit the runner — paste codebase context into the heredoc
$EDITOR your-project/run-agent-loop.sh
#    Update TODO_FILE="todo-*.md" and run_full_validation() for your toolchain

# 4. Pre-flight
cd your-project
chmod +x run-agent-loop.sh start-nightshift.sh
bun test && npx tsc --noEmit    # clean baseline

# 5. Launch
./start-nightshift.sh start
./start-nightshift.sh tail       # follow the summary log

# 6. Sleep

# 7. Morning review
cat .agent-logs/nightshift-summary.log
grep 'REVIEW' todo-*.md          # tasks that need eyes
git diff --stat                  # what changed
git add -p && git commit         # ship what you like
```

---

## Two modes

| Mode | Script | Use case |
|------|--------|----------|
| **Classic** | `scripts/run-agent-loop.sh` | Feature implementation. Loops todo file, runs validation, optional Chrome browser test, marks checkboxes. No git. You review and commit in the morning. |
| **Bulletproof** | `scripts/nightshift-bulletproof.sh` | Production hardening. Same loop but: creates dedicated branch, commits per task, opens PR at end, optionally waits for review and addresses comments. |

Both share the same validation pipeline: **prettier → tsc → eslint → tests → (optional) Chrome browser test**.

---

## Repo layout

```
SKILL.md                     Claude Code skill manifest + workflow guide
.claude-plugin/plugin.json   Plugin marketplace manifest

docs/
├── 01-playbook.md           Master guide — read this first (47 KB)
├── 02-bulletproof-mode.md   PR-loop variant (commit per task, open PR, address review)
├── 03-chrome-testing.md     Live browser verification via Claude-in-Chrome MCP
├── 04-qa-checklist.md       Writing a production-ship checklist
├── 05-failure-modes.md      Cheatsheet of seen failures + fixes
└── 06-test-loop.md          Recursive validation loop (no Claude)

scripts/
├── run-agent-loop.sh        Classic feature-implementation runner
├── nightshift-bulletproof.sh Branch + commit + PR + review variant
├── start-nightshift.sh      start/stop/status/tail wrapper
└── test-nightshift.sh       Recursive validation loop

templates/
├── todo-template.md         Blank feature-plan skeleton
├── codebase-context.md      Heredoc filler for the runner
├── qa-checklist-template.md Production-ship checklist skeleton
└── runner-config.env        Tuning presets per scenario

examples/
├── todo-design-nightshift.md  Real (sanitized) 50-task design overhaul
├── qa-checklist-saas.md       Real (sanitized) 22-section SaaS checklist
└── bulletproof-summary.log    Real (sanitized) 100-step run timeline
```

---

## Tuning

Formula: `MAX_ITERATIONS >= NUM_TASKS × (1 + MAX_FIX_ATTEMPTS + 2)`

| Scenario | MAX_ITERATIONS | MAX_FIX_ATTEMPTS | COOLDOWN |
|----------|----------------|------------------|----------|
| 5 easy tasks | 50 | 3 | 2s |
| 16 mixed tasks (default) | 200 | 7 | 5s |
| 30+ ambitious tasks | 400 | 10 | 8s |
| Quick prototype | 40 | 2 | 2s |
| 100-step Bulletproof sweep | 500 | 7 | 5s |

Full presets in `templates/runner-config.env`.

---

## Adapting to other stacks

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

Per-stack codebase-context examples and conventions in `docs/01-playbook.md` §11 and §13.

---

## Prerequisites

- `claude` CLI installed and authenticated ([install instructions](https://docs.claude.com/en/docs/claude-code))
- `bun` (or your test runner — the validation function is editable)
- `gh` CLI authenticated (Bulletproof mode only, for PR creation)
- Chrome + [Claude-in-Chrome extension](https://chromewebstore.google.com/) (only if Phase 3 enabled)
- A project with: linter, type checker, test runner, dev server

---

## Why nightshift

The autonomous loop verifies code compiles, lints, types pass, unit tests pass, and the browser sees the element. It does **not** verify the user's golden path end-to-end, payment flows, email sends, cross-feature interactions, performance, cross-browser behavior, mobile UX, legal copy, or compliance.

That's the human's job in the morning. The QA checklist (`templates/qa-checklist-template.md`) is the contract for those things.

So nightshift is not "AI replaces engineering." It's "AI handles the mechanical 80% so you can spend morning hours on the judgment-heavy 20%."

---

## License

MIT. Patterns intentionally generic so they're copyable.

## Credits

Distilled from production runs on `better-llm-interface` and `bmw-fastlane-ai-coach` private repos. This consolidation generalizes the playbook so anyone can run nightshift on their codebase.

## Contributing

Issues, PRs, and stack-specific adaptation guides welcome. The most valuable contributions are:

- New validation-function snippets for stacks not yet covered (Elixir, Kotlin, Swift, etc.)
- Real (sanitized) examples of todo files / QA checklists from your own runs
- Failure modes you've hit that aren't in `docs/05-failure-modes.md`
