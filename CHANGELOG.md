# Changelog

All notable changes documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning follows [SemVer](https://semver.org/).

## [Unreleased]

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
