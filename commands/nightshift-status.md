---
description: Check status of a running nightshift (is it alive? what's it on?)
---

The user wants to know what their nightshift is doing right now.

1. **Check liveness:**
   ```bash
   ./start-nightshift.sh status
   ```
   Or directly:
   ```bash
   ps -p $(cat .agent-logs/runner.pid 2>/dev/null) 2>&1
   ```

2. **Latest events** (last 20 lines of summary):
   ```bash
   tail -20 .agent-logs/nightshift-summary.log
   ```

3. **Current task progress** — find the most recent `STARTED:` line without a matching `COMPLETED:` / `FAILED:` line. That's the in-flight task. Show its task number and name.

4. **Iteration budget:**
   ```bash
   cat .claude_iterations
   ```
   Compare to `MAX_ITERATIONS` in the runner script. Warn if >80% used and many tasks remain.

5. **Last Claude output** — find the latest `.agent-logs/task-{N}.log` and tail it. If it's been idle (no new output for >5 min), the runner may be stuck in a Claude API call.

6. **Report:**
   ```
   Status: running (PID X) / not running
   Current: Task N — {name} (started {time})
   Progress: M/T tasks complete, K failed, J review-flagged
   Iterations: U/MAX (P%)
   ETA: ~X min based on average task time
   ```

If `not running` and tasks remain incomplete: check for crash. Read `.agent-logs/stdout.log` final 50 lines. Common causes: iteration limit, rate-limit exhaustion, `claude` CLI auth expired.
