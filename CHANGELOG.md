# Changelog

All notable changes documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning follows [SemVer](https://semver.org/).

## [Unreleased]

### Added

- `USAGE.md` — consolidated how-to-use guide with three install paths (Claude Code plugin / npm CLI / pure bash) and a comprehensive troubleshooting section. Surfaces the "must run `/plugin install` AFTER `/plugin marketplace add`" gotcha that's been the most common cause of "I installed but don't see the skill".
- README install section now links to `USAGE.md` and clarifies the `/plugin install` + full restart requirement for plugin installs.
- `.github/workflows/npm-publish.yml` — auto-publish to npm on tag push. Requires `NPM_TOKEN` secret with "Bypass 2FA when publishing" enabled. Fails-safe (warns, doesn't fail) when secret is missing.
- Branch protection on `main` with 8 required status checks: ShellCheck, Markdownlint, JSON validation, SKILL.md frontmatter, CLI smoke test, npm pack dry-run, site build, CodeQL. No force-push, no deletion.

## [1.5.2] — 2026-05-28

### Added — auto-update notification + self-update command

- **`nightshift update`** subcommand. Detects install channel from `$ROOT` path (npm Cellar / Homebrew / `~/.claude/skills/` / `~/.claude/plugins/marketplaces/` / git clone) and runs the matching update command. Invalidates the update-check cache after running.
- **Daily update check** runs before every subcommand except `version`, `help`, `update`. Fetches latest from npm registry with 3s timeout, caches result in `$XDG_CACHE_HOME/nightshift/latest-version` (or `~/.cache/nightshift/`). If newer version exists, prints a one-line yellow notice to stderr. Fails silent on network errors.
- Pure-bash semver comparison (`version_lt`). No new dependencies. Skips check in non-interactive contexts (CI, pipes) via `[ -t 1 ]`. Disable via `NIGHTSHIFT_NO_UPDATE_CHECK=1`.

### Fixed (real bug reported via screenshot)

- **`bin/nightshift help` displayed literal `\033[1m` escape codes** instead of bold/colored text. Cause: single-quoted color variables (`BOLD='\033[1m'`) stay as literal 6-char strings; `cat <<EOF` heredoc does not interpret backslash escapes. Fix: ANSI-C quoting (`BOLD=$'\033[1m'`) so vars contain real ESC bytes that terminals interpret correctly.

### Why this release

Combined v1.5.1 (ANSI bug fix) with auto-update feature user requested. Bumping straight to 1.5.2 since v1.5.1 was tagged on GitHub but never published to npm.

## [1.5.1] — 2026-05-28

### Fixed (real bug reported via screenshot)

- **`bin/nightshift help` displayed literal `\033[1m` escape codes** instead of bold/colored text. Cause: color variables used single-quoted strings (`BOLD='\033[1m'`) which stay as literal 6-char strings; `cat <<EOF` heredoc does not interpret backslash escapes. Fix: ANSI-C quoting (`BOLD=$'\033[1m'`) so vars contain real ESC bytes that terminals interpret correctly.
- Affects: all CLI subcommands that print colored output via heredoc (help, version, init).

### Why this release

User screenshot showed `nightshift help` output with raw escape sequences instead of rendered colors. Real, visible regression in v1.4.0 and v1.5.0. Fixed.

## [1.5.0] — 2026-05-28

## [1.5.0] — 2026-05-28

### Added — Vite + React site with docs, onboarding, content sync

- **`site/`** — full rewrite from single-file HTML to Vite + React + Tailwind + Framer Motion SPA. Five pages: landing (`/`), install (`/install`), commands (`/commands`), onboarding (`/onboarding`), docs (`/docs/*` with sidebar nav).
- **Onboarding walkthrough** at `/onboarding` — 7-step interactive tutorial with progress bar, copyable commands per step, framer-motion transitions between steps. Goes from `npm install` to morning review.
- **Docs pages** at `/docs/*` — renders existing `docs/*.md` files via `react-markdown + remark-gfm` with `?raw` imports. 8 doc pages (playbook, bulletproof, chrome, qa-checklist, failure-modes, test-loop, cost-safety, FAQ) with a sticky sidebar.
- **`site/scripts/sync-content.ts`** — deterministic content-sync agent that reads canonical source (`package.json`, `commands/*.md`) and regenerates `site/src/content/*.ts`. No LLM calls — pure transformation. Referenced from CLAUDE.md and AGENTS.md.
- **`.github/workflows/deploy-site.yml`** updated — installs site deps, runs `npm run build` in `site/`, deploys `site/dist/` to GitHub Pages. Triggers on `site/`, `docs/`, `commands/`, `SKILL.md`, or `package.json` changes.

### Added — agentic context files

- **`CLAUDE.md`** — comprehensive working-in-this-repo guide for Claude Code. Project purpose, file map, conventions (no emojis, bash 4+, semver, etc.), when-to-modify-what, what NOT to do, testing/lint commands.
- **`AGENTS.md`** — multi-agent coordination notes. Roles (maintainer / user-helper / site-sync / self-improving), coordination protocols, tool authority table (what agents may + may not do without confirmation).
- **`.cursorrules`** — Cursor-specific tight summary of conventions.
- **`.github/copilot-instructions.md`** — GitHub Copilot context.

### Added — `.claude-plugin/marketplace.json`

- Required by `/plugin marketplace add` — previously missing, caused error: `Marketplace file not found at .../.claude-plugin/marketplace.json`. Now present, lists this repo as a single-plugin marketplace with metadata.

### Changed — repo metadata

- GitHub homepage URL → `https://www.npmjs.com/package/autonomous-agent-nightshift`
- Description tightened: added "npm CLI" mention, removed "real examples" tail (now sub-product of broader claim).
- Topics expanded: `claude-code-plugin`, `npm-package`, `cli`, `cli-tool`, `homebrew` added.

### Documentation

- Removed `site/index.html` (single-file static landing) — replaced by Vite app entry.

### Why this release

User asked for:
1. A more detailed, playful site with Vite + React, docs, and onboarding — to "sell the skill better"
2. An agent that updates the site based on the actual skill state
3. Agentic AI markdown files (CLAUDE.md, etc.)
4. Updated GitHub metadata
5. Fix for `/plugin marketplace add` error

All five delivered. Plugin marketplace is now functional. Site is a real React app with proper structure to grow into.

## [1.4.0] — 2026-05-27

## [1.4.0] — 2026-05-27

### Added — multi-channel distribution

- **`bin/nightshift`** — unified CLI dispatcher (bash). Subcommands: `init`, `bulletproof-init`, `start`, `stop`, `status`, `tail`, `review`, `resume`, `version`, `help`. Resolves install root regardless of channel (npm global, Homebrew Cellar, tarball, git clone, or skills dir). Symlink-aware (`while [ -L "$src" ]`).
- **`package.json`** — npm-installable. `npm install -g autonomous-agent-nightshift` ships the `nightshift` CLI. `npx autonomous-agent-nightshift init my-feature` for one-shot bootstrap.
- **`Formula/nightshift.rb`** — Homebrew formula. `brew install noluyorAbi/tap/nightshift` (when tap is published) or `brew install --HEAD` from raw URL today.
- **`.github/workflows/release.yml`** — on tag push, builds tarball + SHA256 and attaches to the GitHub Release. Enables `curl -L .../releases/latest/download/*.tar.gz | tar xz` install.
- **`.npmignore`** — keeps `.github/`, `.git/`, `Formula/`, dev artifacts out of the npm payload.

### Changed — README install matrix

- Install section restructured as a channel matrix table (npm / Homebrew / curl / plugin / tarball / git clone) with a "what each gives you" comparison (CLI vs skill vs slash commands).
- New `## CLI` section after Install showing `nightshift init / start / tail / status / review / resume / bulletproof-init`.

### Verified

- `bin/nightshift version` resolves install root correctly: ✓
- `bin/nightshift help` renders with colors when TTY, plain when piped: ✓
- `bin/nightshift init test-feature` in tmp dir: bootstraps todo + runner, sed-substitutes TODO_FILE, appends `.gitignore`: ✓ (tested on macOS BSD sed path)
- `bash -n bin/nightshift` syntax check: ✓

### Why this release

User asked: "make it run so I can download as skill, npm package, cli tool etc". v1.3 was install-as-skill-only. v1.4 ships **6 install channels** for the same underlying tool. CLI tool is the new primary user-facing artifact for non-Claude-Code users.

## [1.3.0] — 2026-05-27

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
