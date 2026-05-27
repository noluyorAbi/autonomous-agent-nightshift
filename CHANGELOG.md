# Changelog

All notable changes documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning follows [SemVer](https://semver.org/).

## [Unreleased]

## [1.3.0] — 2026-05-27

### Removed (sanitization for public release)

- `examples/todo-design-nightshift.md` — too project-specific to sanitize cleanly (real soccer-club client identifiers: location, founding year, address coordinates, named characters from the wordmark). Synthetic `todo-simple-example.md` + `bulletproof-steps-example.md` cover the example need without the leakage risk.

### Fixed (final pre-public sanitization sweep)

- `examples/qa-checklist-saas.md` — replaced "BMW" reference with generic "hardcoded company name" phrasing.
- `examples/bulletproof-summary.log` — replaced `noluyorAbi/bmw-fastlane-ai-coach` repo URL (×3) with `owner/repo`, replaced `road-to-saas` branch name (×4) with `staging`.
- `examples/README.md` — restructured to drop deleted entry; softened intro line.

### Changed

- README `/plugin install` block now correctly shows `marketplace add` step (custom marketplace flow). Previous single-line `/plugin install` claim implied first-party marketplace presence that didn't exist.
- README badges: replaced dead "Claude Code Skill" badge URL with working docs link, added CI status badge, added release-version badge.
- `SKILL.md` examples list updated for the deleted file.

### Verified

- `install.sh` end-to-end logic via local `file://` clone test: fresh clone → re-pull idempotent → SKILL.md frontmatter loads → all 6 slash commands present. Real network test happens post-public-flip.

### Repo now public

Visibility flipped from private to public after this release was prepared. Install command becomes functional for everyone:

```
curl -fsSL https://raw.githubusercontent.com/noluyorAbi/autonomous-agent-nightshift/main/bin/install.sh | bash
```

## [1.2.0] — 2026-05-27

## [1.2.0] — 2026-05-27

### Fixed (real bugs found via self-audit)

- `commands/nightshift-debug.md` used `sed -i ''` (BSD-only). Replaced with `perl -i -pe` (cross-platform). Linux users would have hit `sed: invalid option -- '''`.
- Two scripts had `#!/bin/bash` shebang. macOS ships bash 3.2 at `/bin/bash` (Apple stuck on GPLv2). Switched all four scripts to `#!/usr/bin/env bash` for consistency and modern-bash discovery.

### Added (gaps discovered by self-audit)

- **`docs/07-cost-and-safety.md`** — real $$ cost estimates ($0.50/task Sonnet, $1.50/task Opus), pre-launch safety checklist, permission-prompt handling, disaster recovery. **Critical missing context — users had no idea what an overnight run costs.**
- **`docs/FAQ.md`** — common questions organized by topic (general, cost, setup, during-run, results, skill-specific, defaults rationale).
- `SECURITY.md` — vulnerability disclosure policy.
- `.github/ISSUE_TEMPLATE/bug_report.md` — structured bug intake.
- `.github/ISSUE_TEMPLATE/stack_adapter.md` — template for requesting/contributing new-stack adapters.
- `.github/PULL_REQUEST_TEMPLATE.md` — PR checklist with sanitization reminder.
- `.editorconfig` — consistent line endings + indentation across contributors.

### Changed

- **SKILL.md description now includes a `NOT for:` clause** — prevents over-triggering on "single bugfix", "architecture decision", "one-shot refactor" type queries that shouldn't pull in the whole nightshift workflow.
- README now leads with a **Cost and safety** section before prerequisites. Calling out the real money risk up front.
- `docs/` index in README updated.

### Why this release

Self-applied audit ("does the repo work, is it a good skill, what's missing") found:
- 2 real bugs (sed portability, shebang choice)
- 1 description issue (no NOT-for clause = over-trigger risk)
- 5 missing files (cost docs, FAQ, security, issue templates, editorconfig)

All addressed. No remaining critical gaps. Outstanding nice-to-haves: end-to-end install.sh test on a fresh machine, asciinema demo recording, marketplace listing.

## [1.1.0] — 2026-05-27

## [1.1.0] — 2026-05-27

### Added

- `commands/nightshift-resume.md` — diagnose why a nightshift stopped (iteration limit, rate limit, auth, crash, dev-server) and restart cleanly. The runner is inherently resumable; this command codifies the diagnose+resume workflow.
- `commands/nightshift-debug.md` — when a task hits MAX_FIX_ATTEMPTS, walk through task spec + Claude transcript + validation logs, classify the failure pattern, and propose one of three actions (rewrite task / fix codebase context / implement manually).
- `examples/todo-simple-example.md` — synthetic 5-task dark-mode toggle. Beginner-friendly counterpart to the 50-task design overhaul.
- `examples/bulletproof-steps-example.md` — synthetic 10-step production hardening sweep (security headers → auth → observability → performance → consent). Lets users see what BULLETPROOF-STEPS.md input looks like without inheriting BMW/InterviewPilot domain detail.

### Fixed

- 8 inherited shellcheck warnings across `scripts/run-agent-loop.sh`, `scripts/nightshift-bulletproof.sh`, `scripts/test-nightshift.sh` (SC2188 `> "$f"` truncation idiom → `: > "$f"`; SC2155 `local x=$(cmd)` masking → split declare+assign; SC2034 unused `all_comments` var). CI severity restored from `error` to `warning`.

### Changed

- `.claude-plugin/plugin.json` wires the two new slash commands.
- README repo-layout block reflects the new examples + commands.

## [1.0.0] — 2026-05-26

## [1.0.0] — 2026-05-26

### Added

- `SKILL.md` — Claude Code skill manifest with frontmatter triggering on nightshift-related phrases. Encodes three workflows: setup, morning review, bulletproof PR sweep.
- `.claude-plugin/plugin.json` — plugin marketplace manifest.
- `commands/` — slash commands `/nightshift-setup`, `/nightshift-review`, `/nightshift-bulletproof`, `/nightshift-status` for direct invocation.
- `docs/01-playbook.md` — master 47KB guide (philosophy, three artifacts, tuning, failure modes, Chrome testing, per-stack adaptation).
- `docs/02-bulletproof-mode.md` — PR-loop variant with per-step commits and review healing.
- `docs/03-chrome-testing.md` — live browser MCP testing setup and verdict contract.
- `docs/04-qa-checklist.md` — guide for writing production-ship checklists.
- `docs/05-failure-modes.md` — cheatsheet of seen failures and fixes.
- `docs/06-test-loop.md` — recursive validation loop (no Claude).
- `scripts/run-agent-loop.sh` — classic feature-implementation runner with codebase-context heredoc, validation gate, fix loop, optional Chrome phase.
- `scripts/nightshift-bulletproof.sh` — branch + commit per step + PR + review-comment healing variant.
- `scripts/start-nightshift.sh` — start/stop/status/tail wrapper for detached runs.
- `scripts/test-nightshift.sh` — recursive lint/type/test loop for continuous validation.
- `templates/todo-template.md` — feature-plan skeleton with runner contract.
- `templates/codebase-context.md` — heredoc fill-in with quality checklist.
- `templates/qa-checklist-template.md` — production-ship checklist skeleton (22 sections).
- `templates/runner-config.env` — tuning presets per scenario.
- `examples/todo-design-nightshift.md` — real sanitized 50-task design overhaul.
- `examples/qa-checklist-saas.md` — real sanitized 22-section SaaS checklist.
- `examples/bulletproof-summary.log` — real sanitized 100-step run timeline.
- `bin/install.sh` — one-liner installer for user-level or project-level skill install.
- `.github/workflows/lint.yml` — CI runs shellcheck on scripts.
- `CONTRIBUTING.md`, `CHANGELOG.md`, `LICENSE` (MIT).

### Sourced from

- `noluyorAbi/better-llm-interface` (private) — playbook, classic runner, test-nightshift, start-nightshift.
- `noluyorAbi/bmw-fastlane-ai-coach` (private) — bulletproof runner, QA checklist, summary log.
- `noluyorAbi/NORD-LERCHENAU-site` (private) — design-nightshift todo example.

All project-specific identifiers sanitized before publication.
