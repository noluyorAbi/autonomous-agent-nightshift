<div align="center">

# Autonomous Agent Nightshift

<p>
  <strong>A Claude Code skill and bash harness for running AI agents overnight on your codebase.</strong><br>
  Write a todo file with Implementation+Validation pairs. Launch. Wake up to validated code &mdash; or a PR with review feedback already addressed.
</p>

<p>
  <a href="https://opensource.org/licenses/MIT"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg"></a>
  <a href="https://docs.claude.com/en/docs/claude-code/skills"><img alt="Claude Code Skill + Plugin" src="https://img.shields.io/badge/Claude%20Code-Skill%20%2B%20Plugin-orange"></a>
  <a href="https://github.com/noluyorAbi/autonomous-agent-nightshift/actions/workflows/lint.yml"><img alt="CI" src="https://github.com/noluyorAbi/autonomous-agent-nightshift/actions/workflows/lint.yml/badge.svg"></a>
  <a href="https://github.com/noluyorAbi/autonomous-agent-nightshift/releases"><img alt="Release" src="https://img.shields.io/github/v/release/noluyorAbi/autonomous-agent-nightshift"></a>
</p>

<sub>Distilled from production runs on multiple SaaS codebases (Next.js, Bun, Supabase, Stripe). Adapters documented for Python, Go, Rust.</sub>

</div>

<hr>

## How it works

<table>
<tr>
<td width="33%" align="center"><strong>Feature plan</strong><br><sub>todo file with checkboxes</sub><br><br>You write the WHAT.</td>
<td width="33%" align="center"><strong>Runner script</strong><br><sub>bash harness</sub><br><br>Orchestrates the loop.</td>
<td width="33%" align="center"><strong>Codebase context</strong><br><sub>embedded heredoc</sub><br><br>Where things live.</td>
</tr>
</table>

Per-task pipeline:

```
Phase 1: Implement   Claude writes code + tests
Phase 2: Validate    prettier . tsc . eslint . test runner
  -> Fix loop        up to MAX_FIX_ATTEMPTS (default 7)
Phase 3: Chrome      optional live browser test via Claude-in-Chrome MCP
  -> Fix loop        up to MAX_CHROME_FIX_ATTEMPTS (default 3)
Phase 4: Mark done   checkbox [x] in todo file
```

Failed tasks get `[x] -- NEEDS MANUAL REVIEW` and the loop moves on. You triage in the morning.

<hr>

## Install

> [!NOTE]
> **One-liner installer** clones this repo into your Claude Code skills directory. After install, restart Claude Code so it picks up the skill and slash commands.

```bash
curl -fsSL https://raw.githubusercontent.com/noluyorAbi/autonomous-agent-nightshift/main/bin/install.sh | bash
```

<details>
<summary><strong>Other install paths</strong></summary>

<br>

**Project-level** (only this project):
```bash
curl -fsSL https://raw.githubusercontent.com/noluyorAbi/autonomous-agent-nightshift/main/bin/install.sh | bash -s -- --project
```

**Manual skill install:**
```bash
git clone https://github.com/noluyorAbi/autonomous-agent-nightshift ~/.claude/skills/autonomous-agent-nightshift
```

**As a plugin** (custom marketplace):
```
/plugin marketplace add noluyorAbi/autonomous-agent-nightshift
/plugin install autonomous-agent-nightshift
```

**Bash-only** (no Claude Code skill, just scripts):
```bash
git clone https://github.com/noluyorAbi/autonomous-agent-nightshift /tmp/nightshift
cp /tmp/nightshift/scripts/run-agent-loop.sh ./
cp /tmp/nightshift/scripts/start-nightshift.sh ./
cp /tmp/nightshift/templates/todo-template.md ./todo-$(date +%Y_%m_%d)_my-feature.md
```

</details>

<hr>

## Slash commands

After install, six commands trigger directly inside Claude Code:

<table>
<tr><td><code>/nightshift-setup</code></td><td>Detect stack, write todo, generate context, configure runner, preflight, launch command.</td></tr>
<tr><td><code>/nightshift-status</code></td><td>Is it running? What task? Iteration budget? ETA?</td></tr>
<tr><td><code>/nightshift-review</code></td><td>Read logs, surface REVIEW-flagged tasks, summarize diff, produce morning report.</td></tr>
<tr><td><code>/nightshift-resume</code></td><td>Diagnose why a run stopped (iteration cap, rate limit, crash, auth, dev-server) and restart cleanly.</td></tr>
<tr><td><code>/nightshift-debug</code></td><td>A task exhausted retries. Classify the failure, propose rewrite / context-fix / manual implementation.</td></tr>
<tr><td><code>/nightshift-bulletproof</code></td><td>Production-hardening sweep with branch + commit per step + PR + review-comment healing.</td></tr>
</table>

Or talk naturally. The skill triggers on phrases like &ldquo;set up a nightshift&rdquo;, &ldquo;review last night's run&rdquo;, &ldquo;is my agent still running&rdquo;.

<hr>

