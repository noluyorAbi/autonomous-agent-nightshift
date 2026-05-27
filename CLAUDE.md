# CLAUDE.md — Working in this repo

This file is read by Claude Code (and other coding agents) when working inside `autonomous-agent-nightshift`. It explains what the project is, how it's organized, and the conventions you must follow when editing it.

---

## What this project is

`autonomous-agent-nightshift` is **itself a Claude Code skill + plugin + CLI tool**. It teaches Claude (the runtime, including you right now) how to run multi-task autonomous batches overnight on a user's codebase. The repo ships:

- A skill manifest (`SKILL.md`) that triggers on nightshift-related phrases
- Six slash commands (`commands/`) for setup, status, review, resume, debug, bulletproof
- A bash harness (`scripts/`) that drives `claude -p` in a validation-gated loop
- Templates, examples, and a 47KB playbook in `docs/`
- A unified CLI (`bin/nightshift`) installable via npm/Homebrew/curl/tarball
- A static landing site (`site/`) deployed to GitHub Pages

You may be editing any of these layers. Know which one you're touching and respect its conventions.

---

## File map

```
SKILL.md                     Claude Code skill manifest (read by all agents)
CLAUDE.md                    This file — agent working instructions
AGENTS.md                    Multi-agent coordination notes
.claude-plugin/
  plugin.json                Plugin manifest (skill + 6 commands)
  marketplace.json           Marketplace manifest (for `/plugin marketplace add`)

bin/
  nightshift                 Unified CLI entry, dispatches subcommands
  install.sh                 curl one-liner installer

commands/                    Slash command definitions (each .md = one command)
  nightshift-setup.md
  nightshift-status.md
  nightshift-review.md
  nightshift-resume.md
  nightshift-debug.md
  nightshift-bulletproof.md

scripts/
  run-agent-loop.sh          Classic runner (no git)
  nightshift-bulletproof.sh  Branch + commit per step + PR variant
  start-nightshift.sh        start/stop/status/tail wrapper
  test-nightshift.sh         Recursive validation loop (no Claude)

templates/                   Blank skeletons users copy into their projects
  todo-template.md
  codebase-context.md
  qa-checklist-template.md
  runner-config.env

examples/                    Reference artifacts (sanitized real or synthetic)
  todo-simple-example.md
  bulletproof-steps-example.md
  qa-checklist-saas.md
  bulletproof-summary.log

docs/                        Long-form documentation
  01-playbook.md             Master guide (47 KB) — the canonical reference
  02-bulletproof-mode.md
  03-chrome-testing.md
  04-qa-checklist.md
  05-failure-modes.md
  06-test-loop.md
  07-cost-and-safety.md
  FAQ.md

site/                        Static landing page (Vite + React)
  src/                       React app source
  index.html                 Vite entry

.github/
  workflows/lint.yml         CI: shellcheck, markdownlint, JSON validation, frontmatter check
  workflows/release.yml      On tag push: build tarball, attach to GitHub release
  workflows/deploy-site.yml  On site/ change: deploy to GitHub Pages
  ISSUE_TEMPLATE/            Bug, stack-adapter request

package.json                 npm CLI package config
Formula/nightshift.rb        Homebrew formula
```

---

## Conventions (must follow)

### Style
- **No emojis in code, docs, scripts, or markdown.** Anywhere. Visual emphasis = formatting (bold, headings, callouts), not emoji.
- **Caveman doc style in user-facing copy where appropriate.** Drop articles, filler, hedging when terseness aids readability. Keep precision.
- **Plain American English.** No corporate fluff.
- **HTML in markdown is OK** for landing-page-style README structure. Most docs stay pure markdown.

### Code
- **Bash 4+ compat.** Use `#!/usr/bin/env bash` (not `#!/bin/bash` — macOS ships 3.2 there).
- **`set -euo pipefail`** at the top of every script.
- **`shellcheck` clean** at severity `warning`. CI enforces this.
- **`: > "$f"`** for truncation, not `> "$f"` (SC2188).
- **Cross-platform sed:** prefer `perl -i -pe` or runtime OS detection over `sed -i ''` (BSD-only).
- **No `npx`, no Node deps in the bash scripts.** Self-contained except `claude`, `gh`, `git`.

### Docs
- **Implementation+Validation pattern** is the project's core teaching. Every example task in docs must follow it.
- **No emoji in docs.** Section dividers use `---` or `<hr>`.
- **Cross-reference paths.** Use `path/to/file.md` not just `file.md`.
- **Examples in `examples/` are reference artifacts** — never templates. Users copy from `templates/` instead.

### Scripts
- **Idempotent where possible.** Re-running `nightshift init` should warn, not overwrite.
- **Cost-cap awareness.** Any new feature that calls `claude -p` MUST respect `MAX_ITERATIONS` and document estimated cost impact.
- **No `--dangerously-skip-permissions` in default scripts.** Document it as an opt-in for advanced users.

