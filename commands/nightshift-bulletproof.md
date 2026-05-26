---
description: Set up a Bulletproof production-hardening sweep (branch + commit per step + PR + review healing)
---

The user wants a production-hardening sweep. Follow `SKILL.md` Workflow 3:

1. **Audit + propose steps** — read the codebase, produce `BULLETPROOF-STEPS.md` organized by category. Common categories:
   1. Styling & Design System
   2. Performance (bundle, Core Web Vitals, image opt)
   3. Accessibility (ARIA, keyboard nav, contrast)
   4. Security headers + CSP
   5. Auth + session hardening
   6. Rate limiting + quota
   7. Error boundaries + observability
   8. SEO + meta
   9. Mobile + responsive
   10. Legal + compliance copy

   Each step must be atomic (one commit). Each has **Implementation** + **Validation**.

2. **Configure** — copy `scripts/nightshift-bulletproof.sh` to project root. Edit:
   ```bash
   PLAN_FILE="BULLETPROOF-STEPS.md"
   BASE_BRANCH="main"
   GITHUB_REPO="owner/repo"             # exact match
   PR_WAIT_MINUTES=20                    # how long to wait for review
   ```
   Paste codebase context. Pre-flight per `nightshift-setup` PLUS:
   - [ ] `gh auth status` green
   - [ ] `gh auth refresh -s repo` (token needs repo scope for PR comment replies)
   - [ ] Working tree clean (Bulletproof refuses to start dirty)

3. **Launch instructions** (don't launch yourself):
   ```bash
   chmod +x nightshift-bulletproof.sh
   nohup ./nightshift-bulletproof.sh > .agent-logs/stdout.log 2>&1 &
   ```

   Available filters:
   - `--from N --to M` — step range
   - `--category N` — whole category
   - `--skip-chrome` — no browser test
   - `--skip-pr` — don't open PR
   - `--dry-run` — parse only

4. **Explain the PR review loop** — after all steps complete and PR opens, Bulletproof polls for comments and self-heals each one with a commit + inline reply. The user wakes up to a PR with N+1 commits where initial feedback is already addressed.

Reference `examples/bulletproof-summary.log` for a real 100-step run timeline.
