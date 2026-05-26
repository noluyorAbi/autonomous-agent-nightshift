# {Plan Title}: Autonomous Execution Plan

**Runner contract:** This file is consumed by `run-agent-loop.sh`. The parser takes the **first** unchecked task whose line matches `- [ ] **Task N: ...**`, then reads every subsequent line indented with ≥ 2 spaces as that task's body. Keep every task in that exact shape — the bash regex is strict.

**Agent Instructions:** For each task you must:

1. Read every file named in `Implementation` before editing.
2. Write or update the tests named in `Validation` alongside the implementation.
3. Run the **code validation gate**: `prettier --write .` → `tsc --noEmit` → `lint` → `test` → `build`. The gate must be fully green before the checkbox flips.
4. For every task that changes visible UI, conclude the Chrome QA phase by emitting **exactly**:

   ```
   CHROME_VERDICT: PASS
   Evidence: <short bullet list of what you verified in the live app>
   ```

   or `CHROME_VERDICT: FAIL` plus issues + suggested fixes.

5. Only mark `[x]` on success. On failed code validation after max fix attempts, append ` — NEEDS MANUAL REVIEW`. On Chrome-only failure (code green, UI not verifiable), append ` — CHROME REVIEW NEEDED`.

**Never** delete or weaken tests. No `any`, no `@ts-ignore`, no `eslint-disable`.

---

## Phase 1: {Phase Name}

- [ ] **Task 1: {Specific, named outcome}**
  - **Implementation:** {Exactly what to build/change. Reference specific functions, components, file paths. Mention the existing hook/pattern to reuse.}
  - **Validation:** {The test that must pass. Be specific: "Assert that X returns Y when given Z" — not "make sure it works".}

- [ ] **Task 2: {Specific, named outcome}**
  - **Implementation:** {...}
  - **Validation:** {...}

## Phase 2: {Phase Name}

- [ ] **Task 3: {Specific, named outcome}**
  - **Implementation:** {...}
  - **Validation:** {...}

---

## Checklist for the human before launch

- [ ] Every task has both **Implementation** and **Validation** sections
- [ ] Tasks are numbered sequentially across phases (Task 1, Task 2, ...)
- [ ] Each task is small enough to finish in one Claude session (~5–15 min of agent work)
- [ ] No task depends on more than 2 prior tasks
- [ ] All referenced files actually exist in the codebase
- [ ] Forbidden patterns are listed (no `any`, no `@ts-ignore`, etc.)