## Cost and safety

> [!WARNING]
> **Nightshift spends real money on Claude API calls and modifies your codebase autonomously.** Read [`docs/07-cost-and-safety.md`](./docs/07-cost-and-safety.md) before launching your first run.

<table>
<tr><td><strong>Rough cost</strong></td><td>~$0.50 per task (Sonnet) &middot; ~$1.50 per task (Opus)</td></tr>
<tr><td><strong>Default overnight run</strong> (~16 tasks)</td><td>$8&ndash;25 (Sonnet) &middot; $25&ndash;50 (Opus)</td></tr>
<tr><td><strong>Bulletproof sweep</strong> (100 steps)</td><td>$100&ndash;200 (Sonnet) &middot; $250&ndash;500 (Opus)</td></tr>
</table>

Before launch:

- Commit any work you care about (the agent edits files)
- Set <code>MAX_ITERATIONS</code> &mdash; this cap <em>is</em> your worst-case cost cap
- Protect <code>main</code> via branch protection
- Set spending limits in Anthropic Console
- Review the diff in the morning before committing the agent's work

<hr>

## Two modes

<table>
<thead>
<tr><th width="20%">Mode</th><th width="35%">Script</th><th>Use case</th></tr>
</thead>
<tbody>
<tr>
  <td><strong>Classic</strong></td>
  <td><code>scripts/run-agent-loop.sh</code></td>
  <td>Feature implementation. Loops todo file, runs validation, optional Chrome browser test, marks checkboxes. <em>No git.</em> You review and commit in the morning.</td>
</tr>
<tr>
  <td><strong>Bulletproof</strong></td>
  <td><code>scripts/nightshift-bulletproof.sh</code></td>
  <td>Production hardening. Same loop, but creates a dedicated branch, commits per task, opens a PR at the end, and optionally waits for review comments and addresses them.</td>
</tr>
</tbody>
</table>

Both share the validation pipeline: <strong>prettier &rarr; tsc &rarr; eslint &rarr; tests &rarr; (optional) Chrome browser test</strong>.

<hr>

## Quickstart (with the skill)

After install:

> Set up a nightshift to add a stop button to my chat UI, plus branch navigation, plus a media gallery page.

Claude reads your <code>package.json</code>, detects your stack, writes <code>todo-YYYY_MM_DD_chat-features.md</code> with three properly-spec'd tasks, generates the codebase context by exploring <code>src/</code>, copies and customizes <code>run-agent-loop.sh</code>, runs preflight, and tells you the exact launch command.

You run:

```bash
./start-nightshift.sh start
```

Next morning:

> Show me what happened overnight.

Claude reads <code>.agent-logs/nightshift-summary.log</code>, greps the todo for REVIEW flags, summarizes the diff by area, shows screenshots for any <code>CHROME REVIEW NEEDED</code> tasks, and produces a structured report with suggested commits.

<hr>

## Tuning

Formula: <code>MAX_ITERATIONS &gt;= NUM_TASKS &times; (1 + MAX_FIX_ATTEMPTS + 2)</code>

<table>
<thead>
<tr><th>Scenario</th><th>MAX_ITERATIONS</th><th>MAX_FIX_ATTEMPTS</th><th>COOLDOWN</th></tr>
</thead>
<tbody>
<tr><td>5 easy tasks</td><td>50</td><td>3</td><td>2s</td></tr>
<tr><td>16 mixed tasks (default)</td><td>200</td><td>7</td><td>5s</td></tr>
<tr><td>30+ ambitious tasks</td><td>400</td><td>10</td><td>8s</td></tr>
<tr><td>Quick prototype</td><td>40</td><td>2</td><td>2s</td></tr>
<tr><td>100-step Bulletproof sweep</td><td>500</td><td>7</td><td>5s</td></tr>
</tbody>
</table>

Full presets in <a href="./templates/runner-config.env"><code>templates/runner-config.env</code></a>.

<hr>

## vs alternatives

<table>
<thead>
<tr><th>Tool</th><th>Best for</th><th>Why nightshift instead</th></tr>
</thead>
<tbody>
<tr>
  <td>Cursor / Windsurf agents</td>
  <td>Inline editor assist, single-task agents</td>
  <td>They live in the editor. Nightshift runs detached, overnight, behind a real validation gate.</td>
</tr>
<tr>
  <td>Aider</td>
  <td>Pair-programming style CLI</td>
  <td>Aider is interactive. Nightshift is batch &mdash; write the plan, walk away.</td>
</tr>
<tr>
  <td>Devin / SWE-agents</td>
  <td>Issue &rarr; PR end-to-end, cloud</td>
  <td>Nightshift is open-source, runs on your machine, reads your codebase context exactly as you write it.</td>
</tr>
<tr>
  <td>GitHub Copilot Workspace</td>
  <td>Spec &rarr; PR for GitHub issues</td>
  <td>Workspace is GitHub-locked. Nightshift runs locally on any repo, any branch, any toolchain.</td>
