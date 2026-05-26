# Failure Modes Cheatsheet

Every failure mode below has been seen in real production runs. The fixes work.

For deeper context, `docs/01-playbook.md §14` covers the same ground with more prose.

---

## Loop / iteration failures

### Agent stuck in a fix loop, same error each attempt
**Cause:** The error is in a file not listed in the codebase context — the agent can't find it.
**Fix:** Add the file (and its imports/types) to `CODEBASE_CONTEXT`. Re-run only the failed task.

### Agent "fixes" by deleting tests
**Cause:** Weak prompt rules.
**Fix:** Runner prompts already say "Do NOT delete or weaken tests." If still happening, add a task-specific MUST NOT rule, and grep the diff in the morning for `it.skip\|test.skip\|xit\|xtest`.

### Rate-limit 429 errors
**Cause:** Calls too fast.
**Fix:** Increase `COOLDOWN_SECONDS`. The `call_claude()` wrapper retries with 15s backoff; raise that if needed.

### Iteration limit hit mid-task
**Cause:** `MAX_ITERATIONS` < `NUM_TASKS × (1 + MAX_FIX_ATTEMPTS + 2)`.
**Fix:** Use the formula. For overnight runs, default to `MAX_ITERATIONS = 200`, `MAX_FIX_ATTEMPTS = 7`.

### Agent breaks a previous task
**Cause:** Hidden dependency between tasks.
**Fix:** The full test suite runs on every validation, so the fix loop usually catches it. If this happens often, your tasks are too coupled — restructure.

### Stale codebase context
**Cause:** You added new files but didn't update the heredoc.
**Fix:** Re-run exploration before each major run. Treat the context like a config file, not a one-time write.

---

## Chrome / browser failures

### Chrome extension not connected
**Symptom:** MCP tool errors at start of Phase 3.
**Fix:** Open Chrome, verify [Claude-in-Chrome](https://chromewebstore.google.com/) extension shows "Connected" status. Don't close Chrome during the run.

### Dev server crashes mid-run
**Symptom:** Chrome tests fail with "connection refused" after working earlier.
**Cause:** A code change introduced a build error that crashed the dev server.
**Fix:** Runner auto-detects + restarts. If it keeps crashing, the issue is a build-time error → check `.agent-logs/dev-server.log`.

### Auth wall blocks Chrome testing
**Symptom:** Chrome sees a login page instead of the app.
**Fix:** Log into the app in Chrome **before** launching. Session cookies persist across tabs. For long runs, enable a demo bypass mode if your app has one.

### Chrome always says PASS even when broken
**Symptom:** Obvious visual bugs but Phase 3 reports PASS.
**Cause:** Verdict prompt too lenient, or feature isn't visible in the a11y tree (animations, canvas, WebGL).
**Fix:** This is why screenshots and GIFs exist. Review them manually in the morning for visual-heavy features.

---

## Git / PR failures (Bulletproof mode)

### Branch creation fails
**Cause:** `BASE_BRANCH` has uncommitted changes.
**Fix:** Commit or stash before launch. The script refuses to start dirty.

### Push fails — protected branch
**Cause:** `BASE_BRANCH` is `main` with branch protection requiring PRs only.
**Fix:** Use `--branch nightshift/feat-x` to push to a different remote name. Bulletproof never pushes to `BASE_BRANCH` directly — only to `NIGHTSHIFT_BRANCH`.

### `gh pr create` fails
**Cause:** `gh` not authenticated, or no remote configured.
**Fix:** `gh auth login` and `git remote -v` to verify. Token needs `repo` scope.

### PR review loop fetches 0 comments
**Cause:** `GITHUB_REPO` config is wrong.
**Fix:** Set it to exactly `owner/repo` matching `gh api repos/{GITHUB_REPO}` success.

### Comments fetched but no reply posted
**Cause:** GitHub token missing `repo` write scope.
**Fix:** `gh auth refresh -s repo`.

### Per-step commit is empty
**Cause:** Step had no effect (already done, or agent reasoned no-op).
**Fix:** Script skips empty commits and logs to summary. Re-run only that step manually if you suspect it was wrongly skipped.

---

## Validation gate failures

### Prettier reformats everything every run
**Cause:** Project's prettier config drifted from what's checked in.
**Fix:** Commit the result of `npx prettier --write .` once before launching. Then the gate should be a no-op on clean code.

### tsc passes locally but fails in the runner
**Cause:** Local `tsconfig.json` includes paths the runner doesn't (e.g. test fixtures).
**Fix:** Run `npx tsc --noEmit` manually first. If clean locally, the runner is using the same config — read the runner's log for the diff.

### Tests pass locally but fail in the runner
**Cause:** Test order, hidden state from prior runs, or env vars not loaded by the runner.
**Fix:** Inspect `.agent-logs/validation-*.log`. The first failing test is usually a flake; the second is a real bug.

### Build step is the slow part (3+ min)
**Cause:** Full Next.js / Vite build per task.
**Fix:** Remove `bun run build` from `run_full_validation()` unless you specifically need build-time error catching. Keep it only in Bulletproof for production hardening runs.

---

## Logs to check, in order

When something goes wrong:

1. `.agent-logs/nightshift-summary.log` (or `bulletproof-summary.log`) — one-line-per-event timeline
2. `.agent-logs/task-{N}.log` — full Claude output for the failing task
3. `.agent-logs/validation-task-{N}-attempt-{M}.log` — exact validation errors per fix attempt
4. `.agent-logs/chrome-task-{N}.log` — Chrome agent transcript per task
5. `.agent-logs/dev-server.log` — Next.js / framework dev server output
6. `.agent-logs/screenshots/` — visual evidence

The summary log is usually enough to figure out which file to read next.
