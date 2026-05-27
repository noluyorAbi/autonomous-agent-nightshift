# How to use autonomous-agent-nightshift

Three install paths, three ways to use. Pick one that matches how you work.

---

## Path A — Claude Code plugin (recommended for Claude Code users)

### Install

```
/plugin marketplace add noluyorAbi/autonomous-agent-nightshift
/plugin install autonomous-agent-nightshift
```

Then **fully quit and relaunch Claude Code.** Reload-window is not enough.

### Verify

```
/plugin list
```

`autonomous-agent-nightshift` must appear in the list.

### Use

Six slash commands available after restart:

```
/nightshift-setup        Walk through a new run on the current project
/nightshift-status       Is it running? What task?
/nightshift-review       Morning report after a completed run
/nightshift-resume       Diagnose and restart after a crash
/nightshift-debug        Triage a task that exhausted retries
/nightshift-bulletproof  Production hardening sweep with PR + review healing
```

Or natural language (the skill triggers on these phrases):

```
"Set up a nightshift to add dark mode to my project."
"Review last night's nightshift."
"Is my agent still running?"
"Bulletproof this codebase before launch."
```

---

## Path B — npm CLI (works without Claude Code)

### Install

```bash
npm install -g autonomous-agent-nightshift
```

### Verify

```bash
nightshift version
```

### Use

```bash
cd your-project

# Bootstrap
nightshift init add-dark-mode

# Edit the files it created:
#   todo-YYYY_MM_DD_add-dark-mode.md   <- write Implementation+Validation tasks
#   run-agent-loop.sh                    <- paste codebase context heredoc

# Launch
nightshift start
nightshift tail              # follow the summary log
nightshift ui                # interactive TUI (tasks, logs, status)

# Sleep

# Morning
nightshift status
nightshift review
git diff --stat
git add -p && git commit
```

### Update

```bash
nightshift update
```

Detects install channel and runs the matching update command. Auto-update notice fires every 24h if a newer version exists on npm (silence with `NIGHTSHIFT_NO_UPDATE_CHECK=1`).

---

## Path C — Pure bash harness (no Claude Code, no npm)

### Install

```bash
git clone https://github.com/noluyorAbi/autonomous-agent-nightshift /tmp/nightshift
cp /tmp/nightshift/scripts/run-agent-loop.sh ./
cp /tmp/nightshift/scripts/start-nightshift.sh ./
cp /tmp/nightshift/templates/todo-template.md ./todo-$(date +%Y_%m_%d)_my-feature.md
```

### Use

```bash
chmod +x run-agent-loop.sh start-nightshift.sh

# Edit todo-*.md  → add tasks with Implementation + Validation
# Edit run-agent-loop.sh → paste CODEBASE_CONTEXT, set run_full_validation()

./start-nightshift.sh start
./start-nightshift.sh tail
```

This path skips the skill/CLI niceties but uses the same battle-tested bash harness.

---

## Before your first run — checklist

- [ ] `claude` CLI installed and authenticated (`claude --version` works)
- [ ] Your project's test runner works clean (`npm test` or equivalent returns 0)
- [ ] You committed work you care about — the agent edits files
- [ ] You set `MAX_ITERATIONS` in `run-agent-loop.sh` (it's your worst-case cost cap)
- [ ] You set spending limits in Anthropic Console
- [ ] If using Chrome QA: Chrome open with [Claude-in-Chrome extension](https://chromewebstore.google.com/) showing "Connected"
- [ ] If using Bulletproof mode: `gh auth status` green, `gh auth refresh -s repo` ran

Cost: ~$0.50 per task (Sonnet), ~$1.50 (Opus). Default overnight run: $8–50. See [docs/07-cost-and-safety.md](./docs/07-cost-and-safety.md).

---

## Troubleshooting

### "I installed but I don't see the skill in Claude"

**Most common cause:** you ran `/plugin marketplace add` but not `/plugin install`. The marketplace just registers the repo as a source; `install` actually loads the plugin.

```
/plugin install autonomous-agent-nightshift
```

Then **fully quit Claude Code and relaunch.** Reload-window does not reload skills.

### `/plugin marketplace add` fails with "Marketplace file not found"

Your local marketplace cache is stale. Refresh:

```bash
cd ~/.claude/plugins/marketplaces/noluyorAbi-autonomous-agent-nightshift
git fetch origin && git reset --hard origin/main
```

Then retry `/plugin install` from inside Claude Code.

### `nightshift` command not found after `npm install -g`

```bash
# Check global bin path is on $PATH
npm config get prefix
echo $PATH
```

Add `$(npm config get prefix)/bin` to your PATH if missing.

### Slash commands don't appear

1. Verify `/plugin list` shows the plugin
2. Verify `~/.claude/plugins/marketplaces/noluyorAbi-autonomous-agent-nightshift/commands/` contains the 6 `.md` files
3. **Fully quit and relaunch** Claude Code (not just reload)

### "I see literal \033[1m in the help output"

You're on v1.4.0. Upgrade:

```bash
npm install -g autonomous-agent-nightshift@latest   # via npm
# OR
nightshift update                                    # via CLI
```

Fixed in v1.5.2.

### Agent costs too much

Set `MAX_ITERATIONS` lower in `run-agent-loop.sh`. Worst case cost = `MAX_ITERATIONS × ~$0.40/call`. Also set hard spending cap at https://console.anthropic.com.

### Tasks always fail validation

Your `run_full_validation()` function doesn't match your project's toolchain. Run each command manually first — if you can't run it, the agent can't either.

### Nightshift died overnight

```
/nightshift-resume
```

Or via CLI:

```bash
nightshift resume
```

The runner is inherently resumable. It always picks the first unchecked task on restart.

### Need more help

- [Master playbook](./docs/01-playbook.md) — full 47KB guide
- [FAQ](./docs/FAQ.md)
- [Failure modes cheatsheet](./docs/05-failure-modes.md)
- [Issues](https://github.com/noluyorAbi/autonomous-agent-nightshift/issues)
