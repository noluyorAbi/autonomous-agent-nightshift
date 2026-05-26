# Cost and Safety

Nightshift is a power tool. Before launching one, know what it costs and what it can do to your system.

---

## Cost

Nightshift drives the `claude` CLI in a loop. Every iteration is a paid Claude API call.

### Rough math

| Item | Estimate |
|------|----------|
| One Claude call (Implementation phase, ~30K tokens in, ~5K out) | ~$0.20–0.40 (Sonnet) · ~$0.50–1.00 (Opus) |
| One Claude call (Fix phase, similar size) | ~$0.20–0.40 |
| One Chrome QA pass (~20K in, ~3K out, lots of tool calls) | ~$0.15–0.30 |
| **Default overnight run** (200 iterations) | **~$40–80 (Sonnet) · ~$100–200 (Opus)** |
| **Bulletproof 100-step sweep** (500 iterations, more retries) | **~$100–200 (Sonnet) · ~$250–500 (Opus)** |

These are estimates. Real cost depends on:
- Codebase context heredoc size (it's resent every call — big context = expensive)
- How often tasks need fix attempts (every retry = full Claude call)
- Whether Chrome QA is enabled (each task = ~2× cost)
- Which model `claude` uses (default is configurable in your Claude Code settings)

### How to control cost

1. **Estimate before launch** — multiply your task count by ~$0.50 (Sonnet) or ~$1.50 (Opus) per task as a rule of thumb. If estimate exceeds your budget, cut tasks or lower fix attempts.
2. **Trim the codebase context** — every char in the heredoc is sent on every call. Drop files the agent never needs.
3. **Lower MAX_FIX_ATTEMPTS** — 3 instead of 7 cuts worst-case task cost in half.
4. **Skip Chrome for backend tasks** — `--skip-chrome` removes Phase 3 entirely (~30% savings).
5. **Use Sonnet, not Opus** — set in Claude Code settings or via `claude` CLI flags. Sonnet is ~3× cheaper.
6. **Run on a budget cap** — Anthropic Console lets you set spending limits per key.

### Cost is real and recoverable

If a nightshift goes wild (stuck in a fix loop, blasting retries) the iteration limit caps damage at `MAX_ITERATIONS × cost_per_call`. With defaults that's ~$80 worst case. Always set this. Never run with `MAX_ITERATIONS=unbounded`.

---

## Safety

Nightshift runs **detached and unsupervised**. By design, the agent can:

| Capability | Risk |
|------------|------|
| Read every file in your repo | Could exfiltrate via the next `claude` call (low risk — Anthropic doesn't train on API data, but treat secrets accordingly) |
| Edit any file the user has write access to | A bad task can break your project — keep work uncommitted |
| Run shell commands via the runner script (prettier, tsc, tests, build) | These are the validation gate, but they run your project's scripts which can do anything |
| Create branches (Bulletproof) | `git checkout -b`, fine |
| Push branches to GitHub (Bulletproof) | Pushes to `NIGHTSHIFT_BRANCH`, not `main`. Branch protection on `main` is recommended. |
| Open and edit PRs (Bulletproof) | `gh pr create` and `gh api ... comments` — uses your `gh` token's scopes |
| Reply to PR comments (Bulletproof) | Posts as your GitHub user |
| Spend money on Claude API calls | Costs above |

### Pre-launch checklist (safety)

Before launching, confirm:

- [ ] **Repo is committed.** The agent will modify files. If you have uncommitted work you care about, commit or stash first.
- [ ] **Working branch is not `main`.** Either work on a feature branch yourself, or use Bulletproof which creates its own branch.
- [ ] **Branch protection on `main`.** Bulletproof creates a separate branch, but mistakes happen. Protect `main` via GitHub Settings → Branches.
- [ ] **`.env` and secrets are in `.gitignore`.** The agent reads your codebase. Don't commit secrets it might decide to "fix" or reference.
- [ ] **`gh` token scope is minimal.** Bulletproof needs `repo` for PR comment replies. If you don't need PR comment healing, use `--skip-pr` to scope down.
- [ ] **Test runner isolation.** If your tests touch external services (real DBs, real APIs, real email providers), nightshift will hit them every fix attempt. Mock or sandbox them.
- [ ] **Cost cap.** Set spending limits in Anthropic Console.
- [ ] **No production credentials in `.env.local`.** The agent reads project context. If a task drifts and writes test data through prod creds, that's bad.

### Permission prompts

The `claude` CLI may prompt for permission on certain tool uses (file writes, bash commands). In a detached overnight run, prompts cause the loop to hang waiting for input.

Options:

**A. Use `--dangerously-skip-permissions`** (advanced): Allow all tool uses without prompting. Only use in isolated environments (containers, sandboxes, VMs) — never on your main dev machine without thought.

```bash
# Inside run_agent_loop.sh, change:
claude -p "$prompt"
# To:
claude --dangerously-skip-permissions -p "$prompt"
```

**B. Pre-approve common operations** via `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(npx prettier:*)",
      "Bash(npx tsc:*)",
      "Bash(npx eslint:*)",
      "Bash(bun test:*)",
      "Bash(bun run build:*)",
      "Write(src/**)",
      "Edit(src/**)"
    ]
  }
}
```

This grants the agent silent permission for these specific operations. Tighter than `--dangerously-skip-permissions`.

### Disaster recovery

If a run goes off the rails:

```bash
# Immediate stop
./start-nightshift.sh stop

# Inspect uncommitted damage
git status
git diff

# Nuclear: revert everything since launch
git restore --staged .
git restore .
git clean -fd          # WARNING: deletes untracked files

# Bulletproof — branch had committed work
git branch -D nightshift/bulletproof-2026-05-27   # delete the local branch
git push origin --delete nightshift/bulletproof-2026-05-27   # delete remote
```

Always inspect `git diff` before committing the agent's work. Even validated tasks can contain subtly wrong implementations that pass tests but fail the actual intent.

---

## TL;DR

- Budget ~$50–200 per overnight run depending on size and model
- Always set `MAX_ITERATIONS` (worst-case cost cap)
- Commit your uncommitted work before launch
- Protect `main` branch via GitHub
- Use a minimal-scope `gh` token
- Set Anthropic spending limits
- Review the diff before committing the agent's work
