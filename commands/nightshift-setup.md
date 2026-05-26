---
description: Set up a new autonomous nightshift run on the current project
---

You are setting up a nightshift run on the user's project. Follow `SKILL.md` Workflow 1 exactly:

1. **Detect stack** — read `package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod`, identify framework, test runner, package manager, lint/format/type-check/dev-server commands.

2. **Clarify the feature plan** — ask the user what they want built. Push back on vague requests. Every task needs a specific outcome and a testable assertion. Aim for 5-20 tasks, each fitting one Claude session (~5-15 min agent work).

3. **Write the todo file** at `todo-$(date +%Y_%m_%d)_{name}.md` using `templates/todo-template.md` structure. Each task must have:
   - **Implementation:** exact files, functions, props, classes to touch + existing patterns to reuse
   - **Validation:** testable assertion ("Assert X returns Y when given Z"), never "make sure it works"

4. **Generate codebase context** by exploring `src/` (Glob + key reads). Produce a heredoc following `templates/codebase-context.md` covering file paths, conventions, forbidden patterns.

5. **Copy + customize runner** — copy `scripts/run-agent-loop.sh` and `scripts/start-nightshift.sh` into the project root. Update:
   - `TODO_FILE` = the file you just wrote
   - `CODEBASE_CONTEXT` heredoc = your generated context
   - `run_full_validation()` = the user's actual toolchain (see SKILL.md for per-stack patterns)
   - `DEV_PORT` = the user's dev server port
   - Limits per `templates/runner-config.env` (default overnight: `MAX_ITERATIONS=200`, `MAX_FIX_ATTEMPTS=7`)

6. **Pre-flight** — verify each:
   - [ ] `claude` CLI authenticated
   - [ ] Clean baseline: `bun test && npx tsc --noEmit` (or equivalent) returns 0
   - [ ] `.gitignore` includes `.agent-logs/` and `.claude_iterations`
   - [ ] (Chrome) Chrome open, extension shows "Connected"
   - [ ] (Chrome) User logged into the app for auth-walled routes

7. **Don't launch.** Tell the user the exact launch command:
   ```
   chmod +x run-agent-loop.sh start-nightshift.sh
   ./start-nightshift.sh start
   ./start-nightshift.sh tail
   ```

Throughout: honor the principles in `SKILL.md` — the human writes WHAT, the agent writes HOW. Every task verifiable. The codebase context is the agent's only memory between sessions.