</tr>
<tr>
  <td>Raw <code>claude -p</code> in a bash loop</td>
  <td>Anyone with bash</td>
  <td>This is what nightshift <em>is</em>, with: a validation gate, fix loop, Chrome MCP testing, Bulletproof PR mode, per-stack adapters, sanitized real examples, and a 47KB playbook.</td>
</tr>
</tbody>
</table>

Niche: <strong>you trust the model to write code, want it harnessed by a strict validation gate, and want it detached so you can sleep.</strong>

<hr>

## Adapting to other stacks

The validation function is a single bash function. Replace it.

<details>
<summary><strong>Python</strong></summary>

```bash
run_full_validation() {
    black . && mypy . && ruff check . && pytest
}
```
</details>

<details>
<summary><strong>Go</strong></summary>

```bash
run_full_validation() {
    gofmt -w . && go vet ./... && golangci-lint run && go test ./...
}
```
</details>

<details>
<summary><strong>Rust</strong></summary>

```bash
run_full_validation() {
    cargo fmt && cargo clippy -- -D warnings && cargo test
}
```
</details>

Per-stack codebase-context examples and conventions in <a href="./docs/01-playbook.md">docs/01-playbook.md</a> sections 11 and 13.

<hr>

## Repo layout

```
SKILL.md                      Claude Code skill manifest + workflow guide
.claude-plugin/plugin.json    Plugin marketplace manifest
bin/install.sh                One-liner installer

commands/
  nightshift-setup.md         /nightshift-setup
  nightshift-status.md        /nightshift-status
  nightshift-review.md        /nightshift-review
  nightshift-resume.md        /nightshift-resume
  nightshift-debug.md         /nightshift-debug
  nightshift-bulletproof.md   /nightshift-bulletproof

docs/
  01-playbook.md              Master guide (47 KB)
  02-bulletproof-mode.md      PR-loop variant deep dive
  03-chrome-testing.md        Live browser MCP testing
  04-qa-checklist.md          Writing production-ship checklists
  05-failure-modes.md         Cheatsheet of seen failures + fixes
  06-test-loop.md             Recursive validation loop (no Claude)
  07-cost-and-safety.md       Cost estimates + safety checklist
  FAQ.md                      Common questions

scripts/
  run-agent-loop.sh           Classic feature-implementation runner
  nightshift-bulletproof.sh   Branch + commit per step + PR variant
  start-nightshift.sh         start/stop/status/tail wrapper
  test-nightshift.sh          Recursive validation loop

templates/
  todo-template.md            Feature-plan skeleton
  codebase-context.md         Heredoc filler for the runner
  qa-checklist-template.md    Production-ship checklist skeleton
  runner-config.env           Tuning presets per scenario

examples/
  todo-simple-example.md      Synthetic 5-task dark-mode toggle (start here)
  bulletproof-steps-example.md Synthetic 10-step hardening sweep
  qa-checklist-saas.md        Real (sanitized) 22-section SaaS checklist
  bulletproof-summary.log     Real (sanitized) 100-step run timeline

.github/workflows/lint.yml    CI: shellcheck + markdownlint + JSON validation
CONTRIBUTING.md               How to contribute
CHANGELOG.md                  Release history
SECURITY.md                   Vulnerability disclosure policy
```

<hr>

## Prerequisites

<table>
<tr><td><strong>Required</strong></td><td><code>claude</code> CLI installed and authenticated &middot; <code>bash</code> 4+ &middot; a project with linter, type checker, test runner</td></tr>
<tr><td><strong>Bulletproof only</strong></td><td><code>gh</code> CLI authenticated</td></tr>
<tr><td><strong>Chrome phase only</strong></td><td>Chrome browser + <a href="https://chromewebstore.google.com/">Claude-in-Chrome extension</a></td></tr>
</table>

<hr>

## Why nightshift

The autonomous loop verifies code compiles, lints, types pass, unit tests pass, and the browser sees the element. It does <strong>not</strong> verify the user's golden path end-to-end, payment flows, email sends, cross-feature interactions, performance, cross-browser behavior, mobile UX, legal copy, or compliance.

That's the human's job in the morning. The QA checklist (<a href="./templates/qa-checklist-template.md"><code>templates/qa-checklist-template.md</code></a>) is the contract for those things.

Nightshift is not <em>AI replaces engineering</em>. It is <em>AI handles the mechanical 80% so you can spend morning hours on the judgment-heavy 20%.</em>

<hr>

## License

MIT. See <a href="./LICENSE">LICENSE</a>.

## Contributing

See <a href="./CONTRIBUTING.md">CONTRIBUTING.md</a>. The most valuable contributions: new stack adapters (Elixir, Kotlin, Swift, Ruby, .NET), sanitized real examples from your own runs, failure modes not yet in <a href="./docs/05-failure-modes.md">docs/05-failure-modes.md</a>.

## Security

See <a href="./SECURITY.md">SECURITY.md</a> for vulnerability disclosure.

<div align="center">

<sub>Built for the overnight engineer.</sub>

</div>
