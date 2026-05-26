---
description: Review results from a completed nightshift run
---

The user is reviewing a nightshift run. Follow `SKILL.md` Workflow 2:

1. **Read the summary log:**
   ```bash
   cat .agent-logs/nightshift-summary.log
   ```
   Identify: completed-first-try, completed-after-fixes, FAILED, CHROME REVIEW NEEDED. Note total runtime + iterations used.

2. **Find manual-review tasks:**
   ```bash
   grep 'NEEDS MANUAL REVIEW' todo-*.md
   grep 'CHROME REVIEW NEEDED' todo-*.md
   ```
   For each, read the task body + `.agent-logs/task-{N}.log` to understand why.

3. **Surface the diff:**
   ```bash
   git diff --stat
   ```
   Summarize by area: routes, components, tests, configs.

4. **Spot-check visual evidence** (if Chrome testing ran):
   ```bash
   ls .agent-logs/screenshots/
   ```
   For each REVIEW-flagged UI task, open the screenshot/GIF and report what you see.

5. **Produce structured report:**
   ```
   Completed: N tasks (M first-try, K with fixes)
   Failed: N — [list with file:line of issue]
   Chrome review needed: N — [list]
   Diff: +X / -Y across Z files
   Next steps:
     1. Verify [task N] manually — [why]
     2. Run baseline checks
     3. Commit accepted work: git add -p && git commit
   ```

**Do NOT auto-commit.** The human stages and commits.