### Skill manifest (`SKILL.md`)
- **Description is the trigger surface.** Keep it specific. Include `NOT for:` clause to prevent over-triggering.
- **Description length 150-1000 chars.** CI enforces. Real Anthropic skills land 200-600 typically.
- **Don't duplicate playbook content in SKILL.md.** Reference `docs/01-playbook.md` instead.

### Slash commands (`commands/*.md`)
- **Frontmatter requires `description:` only.** Name derives from filename.
- **Body is a workflow instruction document.** Should reference SKILL.md, not duplicate it.
- **Always include "Don't auto-commit" reminders** where applicable.

### Versioning
- **Semver.** Patch = bugfix. Minor = new commands/features. Major = breaking install paths or runner contract changes.
- **CHANGELOG.md updated for every release.** Include "Why this release" section so context survives.
- **Tag releases as `vX.Y.Z`.** The `.github/workflows/release.yml` builds tarball on tag.

---

## When making changes

### Adding a new slash command
1. Create `commands/nightshift-{name}.md` with `description:` frontmatter and workflow body
2. Add entry to `.claude-plugin/plugin.json` `commands` array
3. Add entry to `bin/install.sh` post-install hint list
4. Add entry to `bin/nightshift` `cmd_help()` if user-facing
5. Update README slash-commands table
6. Update CHANGELOG

### Adding a new doc
1. Create `docs/NN-topic.md` (next sequential number)
2. Update README repo-layout block
3. Update site (if structure changed)
4. Cross-link from related docs

### Adding a new stack adapter
1. Add `run_full_validation()` snippet to `docs/01-playbook.md` §13
2. Add corresponding `CODEBASE_CONTEXT` example to §11
3. Update `templates/codebase-context.md` if patterns differ
4. Don't add a new script file — the existing runners are stack-agnostic

### Updating skill description
1. Edit SKILL.md frontmatter
2. Run `wc -c` — must be 150-1000 chars
3. CI workflow will validate on push

### Touching scripts
1. Run `shellcheck -S warning` locally before commit
2. Test idempotency by running twice
3. Check macOS BSD sed vs Linux GNU sed compatibility

---

## What NOT to do

- **Don't add features that require new dependencies.** The skill must work with just `bash`, `claude`, `gh`, `git`.
- **Don't add tracking, telemetry, or phone-home behavior.** The user's codebase is private. We don't see it.
- **Don't add prompts for the user inside the runner loop.** The runner is detached overnight — prompts hang.
- **Don't bundle the user's API key anywhere.** `claude` CLI manages auth.
- **Don't auto-commit changes the agent makes.** Classic runner never commits. Bulletproof commits to a dedicated branch only.
- **Don't write to `~` outside of `~/.claude/skills/` and `.agent-logs/`.**
- **Don't suppress validation errors.** A failed task should be visible, not hidden.
- **Don't add emoji.** (Yes, this rule is listed twice. That's intentional.)

---

## Working on the site

The site (`site/`) is a Vite + React project deployed to GitHub Pages via `.github/workflows/deploy-site.yml`. Conventions:

- **Content comes from canonical source.** README, docs/*.md, commands/*.md, SKILL.md are the source of truth. Site renders them, never re-authors them.
- **No CSS-in-JS heavy frameworks.** Tailwind utility classes only.
- **Playful but not childish.** Animations welcome (Framer Motion), but maintain the technical aesthetic.
- **Dark theme primary.** Light theme is nice-to-have, not required.
- **No emojis.** (Third reminder.)

When the canonical source changes (e.g., a new slash command added to `commands/`), run `scripts/agent-sync-site.sh` to update the site's content imports.

---

## Testing your changes

```bash
# Lint scripts
shellcheck -S warning scripts/*.sh bin/nightshift

# Lint markdown
npx markdownlint-cli2 "**/*.md" "#node_modules" "#examples"

# Validate plugin.json + marketplace.json
python3 -m json.tool .claude-plugin/plugin.json > /dev/null
python3 -m json.tool .claude-plugin/marketplace.json > /dev/null

# Smoke-test the CLI
./bin/nightshift version
./bin/nightshift help

# Smoke-test init flow in a tmp dir
TMP=$(mktemp -d) && cd "$TMP" && /path/to/repo/bin/nightshift init test
ls -la
cd / && rm -rf "$TMP"

# Local site preview
cd site && npm install && npm run dev
```

---

## When you're unsure

Read in this order:

1. `docs/01-playbook.md` — the canonical reference for everything
2. `SKILL.md` — what the skill promises to do
3. This file (`CLAUDE.md`) — how to work on the repo itself
4. `docs/07-cost-and-safety.md` — what the runner is allowed/expected to do
5. `examples/*` — what real artifacts look like

If still unsure, **ask the human**. Don't guess at intent — the cost of a bad guess in a tool that spends real money is high.
