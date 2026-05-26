# Writing a Production Ship QA Checklist

The QA checklist is a markdown document that the human (you, in the morning) walks through before deploying. It's the safety net under the autonomous run.

Template lives at `templates/qa-checklist-template.md`. A real (sanitized) example is in `examples/qa-checklist-saas.md`.

---

## Why bother

The autonomous loop verifies:
- Code compiles, lints, types
- Unit tests pass
- Browser sees the element

It does **not** verify:
- The user's golden path end-to-end
- Payment flows actually move money in test mode
- Email sends actually arrive
- Cross-feature interactions (signup → onboarding → first feature use)
- Performance under realistic load
- Cross-browser behavior beyond Chrome
- Mobile/touch UX
- Legal/compliance copy
- Security headers and CSP
- Cookie consent gating analytics

The checklist is the human's contract for those things.

---

## When to write one

| Type of run | Need a checklist? |
|-------------|-------------------|
| Single-task bugfix | No — review the diff |
| 5-10 small feature tasks | Optional — depends on blast radius |
| Overnight feature sprint | **Yes** |
| Production-ship Bulletproof sweep | **Required** — this is what it's for |
| Dependency upgrade | **Yes** — upgrade compatibility breaks creep in |

---

## How to structure it

Group by **page or flow**, not by file. The checklist is for the human walking through the app in a browser, not reading source.

```
0. Pre-flight (build commands, env vars, migrations)
1. Each main page or flow (landing, auth, dashboard, ...)
2. Auth flows (signup, login, OAuth, password reset)
3. Each major user action (the things users actually do)
4. Quota / rate limiting
5. API smoke
6. Security headers
7. Error handling
8. Mobile / responsive
9. Observability (errors, analytics, vitals)
10. Legal pages
11. Sign-off line
```

Order them so a human can walk the app top to bottom and check items as they go.

---

## The legend

Each item is one of:

- `[ ]` pending
- `[x]` verified — passed manually
- `[!]` bug found — file a blocker
- `[~]` known-skip with reason

The `[~]` state is important: it's an explicit acknowledgement that you saw the item and chose not to verify it (e.g. "Stripe live mode — only test in staging"). It's not the same as "I forgot."

---

## Writing good checklist items

**Bad:**
```
- [ ] Landing page works
- [ ] Auth is fine
```

**Good:**
```
- [ ] Hero headline + primary CTA render within ~500ms (no long blank hold)
- [ ] Signup with valid email + 12-char password → redirects to /verify-email within 20s
- [ ] OAuth Google button → either redirects to consent OR shows "provider not enabled"
```

Rules:

1. **Each item is a single assertion.** If you find yourself writing "and," split into two items.
2. **State the expected behavior, not the test action.** "Pricing cards align with equal height" beats "check pricing card alignment."
3. **Include thresholds.** "Lighthouse Performance ≥ 85" beats "page is fast."
4. **Reference exact paths and URLs.** "/login?error=invalid_oauth_state renders error banner" beats "OAuth errors handled."
5. **Cover failure paths explicitly.** Don't just check the happy path — every external call has a fail mode worth one line.

---

## Pairing with the autonomous run

You can have the agent populate parts of the checklist:

1. After Bulletproof finishes, ask Claude to read `.agent-logs/bulletproof-summary.log` and pre-tick items that map to completed steps.
2. For items with a clear test (`bun test specific.test.ts`), the agent can run the test and report.
3. Items requiring eyes (animations, copy review, mobile feel) stay `[ ]` for the human.

But don't let the agent self-tick visual items. The whole point is that a human looks.

---

## Sign-off

Every checklist ends with:

```
Reviewer: ______________________   Date: ____________
Blocker count: ___   Ship? [ ] Yes  [ ] No — see bug list
```

The discipline of signing your name forces a real "yes" or "no" instead of vibes. If you can't put a date next to "yes," ship date is wrong.
