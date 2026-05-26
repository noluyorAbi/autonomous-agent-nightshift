# Codebase Context — Fill-In Template

Paste this into the `CODEBASE_CONTEXT` heredoc inside `run-agent-loop.sh` or `nightshift-bulletproof.sh`. Fill every `{placeholder}` with values from your project. Re-run the codebase exploration whenever you add new major files.

```
## Codebase Map (use these exact paths):

**Stack:** {framework} + {language} + {db} + {styling} + {ui-kit}

**Pages & Routes:**
- {path/to/file.tsx} — {description, key exports}

**API Routes:**
- {path/to/route.ts} — {method, purpose, schema}

**Core Components:**
- {path/to/component.tsx} — {description}

**Types:**
- {path/to/types.ts} — {key interfaces/types}

**Hooks & Services:**
- {path/to/hook.ts} — {what state it manages}
- {path/to/context.tsx} — {what context it provides}

**Business Logic:**
- {path/to/lib.ts} — {description}

**Database:**
- {db} with {RLS / migrations / ...}
- Tables: {list}
- Migrations: {path}

**Config:**
- {build config}
- {test config}
- {lint config}

**Test Files:**
- {path to test dir}

**Package Manager:** {npm/pnpm/bun/yarn}
**Validation:** {lint command}, {type-check command}, {format command}
**Test Runner:** {unit-test command}, {e2e command if any}

## Conventions:
- Always run `{format command}` after code changes
- {Type safety rule: e.g., "TypeScript strict mode. No `any`."}
- {UI patterns: e.g., "Follow existing shadcn/ui patterns. Use Radix primitives."}
- {Animation: e.g., "Framer Motion for animations. No raw CSS keyframes."}
- {Validation: e.g., "Zod for all input. Never trust user input."}
- {Theming: e.g., "Dark mode via CSS variables, not hardcoded colors."}
- {Test locality: e.g., "Tests colocated as *.test.{ext}."}
- {Auth/data: e.g., "Supabase RLS on all tables. Never bypass client-side."}
- {Rate limiting: e.g., "Rate limit all API routes via lib/rate-limit.ts"}
```

---

## Quality Checklist

Run through this before pasting your filled-in context:

- [ ] Every file the agent might touch is listed
- [ ] Key functions/exports are named (not "the main component")
- [ ] Test framework + import syntax are explicit
- [ ] UI library, styling, animation, icon library are stated
- [ ] Forbidden patterns are listed (`any`, `@ts-ignore`, etc.)
- [ ] The exact formatting command is included
- [ ] The agent could navigate the codebase using only this map

---

## How to Generate It (when starting fresh)

Option A — let Claude do it:

```bash
claude -p "Explore this codebase thoroughly. List every important file with its path and a one-line description of what it does. Group by domain (e.g. routes, components, API, types, hooks). Include the UI stack, test framework, package manager, and key conventions. Format as markdown using the structure in templates/codebase-context.md."
```

Option B — do it by hand:

You know your codebase. Walking through the directories and writing one-liners often produces a better map than asking the agent.
