# FAQ

## General

**Q: How is this different from just running `claude -p "build X"` in a loop?**
A: That's what nightshift is, with: a strict validation gate (lint, types, tests, build), a fix loop that retries failed validations, optional Chrome MCP browser testing for UI work, a Bulletproof PR-review loop, per-stack adapters, a parser that walks structured todo files, summary logging, iteration budget caps, rate-limit-aware backoff, and 6 slash commands for setup/review/resume/debug. Plus 47KB of playbook and real sanitized examples. The bash harness alone is ~1100 lines.

**Q: Does it work with Claude API (Anthropic SDK) or only Claude Code?**
A: Only Claude Code (the CLI). The runner calls `claude -p` directly. Adapting to the raw Anthropic API would mean rewriting the call path and losing tool access (file edits, bash, browser MCP).

**Q: Will it work on Windows?**
A: Bash scripts only. Use WSL2.

**Q: Linux vs macOS portability?**
A: Tested on macOS (BSD coreutils). Linux should work — the scripts use POSIX-friendly idioms and `/usr/bin/env bash`. One known gotcha was `sed -i ''` vs `sed -i` — fixed in v1.1.1. Report any other portability issues.

## Cost

**Q: How much does an overnight run cost?**
A: Rough rule: ~$0.50 per task with Sonnet, ~$1.50 with Opus. A 16-task default run = $8–25. A 100-step Bulletproof sweep = $100–500. See `docs/07-cost-and-safety.md` for detailed math.

**Q: Can it cost more than I expect?**
A: Yes if `MAX_ITERATIONS` is unbounded and tasks loop. Always set this. Worst-case cost = `MAX_ITERATIONS × ~$0.40`.

**Q: How do I set a hard spending limit?**
A: Anthropic Console → Workspaces → set a monthly spending cap. Nightshift can't go above what your API key allows.

## Setup

**Q: Do I need Chrome?**
A: Only for Phase 3 (visual verification of UI tasks). Pass `--skip-chrome` to the bulletproof script or remove Phase 3 from the classic runner. Backend-only runs don't need it.

**Q: Do I need the Claude-in-Chrome extension?**
A: Only for Phase 3. The runner detects when MCP tools are unavailable and skips Chrome.

**Q: Can I run multiple nightshifts in parallel?**
A: One per repo at a time. Two on the same repo would race on the todo file and git state. For multi-repo parallel, use different machines or sandboxed working copies.

**Q: Does it work on a remote server?**
A: Yes — the scripts use `nohup`/detached background processes by design. SSH in, launch, disconnect, SSH back in the morning. Chrome phase only works if Chrome is running on a machine you can reach (locally or via X forwarding); for remote runs you usually `--skip-chrome`.

## During the run

**Q: How do I check if it's still alive?**
A: `./start-nightshift.sh status` or use `/nightshift-status`.

**Q: How do I see what's happening right now?**
A: `./start-nightshift.sh tail` follows the summary log.

**Q: How do I stop it cleanly?**
A: `./start-nightshift.sh stop`. The runner finishes its current Claude call, then exits.

**Q: It's stuck on Task 7 with 5 fix attempts. Should I let it keep going?**
A: Probably not. Stop it, use `/nightshift-debug` to triage, and either rewrite the task or implement it manually. More retries rarely help when the first 5 didn't.

## Results

**Q: Will it commit code automatically?**
A: Classic mode: no. Bulletproof mode: yes, one commit per step, pushed to a dedicated branch (never `main`).

**Q: How do I roll back a Bulletproof run?**
A: `git checkout main && git branch -D nightshift/bulletproof-YYYY-MM-DD`. Remote branch: `git push origin --delete nightshift/bulletproof-YYYY-MM-DD`.

**Q: What if a task passes validation but the implementation is wrong?**
A: The QA checklist (`templates/qa-checklist-template.md`) is your safety net for this. Validation gates verify code compiles and passes existing tests. They don't verify the task's intent matches what got built. Review the diff.

**Q: What does "NEEDS MANUAL REVIEW" mean exactly?**
A: The runner exhausted `MAX_FIX_ATTEMPTS` trying to make validation pass. The task is marked `[x]` (loop moves on) but the suffix flags it for you. Use `/nightshift-debug` to triage.

**Q: What does "CHROME REVIEW NEEDED" mean?**
A: Code validation passed (lint, types, tests) but Chrome browser verification couldn't confirm the UI works. Common for animations, canvas, WebGL, or auth-walled routes. Check the screenshot/GIF in `.agent-logs/screenshots/`.

## Skill specific

**Q: The skill isn't triggering. Why?**
A: Check (1) the repo is in `~/.claude/skills/` or `.claude/skills/`, (2) `SKILL.md` exists at the repo root with valid frontmatter, (3) you've restarted Claude Code since installing, (4) your phrasing matches the trigger list ("nightshift", "autonomous agent", "overnight agent", etc — not "set up a coding loop").

**Q: Slash commands don't show up.**
A: `commands/*.md` files must have a frontmatter `description:` line. Restart Claude Code after install. Check `.claude-plugin/plugin.json` lists the command.

**Q: How do I uninstall?**
A: `rm -rf ~/.claude/skills/autonomous-agent-nightshift`. The skill and its slash commands disappear.

## Why these defaults?

**Q: Why `MAX_ITERATIONS=200`?**
A: 16 tasks × (1 implement + 7 fix retries + 2 buffer) = 160. Round up to 200 for headroom. If you have more tasks, use the formula in `docs/01-playbook.md`.

**Q: Why `MAX_FIX_ATTEMPTS=7`?**
A: Empirically: 1–2 attempts catches 60% of failures. 3–4 catches another 20%. 5–7 catches another 10%. Beyond 7, fix attempts stop helping (the agent is in a local minimum). 7 is the cost/benefit sweet spot for overnight runs.

**Q: Why `MAX_CHROME_FIX_ATTEMPTS=3`?**
A: Chrome failures are usually visual issues that need different reasoning than code failures. Three attempts catches most. Beyond that, escalate to human review.

**Q: Why port 31415 default in the classic runner?**
A: `π × 10000`. Avoids collision with common ports (3000, 8080). Override via `DEV_PORT`.
