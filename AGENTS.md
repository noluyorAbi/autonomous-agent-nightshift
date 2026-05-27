# AGENTS.md — Multi-agent coordination

This repo is itself an agent harness, and is also worked on by agents. This file describes how agents working inside this repo should coordinate with each other and with the human maintainer.

For single-agent context (Claude Code, Cursor, etc.), see [CLAUDE.md](./CLAUDE.md).

---

## Agent roles you might play

When invoked inside this repo, you are operating in one of these modes. Identify which before acting.

### 1. Maintainer mode (default)

You are editing the repo to ship a new version: adding features, fixing bugs, polishing docs, sanitizing examples. **Follow CLAUDE.md conventions strictly.** Update CHANGELOG.md for every user-visible change. Tag releases as `vX.Y.Z`.

### 2. User-helper mode (skill invocation)

A user has installed nightshift as a skill and asked you for help. You are NOT editing this repo — you are guiding the user through `/nightshift-setup`, `/nightshift-review`, etc. on **their** project. Read the relevant `commands/*.md` for the workflow. Never modify files inside this repo while in user-helper mode.

### 3. Site-sync mode

You are running `scripts/agent-sync-site.sh` or equivalent: reading canonical source (SKILL.md, commands/, package.json) and updating `site/src/content/*.ts` derived files. Do not author new content — only sync existing content shapes.

### 4. Self-improving mode

You are running nightshift **on itself**. The `todo-*.md` lives in this repo and describes improvements to nightshift's own scripts/docs/site. Treat carefully: any change to `scripts/run-agent-loop.sh` immediately affects future nightshift runs. Test changes in a tmp dir before committing.

---

## Coordination with other agents

If you discover that another agent (or a previous Claude session) made changes you disagree with:

1. **Read the commit message** to understand intent.
2. **Don't revert silently.** Revert + explain in your commit message, or open a discussion issue.
3. **CHANGELOG.md is the conversation.** Earlier entries are decisions, not suggestions.

If multiple agents are working in parallel (e.g., one on docs, one on scripts):

- **File-level isolation.** One agent per file at a time.
- **Don't touch SKILL.md or `.claude-plugin/*.json` unless your scope explicitly requires it.** They're shared contracts.
- **CHANGELOG.md is append-only** — multiple agents adding their changes should use `[Unreleased]` and merge cleanly.

---

## Talking to other agents

This repo's slash commands (`commands/nightshift-*.md`) are themselves agent instructions. When you spawn a sub-agent (via `Agent` tool or `claude -p` in scripts), give it:

- **The exact slash command's workflow** if applicable
- **A specific, bounded task** with verification criteria
- **Read-only access by default** — explicit write permission only if needed

Don't spawn agents to do work you should be doing yourself in the current turn.

---

## Tool authority (what agents may and may not do)

| Action | Authority |
|--------|-----------|
| Read any file in repo | Free |
| Edit existing file in scope | Free |
| Create new file in scope | Free |
| Delete file | Require human confirmation unless trivially derivable |
| `git add` / `git commit` | Free (the human asked for the work) |
| `git push` | Free for branches, **require confirmation for main when destructive** |
| `git push --force` | **Require explicit confirmation** |
| `gh release create` | Free if version + notes are confirmed |
| `gh release delete` | Require confirmation |
| `npm publish` | **Require explicit confirmation + OTP from user** |
| `gh repo edit --visibility` | **Require explicit confirmation** |
| Modify CI workflows | Free, but security-review them (no untrusted-input interpolation) |
| Modify `.github/workflows/release.yml` | Free, but verify on next tag push |
| Modify `package.json` `version` field | Free — that's how releases work |
| Add new dependencies to `package.json` | **Require justification** (this is a bash project; deps should be minimal) |
| Run nightshift in this repo (recursive) | Free for dry-run; require confirmation for actual `claude -p` calls |

---

## Reading the human

The human maintainer (`noluyorAbi`) has demonstrated these preferences in past sessions:

- **No emojis.** Anywhere. Multiple reminders confirm this is strict.
- **Caveman/terse communication style** when asked. Drop fluff. Keep substance.
- **Honest verdicts.** "It mostly works but X is broken" beats "it's perfect".
- **Cost-conscious.** Always surface cost implications of new features.
- **Ship-oriented.** Tag releases, push to public, multiple install channels.
- **Security-aware.** Sanitization before public flip, secret handling, branch protection.
- **Multi-language comfort.** German and English mixed. Don't translate idioms.

When in doubt, **be terse and verify before committing to risky actions** (publish, force-push, visibility flips).

---

## When you're spawned for a specific task

A user might invoke you via:

- `/nightshift-setup` → you are running [`commands/nightshift-setup.md`](./commands/nightshift-setup.md) on their project, NOT this repo
- `/nightshift-debug` → you are triaging a failed task in their project
- A direct prompt to edit this repo → you are in **Maintainer mode**

Always identify which mode before acting. The first sentence of your response should make it clear.

---

## What to ignore from past context

If you have memory or prior context suggesting:

- This repo is private (it became public at v1.3.0)
- It has fewer than 6 slash commands (it has 6 as of v1.4.0)
- The CLI is bash-only (it is, but `bin/nightshift` is the unified entry)
- The site is single-file HTML (was at v1.4.0; v1.5.0+ is Vite + React)
- Anthropic marketplace listing is documented but unimplemented (still true unless changed)

Trust the live files, not your memory.

---

## Provenance

This file follows the emerging [AGENTS.md convention](https://agents.md) for multi-agent coordination in code repos. It's read by Claude Code, Cursor, Aider, OpenHands, Devin, and other coding agents that look for project-level coordination files.
