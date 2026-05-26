# Contributing

Thanks for considering a contribution. The most valuable additions:

1. **Stack adapters** — `run_full_validation()` snippets for stacks not yet covered (Elixir, Kotlin, Swift, Ruby, PHP, Java, .NET).
2. **Real (sanitized) examples** — todo files, QA checklists, summary logs from your own runs. The richer `examples/` gets, the better the skill performs.
3. **Failure modes** — bugs you've hit that aren't in `docs/05-failure-modes.md`.
4. **Slash commands** — new `commands/*.md` for adjacent workflows (e.g. `nightshift-resume`, `nightshift-debug`, `nightshift-export`).

## Development setup

```bash
git clone https://github.com/noluyorAbi/autonomous-agent-nightshift
cd autonomous-agent-nightshift

# Lint scripts (CI runs this)
shellcheck scripts/*.sh

# Lint markdown
npx markdownlint-cli2 "**/*.md" "#node_modules"
```

## PR checklist

- [ ] Scripts pass `shellcheck`
- [ ] Markdown passes `markdownlint-cli2`
- [ ] No project-specific identifiers (BMW, InterviewPilot, client names, etc.) leak into scripts or templates
- [ ] Real examples in `examples/` are sanitized (no secrets, no PII, no proprietary architecture details)
- [ ] If you add a slash command, also wire it into `.claude-plugin/plugin.json`
- [ ] If you add a new `docs/` file, update the README repo-layout block

## Sanitization rules

When contributing examples from real projects:

| Sanitize | Keep |
|----------|------|
| Customer / client names | Generic placeholders (`{your-app}`, `{client}`) |
| API keys, secrets, JWTs, webhook secrets | Remove entirely |
| Specific table names tied to a product domain | Generic equivalents |
| Real user emails / IDs | `user@example.com` / `user_123` |
| Proprietary algorithms, scoring weights, business rules | Describe the shape, not the value |
| Step / task names | Keep — they're the most useful part of an example |
| File paths in the project | Keep — they're context for the agent |
| Branch names | Keep |

## Conduct

Be specific. Be terse. No grandstanding. If you're correcting someone, point to the file:line and explain the failure mode. If you're adding examples, lead with what's surprising or non-obvious about your run.
