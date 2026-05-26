---
name: New stack adapter request
about: Request or contribute an adapter for a stack not yet covered
title: '[stack] '
labels: enhancement, stack-adapter
---

## Stack

<!-- e.g. Elixir / Phoenix, Kotlin / Spring Boot, Swift / Vapor, .NET, Ruby on Rails -->

## Validation gate command sequence

<!-- The equivalent of `prettier && tsc --noEmit && eslint && bun test` for this stack -->

```bash
# Format
# Type check (or compile check)
# Lint
# Unit test
# Build (optional, for production-hardening runs)
```

## Typical codebase-context shape

<!-- What files would a nightshift on this stack need listed in the heredoc? -->

## Test framework specifics

<!-- How are tests organized? Where do they go? Import syntax? -->

## Common forbidden patterns

<!-- e.g. for TypeScript: no `any`, no `@ts-ignore`. What's the equivalent here? -->

## Are you contributing the adapter yourself?

- [ ] Yes — I'll open a PR adding a `run_full_validation()` snippet + codebase-context example to `docs/01-playbook.md`
- [ ] No — this is a request for someone else to write it
