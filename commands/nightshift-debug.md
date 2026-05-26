---
description: Diagnose a task that exhausted retries — find the root cause and propose a fix or task rewrite
---

A task hit MAX_FIX_ATTEMPTS and got marked `— NEEDS MANUAL REVIEW`. Walk through the logs and produce a diagnosis.

## Step 1: Identify the failed task

```bash
grep 'NEEDS MANUAL REVIEW' todo-*.md
```

Pick the one the user wants to debug. Note the task number (e.g. Task 7).

## Step 2: Read the task spec + full Claude transcript

```bash
# Task spec (from the todo file)
sed -n '/Task 7/,/Task 8/p' todo-*.md

# Full Claude transcript for that task (every prompt + response)
cat .agent-logs/task-7.log
```

Read both. Compare what the task asked for vs what Claude attempted.

## Step 3: Read every validation attempt

```bash
ls .agent-logs/validation-task-7-attempt-*.log
```

For each attempt, look at:
- Which validator failed (prettier / tsc / eslint / test)
- The exact error
- Whether the same error recurs across attempts (= agent stuck) or errors change (= agent thrashing)

## Step 4: Classify the failure

| Pattern | Diagnosis | Fix |
|---------|-----------|-----|
| Same tsc error every attempt, type from a file not in codebase context | Stale/incomplete codebase context | Add the missing file/type to the heredoc; rerun this task only |
| Each attempt fixes one error but introduces another | Task scope too large | Split into 2-3 subtasks |
| Test passes but the implementation is empty/stub | Validation criteria too weak | Rewrite validation as concrete assertion |
| Agent edited the test to make it pass | Prompt rule violation | Check task log for deleted/weakened assertions; rewrite the task with explicit MUST NOT |
| tsc error in a file the task shouldn't touch | Task instruction ambiguous about scope | Add "ONLY modify {file A, file B}" to Implementation |
| eslint error: `any` or `@ts-ignore` | Agent took the shortcut despite forbidden patterns | Reinforce in CODEBASE_CONTEXT conventions; rewrite task |
| Network/auth error in tests | Test setup is project-specific | Document in CODEBASE_CONTEXT how tests are sandboxed |
| Build error from a transitive dep | Missing dep info in codebase context | Add dep list to context |

## Step 5: Read the relevant code as it stands now

After failed attempts, the codebase may have partial changes. Determine the current state:

```bash
git diff HEAD                    # uncommitted partial work
git status                       # untracked files Claude created
```

Decide: revert and start clean, or keep partial work and surgically fix?

## Step 6: Propose one of three actions

**A. Rewrite the task** — if the task spec was the root cause (vague, scope creep, weak validation). Update todo-*.md with a tighter spec. Mark the original `- [x] ... — RETRIED with rewrite`. Add a new `- [ ] Task NN: ...` at the end with the rewritten spec.

**B. Fix the codebase context** — if the agent kept missing files/types/conventions. Update the heredoc in `run-agent-loop.sh`. Then re-run only this task by un-checking the box:

```bash
# Cross-platform (works on macOS BSD sed AND Linux GNU sed):
perl -i -pe 's/\[x\] \*\*Task 7:/[ ] **Task 7:/' todo-*.md
# Then manually remove the "— NEEDS MANUAL REVIEW" suffix from that line.
./start-nightshift.sh start    # runner will pick it up
```

**C. Do it yourself** — if the task requires judgment the agent can't make (e.g. UX decision, schema choice with business implications). Implement manually, commit, and mark the task `[x] — IMPLEMENTED MANUALLY` for honesty.

## Step 7: Document the failure

In `docs/05-failure-modes.md` (if it's a new pattern) add a one-line entry under "Validation gate failures" or "Loop / iteration failures". This makes the next run smarter.

## What NOT to do

- Don't increase `MAX_FIX_ATTEMPTS` to brute-force through. If 7 attempts didn't fix it, attempt 14 won't either.
- Don't disable validators to make a task pass. The validation gate is the contract.
- Don't mark a task `[x]` without verifying the work matches the spec. The summary log is honest about what failed — keep it that way.
