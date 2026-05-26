# Add Dark Mode Toggle: Autonomous Execution Plan

**Runner contract:** This file is consumed by `run-agent-loop.sh`. The parser takes the **first** unchecked task whose line matches `- [ ] **Task N: ...**`, then reads every subsequent line indented with ≥ 2 spaces as that task's body. Keep every task in that exact shape.

**Agent Instructions:** For each task:

1. Read every file named in `Implementation` before editing.
2. Write or update the tests named in `Validation`.
3. Run the **code validation gate**: `npm run lint` → `npx tsc --noEmit` → `npm test` → `npm run build`.
4. For UI tasks, conclude Phase 3 by emitting **exactly** `CHROME_VERDICT: PASS` (with evidence bullets) or `CHROME_VERDICT: FAIL` (with issues + suggested fixes).
5. Only mark `[x]` on success. On exhausted retries, append ` — NEEDS MANUAL REVIEW`.

**Never** delete or weaken tests. No `any`, no `@ts-ignore`, no `eslint-disable`.

---

## Phase 1 — Theme Plumbing

- [ ] **Task 1: Add theme context and provider**
  - **Implementation:** Create `src/lib/theme-context.tsx`. Export `ThemeProvider` (React Context) with state `{ theme: 'light' | 'dark', setTheme: (t) => void }`. Persist to `localStorage` under key `app-theme`. On mount, read from `localStorage`; if absent, use `window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'`. Wrap the app root in `src/app/layout.tsx` with `<ThemeProvider>`.
  - **Validation:** In `src/lib/theme-context.test.tsx`, render `<ThemeProvider>{children}</ThemeProvider>` with a child that consumes the context. Assert default theme is `'light'` when no localStorage and matchMedia returns false. Assert that calling `setTheme('dark')` updates the context value and writes `'dark'` to localStorage.

- [ ] **Task 2: Apply theme class to document root**
  - **Implementation:** In `src/lib/theme-context.tsx`, add a `useEffect` inside `ThemeProvider` that does `document.documentElement.classList.toggle('dark', theme === 'dark')` whenever `theme` changes. Confirm `tailwind.config.ts` has `darkMode: 'class'`.
  - **Validation:** In the existing test file, render the provider with theme `'dark'`. Assert `document.documentElement.classList.contains('dark')` is true. Then update to `'light'` and assert the class is removed.

## Phase 2 — UI Toggle

- [ ] **Task 3: Theme toggle button component**
  - **Implementation:** Create `src/components/theme-toggle.tsx`. Render a `<button>` with sun icon (lucide-react `Sun`) when theme is dark, moon icon (`Moon`) when light. Apply Tailwind classes `p-2 rounded hover:bg-gray-100 dark:hover:bg-gray-800`. Use `useTheme()` hook from `theme-context.tsx`. Button toggles between light and dark.
  - **Validation:** In `src/components/theme-toggle.test.tsx`, render `<ThemeToggle />` wrapped in `<ThemeProvider>`. Assert clicking it changes the theme. Use React Testing Library's `fireEvent.click` and check the rendered icon swaps from sun to moon.

- [ ] **Task 4: Place toggle in navbar**
  - **Implementation:** In `src/components/navbar.tsx`, import `ThemeToggle` from `@/components/theme-toggle` and render it in the right-hand action group, before the user menu. Make sure it has `aria-label="Toggle theme"`.
  - **Validation:** In `src/components/navbar.test.tsx` (extend existing), assert that the navbar renders an element with `aria-label="Toggle theme"`.

## Phase 3 — Tailwind dark-mode coverage

- [ ] **Task 5: Audit and add dark-mode variants to top-level surfaces**
  - **Implementation:** In `src/app/layout.tsx`, `src/app/page.tsx`, and `src/components/navbar.tsx`, add Tailwind `dark:` variants for every `bg-*`, `text-*`, and `border-*` class. Pattern: light surfaces → `dark:bg-gray-900`, light text → `dark:text-gray-100`, light borders → `dark:border-gray-800`. Do not touch any component outside these three files in this task.
  - **Validation:** Snapshot test on `src/app/page.tsx` rendered with theme `'dark'` — assert the root element class string contains `dark:bg-gray-900`. (For deeper coverage, the Chrome QA phase verifies visually.)
