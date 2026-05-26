# Bulletproof Mode — PR Loop with Self-Healing

`scripts/nightshift-bulletproof.sh` is the production-hardening variant of the basic runner. Where `run-agent-loop.sh` stops after marking checkboxes, Bulletproof goes further: it owns the whole branch lifecycle.

```
0.  Create dedicated branch from BASE_BRANCH, push it
1.  For each step in PLAN_FILE:
      a. Implement (Claude)
      b. Validate (lint, type-check, test, build)  — fix loop on fail
      c. Chrome test (live browser via MCP)         — fix loop on fail
      d. Commit (atomic, one commit per step)
2.  Open PR with detailed summary
3.  Wait PR_WAIT_MINUTES for human/CI review comments
4.  For each unresolved comment:
      a. Implement the fix
      b. Reply to the comment with what changed
5.  Push final state
```

The result of a successful run is a single PR with N+1 commits (one per step plus review fixes) that already addresses initial review feedback.

---

## Why a separate script?

`run-agent-loop.sh` is for **feature implementation**: you'll review the diff manually in the morning. It doesn't touch git.

`nightshift-bulletproof.sh` is for **scheduled hardening sweeps**: weekly security pass, accessibility cleanup, design-system migration, dependency upgrade. The goal is a clean PR sitting in review when you wake up.

| | Classic | Bulletproof |
|---|---------|-------------|
| Touches git? | No | Yes — per-step commits |
| Opens PR? | No | Yes |
| Addresses review comments? | No | Yes (waits PR_WAIT_MINUTES) |
| Parses todo file format | `- [ ] **Task N: ...**` | `Step N: ...` with category headers |
| Best for | Net-new features | Hardening, cleanup, migrations |

---

## Required configuration

The top of the script:

```bash
PLAN_FILE="BULLETPROOF-STEPS.md"   # Your numbered step plan
BASE_BRANCH="main"
NIGHTSHIFT_BRANCH="nightshift/bulletproof-$(date '+%Y-%m-%d')"
GITHUB_REPO="owner/repo"           # Required for PR review fetch
PR_WAIT_MINUTES=20

DEV_PORT=3000
DEV_URL="http://localhost:$DEV_PORT"

MAX_ITERATIONS=500
MAX_FIX_ATTEMPTS=7
MAX_CHROME_FIX_ATTEMPTS=3
```

And the `CODEBASE_CONTEXT` heredoc — fill from `templates/codebase-context.md`.

---

## Plan-file format (Bulletproof)

Bulletproof parses steps in a slightly different shape than the classic todo. Each step is a numbered heading with a category tag, and a body of implementation + validation notes:

```markdown
## Category 1 — Styling & Design System

### Step 1 — Create a skeleton/shimmer component library
**Implementation:** ...
**Validation:** ...

### Step 2 — Standardize spacing & typography scale
**Implementation:** ...
**Validation:** ...

## Category 2 — Performance

### Step 11 — Bundle size budget
**Implementation:** ...
**Validation:** ...
```

Filtering options:

```bash
./nightshift-bulletproof.sh --from 15 --to 30      # Steps 15-30
./nightshift-bulletproof.sh --category 1           # Whole category
./nightshift-bulletproof.sh --skip-chrome          # No browser test
./nightshift-bulletproof.sh --skip-pr              # Don't open PR
./nightshift-bulletproof.sh --dry-run              # Parse + list, no execute
./nightshift-bulletproof.sh --pr-wait 45           # Wait 45min for review
./nightshift-bulletproof.sh --branch nightshift/feat-x   # Override branch
```

---

## What gets committed per step

One atomic commit per step, message format:

```
nightshift(step-{N}): {step title}

{step body}

Validated: code ✓, chrome ✓
Branch: nightshift/bulletproof-{YYYY-MM-DD}
Step: {N}/{total}
```

Failed steps still commit, but with an annotated message:

```
nightshift(step-{N}): {step title} — NEEDS MANUAL REVIEW

Validated: code ✗ (7 fix attempts exhausted)
Last error excerpt: ...
```

This keeps the PR honest — reviewers see exactly which steps the agent struggled with.

---

## PR review loop

After all steps complete and the PR is open, the script polls `gh api repos/{GITHUB_REPO}/pulls/{N}/comments` and `/issues/{N}/comments` every minute for `PR_WAIT_MINUTES`. Any new comment becomes a fix task:

1. Claude reads the comment + the file/line it references
2. Implements the fix
3. Runs the validation gate
4. Replies to the comment with: "Fixed in commit `{sha}` — {what changed and why}"
5. Pushes

If the comment is purely a question (no code change requested), Claude replies inline without committing.

The loop terminates when:
- All comments are addressed, OR
- `PR_WAIT_MINUTES` elapses with no new comments, OR
- Iteration cap is hit

---

## Failure modes specific to Bulletproof

| Symptom | Cause | Fix |
|---------|-------|-----|
| Branch creation fails | `BASE_BRANCH` has uncommitted changes | Commit or stash before launch |
| Push fails — protected branch | You set `BASE_BRANCH` to main with branch protection | Use `--branch other/name` |
| `gh pr create` fails | `gh` not authenticated, or no remote | `gh auth login`; `git remote -v` |
| PR review loop fetches 0 comments | `GITHUB_REPO` is wrong | Double-check `owner/repo` exactly |
| Comments fetched but no reply posted | Token missing `repo` scope | `gh auth refresh -s repo` |
| Per-step commit is empty | Step had no effect (e.g. already done) | Script skips empty commits and logs |

---

## Morning review for Bulletproof runs

```bash
# Summary timeline
cat .agent-logs/bulletproof-summary.log

# Steps marked NEEDS MANUAL REVIEW
grep 'NEEDS MANUAL REVIEW' BULLETPROOF-STEPS.md

# Steps with CHROME REVIEW NEEDED
grep 'CHROME REVIEW NEEDED' BULLETPROOF-STEPS.md

# PR URL
gh pr view --json url --jq .url

# Per-step commits
git log --oneline ${BASE_BRANCH}..HEAD
```

See `examples/bulletproof-summary.log` for a real timeline from a 100-step run.
