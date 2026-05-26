# Security Policy

## Reporting a vulnerability

If you discover a security issue in the scripts, slash commands, or installer:

1. **Do not open a public GitHub issue.**
2. Email the maintainer or use [GitHub's private vulnerability reporting](https://github.com/noluyorAbi/autonomous-agent-nightshift/security/advisories/new).
3. Include:
   - A description of the issue
   - Steps to reproduce
   - Affected file + line number(s)
   - Suggested fix if you have one

Expect an acknowledgement within 7 days.

## What counts as a security issue here

This repo ships **bash scripts that run on the user's machine and spend money on Claude API calls**. Security issues include:

- **Command injection** in any script that interpolates external data (PR comments, task titles, file names) into shell commands without quoting
- **Path traversal** in `install.sh` or any file the agent is instructed to read/write
- **Privilege escalation** patterns (e.g. scripts that suid, write to `/etc`, modify shell rc files without warning)
- **Credential leakage** in logs, summary outputs, or commit messages
- **Supply chain** issues: malicious URLs in `install.sh`, compromised default GitHub Actions versions

## What is not a security issue

- The agent reads your codebase and sends it to Anthropic's API — this is the entire purpose, documented in `docs/07-cost-and-safety.md`. If you have files the agent shouldn't see, exclude them via `.gitignore` and prune them from the codebase-context heredoc.
- Bash scripts run shell commands — also documented. The validation gate calls your project's lint/test/build commands. Audit them as you would any tool you let near your project.
- A bad task in your todo file can break your codebase — by design, the runner will follow your instructions. Review tasks before launch.

## Hardening recommendations for users

- Run nightshift in a git working tree you can `git restore .` if things go wrong
- Protect `main` branch via GitHub Settings → Branches
- Set Anthropic Console spending limits
- Use a minimal-scope GitHub PAT (only `repo` scope, only for the repos you nightshift)
- Inspect `git diff` before committing the agent's work
- Never run `--dangerously-skip-permissions` on a machine with production credentials in env vars
