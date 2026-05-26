# Chrome Browser Testing (Phase 3)

After code validation passes, the runner launches a live visual + functional check in a real browser via the [Claude-in-Chrome extension](https://chromewebstore.google.com/) MCP server. This is what catches the bugs that unit tests miss.

Full architecture lives in `docs/01-playbook.md §9` — this file is a focused integration guide.

---

## What it catches that unit tests don't

| Unit tests catch | Chrome testing catches |
|------------------|------------------------|
| Wrong return values | Button is there but invisible (z-index, opacity) |
| Missing function calls | Dark mode breaks text color |
| Type errors | Click handler fires but UI doesn't update |
| API schema mismatches | New component causes React hydration error |
| Logic bugs | Element exists but is unreachable (covered by overlay) |
| Regression in other tests | Console floods with warnings on every render |

---

## Prerequisites

1. Chrome browser must be open **and stay open** for the entire run.
2. The [Claude-in-Chrome extension](https://chromewebstore.google.com/) installed and showing "Connected" status.
3. The dev server runs automatically (the script starts it on `DEV_PORT`).
4. If your app requires auth, log in to it in Chrome before launching. Session cookies persist across tabs.

---

## Per-task pipeline

```
Code validation passes
    │
    ▼
Dev server running on DEV_PORT? (auto-started)
    │
    ▼
Claude opens Chrome via MCP tools
    │
    ├── 1. Get tab context              (tabs_context_mcp)
    ├── 2. Create new tab               (tabs_create_mcp)
    ├── 3. Navigate to relevant page    (navigate)
    ├── 4. Visual inspection            (read_page — a11y tree)
    ├── 5. Functional testing           (computer / form_input)
    ├── 6. Console check                (read_console_messages)
    ├── 7. Dark mode toggle + re-check  (javascript_tool)
    ├── 8. Screenshot                   (upload_image)
    └── 9. GIF recording                (gif_creator) — for interactions
    │
    ▼
Verdict: PASS or FAIL
    │
    ├── PASS → Mark task [x]
    │
    └── FAIL → Fix loop (up to MAX_CHROME_FIX_ATTEMPTS)
              │
              ├── Claude fixes the code based on Chrome findings
              ├── Re-run code validation (in case fix broke tests)
              ├── Re-test in Chrome
              └── Loop or give up with "CHROME REVIEW NEEDED" note
```

---

## The verdict contract

The Chrome testing prompt instructs Claude to emit a structured verdict line that the harness greps for verbatim:

**PASS:**
```
CHROME_VERDICT: PASS
Evidence: Button renders correctly, onClick navigates to branch, dark mode OK, no console errors
```

**FAIL:**
```
CHROME_VERDICT: FAIL
Issues found:
- Stop button not visible during generation (opacity: 0 in dark mode)
- Console error: "Cannot read properties of undefined (reading 'id')"
Suggested fixes:
- Add dark:opacity-100 class to stop button
- Add null check in branch navigation handler
```

The harness greps for the literal substring `CHROME_VERDICT: PASS`. Any other output is treated as FAIL.

---

## What gets checked

| Check | How |
|-------|-----|
| Element exists | `read_page` accessibility tree — is the new button/panel/modal present? |
| Correct text/labels | A11y tree shows proper content and ARIA labels |
| Interactions work | `computer` clicks, `form_input` fills fields |
| State changes | After interaction, re-read page to verify UI updated |
| Dark mode | Toggle via `document.documentElement.classList.toggle('dark')`, re-check |
| Reduced-motion | Emulate `prefers-reduced-motion: reduce` via devtools, verify animation strips |
| No console errors | `read_console_messages` with error/warning filter |
| No network failures | `read_network_requests` for failed API calls |
| Visual evidence | Screenshot saved to `.agent-logs/screenshots/` |
| Animation evidence | GIF recorded for interactive features |

---

## Task-specific navigation

Tell Claude where to look. Inside the runner's `CHROME_CONTEXT` heredoc, list your routes:

```
- Landing: http://localhost:$DEV_PORT/
- Login: http://localhost:$DEV_PORT/login
- Dashboard: http://localhost:$DEV_PORT/dashboard
- {Your feature}: http://localhost:$DEV_PORT/{path}
```

The agent picks the right one from the task description. If a task touches multiple routes, the implementation prompt should call them out by path.

---

## When to disable Chrome testing

Pass `--skip-chrome` to skip Phase 3 entirely. Reasons to do this:

- **No browser available** (running on a headless server)
- **Backend-only changes** (API routes, DB migrations, infra)
- **CI/CD environment** without Chrome
- **Auth wall you can't bypass** (no demo mode and no persistent session)

Without Chrome testing, the loop relies entirely on the code validation gate (lint, types, tests). For backend work that's usually enough; for UI changes you'll catch ~70% of issues but visual regressions slip through.

---

## Auth-walled apps

If most of your app requires login:

1. Log in to the app in Chrome **before** launching the runner. The session cookie persists.
2. If the cookie expires mid-run, the Chrome agent will see login pages instead of your app. The verdict will be `FAIL` with a note about the redirect.
3. For long runs, consider a longer session TTL during nightshift, or a `?demo=true` bypass mode.

---

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Chrome phase errors immediately with MCP tool errors | Chrome closed or extension disabled | Open Chrome, verify extension shows "Connected" |
| Tests fail with "connection refused" after working earlier | Dev server crashed on a build error | Check `.agent-logs/dev-server.log`; runner auto-restarts |
| Agent always says PASS even when broken | Verdict prompt too lenient, or feature isn't a11y-tree visible | Review screenshots manually; tighten the prompt |
| Auth wall blocks Chrome | No session in browser | Log in before launch, or enable demo mode |

For animations and pixel-precise layouts, **always review the saved GIFs/screenshots manually** in the morning. The a11y-tree-based agent can't see them.

```bash
open .agent-logs/screenshots/*.png
open .agent-logs/screenshots/*.gif
```
