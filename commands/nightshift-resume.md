---
description: Resume a nightshift that died mid-run, starting from the last completed task
---

The user's nightshift stopped before completing all tasks. Help them resume cleanly.

## Step 1: Diagnose why it stopped

Run `./start-nightshift.sh status` and read the last 50 lines of `.agent-logs/stdout.log`. Identify the cause:

| Cause | Signal |
|-------|--------|
| Iteration limit hit | `Max iterations hit` in summary log; `.claude_iterations` ≥ MAX_ITERATIONS |
| Rate limit exhausted | `RATE LIMIT: Could not parse time` repeated |
| `claude` CLI auth expired | `claude: command not found` or auth errors |
| Manual stop | `Stopped PID X` in stdout |
| Crashed | Stack trace at end of stdout.log |
| Dev server crashed (Chrome runs) | `connection refused` to dev port |

## Step 2: Check resume readiness

```bash
# How many tasks are already done?
grep -c '^\- \[x\]' todo-*.md

# How many remain?
grep -c '^\- \[ \]' todo-*.md

# Any with REVIEW flags?
grep 'REVIEW' todo-*.md
```

The runner is **inherently resumable** — it always picks the first unchecked task. No state to clean up.

## Step 3: Fix the root cause first

**Iteration limit hit:**
```bash
# Edit run-agent-loop.sh, bump MAX_ITERATIONS.
# Formula: REMAINING_TASKS × (1 + MAX_FIX_ATTEMPTS + 2)
# Then reset the counter for fresh budget.
echo "0" > .claude_iterations
```

**Rate limit exhausted:** Wait the cooldown (check Anthropic dashboard). Bulletproof script auto-sleeps until reset; classic runner doesn't — bump `COOLDOWN_SECONDS=10` before resuming.

**Auth expired:** `claude /login` or check `~/.config/claude/`.

**Dev server crashed:** Tail `.agent-logs/dev-server.log` for the root build error. Fix it manually. Then resume.

**Manual stop / crash:** Determine if any partial work is uncommitted. The classic runner doesn't commit; Bulletproof commits per task. For Bulletproof:

```bash
git status                       # any half-staged changes?
git log --oneline -5             # last completed step's commit
```

If the last step started but didn't commit, its checkbox is still `[ ]` — the resume will retry it from scratch. That's fine.

## Step 4: Resume

```bash
# Classic
./start-nightshift.sh start

# Bulletproof
nohup ./nightshift-bulletproof.sh --from $(next_unchecked_step) > .agent-logs/stdout.log 2>&1 &
```

For Bulletproof `--from`, find the lowest unchecked step number:

```bash
grep '^### Step ' BULLETPROOF-STEPS.md | head -20    # see step numbers
grep -B1 '\- \[ \]' BULLETPROOF-STEPS.md | head -5   # see first unchecked
```

## Step 5: Monitor

```bash
./start-nightshift.sh tail
```

Verify the first resumed task picks up where it should — not re-running already-completed work.

## Common gotchas to warn about

- **Iteration counter** — `.claude_iterations` is monotonic across resumes unless you reset it. If you bumped `MAX_ITERATIONS` but didn't reset the counter, you may hit the limit again instantly.
- **Bulletproof branch** — resume uses the same `NIGHTSHIFT_BRANCH` from the original run (date-based default). If the date changed, override with `--branch nightshift/bulletproof-{original-date}`.
- **Dev server port** — if a process is still holding the port, kill it first: `lsof -ti:$DEV_PORT | xargs kill -9`.
- **Stale codebase context** — if you edited files between runs that the agent's context doesn't reflect, update the heredoc before resuming.
