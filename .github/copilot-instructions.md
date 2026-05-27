# GitHub Copilot Instructions

This is `autonomous-agent-nightshift` — a Claude Code skill + bash harness + npm CLI for running AI agents overnight on user codebases.

## Style

- **No emojis.** Anywhere. Period.
- **Terse.** No fluff in docs or commit messages.
- **Plain American English.**
- Bash 4+ with `#!/usr/bin/env bash` shebangs.
- `set -euo pipefail` in every script.

## Conventions

- Skill triggers come from `SKILL.md` frontmatter description (keep 150-1000 chars, include `NOT for:`).
- Slash commands live in `commands/*.md`, registered in `.claude-plugin/plugin.json`.
- Scripts must pass `shellcheck -S warning`.
- Cross-platform: use `perl -i -pe` not `sed -i ''`.
- No new bash deps beyond `claude`, `gh`, `git`, `bash`.

## Files

- `CLAUDE.md` — full agent working instructions
- `AGENTS.md` — multi-agent coordination
- `.cursorrules` — Cursor-specific
- `docs/01-playbook.md` — 47KB master guide

When suggesting code: respect the bash-first ethos, no emoji, semver-aware. When unsure, read `CLAUDE.md`.
