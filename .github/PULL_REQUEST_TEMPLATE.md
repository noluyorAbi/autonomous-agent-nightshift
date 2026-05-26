## What this PR does

<!-- One sentence. What changes, why. -->

## Type

- [ ] Bug fix (script bug, broken docs, wrong example)
- [ ] New stack adapter (Python / Go / Rust / Elixir / Kotlin / etc.)
- [ ] New slash command
- [ ] New example (sanitized real artifact or synthetic skeleton)
- [ ] Documentation
- [ ] CI / tooling

## Checklist

- [ ] Scripts pass `shellcheck` at severity `warning`
- [ ] Markdown passes `markdownlint-cli2`
- [ ] No project-specific identifiers (client/customer names, real API keys, real user data) leak in
- [ ] If touching scripts: tested locally on at least one project
- [ ] If adding a slash command: also wired into `.claude-plugin/plugin.json`
- [ ] If adding a doc: updated the repo-layout block in `README.md`
- [ ] If user-visible change: updated `CHANGELOG.md` under `[Unreleased]`

## How to test

<!-- Specific steps a reviewer can run. -->

```bash
# Example
git clone <this-branch>
cd autonomous-agent-nightshift
# run shellcheck etc.
```
