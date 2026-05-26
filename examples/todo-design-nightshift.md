# SV Nord München — Design Nightshift: 50-Point Plan

**Runner contract:** This file is consumed by the Autonomous Agent Playbook's `run-agent-loop.sh`. The parser takes the **first** unchecked task whose line matches `- [ ] **Task N: ...**`, then reads every subsequent line indented with ≥ 2 spaces as that task's body. Keep every task in that exact shape (single header line, then `  - **Implementation:**` / `  - **Validation:**` indented at least two spaces). Do not flatten sub-bullets or change the checkbox style — the bash regex is strict.

**Agent Instructions:** For each task you must:

1. Read every file named in `Implementation` before editing.
2. Write or update the tests named in `Validation` alongside the implementation (TDD where the task says so).
3. Run the **code validation gate**: `npx prettier --write .` → `npx tsc --noEmit` → `npm run lint` → `npm test` → `npm run build` → `npm run e2e`. (Playwright runs on **port 3100**; do not change that.) The gate must be fully green before the checkbox flips.
4. For every task that changes visible UI (most of them), conclude the Chrome QA phase by emitting a line **exactly**:

   ```
   CHROME_VERDICT: PASS
   Evidence: <short bullet list of what you verified in the live app>
   ```

   or `CHROME_VERDICT: FAIL` plus issues + suggested fixes. The harness greps for the literal `CHROME_VERDICT: PASS` substring; no synonyms.

5. Only mark `[x]` on success. On failed code validation after max fix attempts, append ` — NEEDS MANUAL REVIEW`. On Chrome-only failure (code green, UI not verifiable), append ` — CHROME REVIEW NEEDED`. The harness commits and pushes per task.

**Never** delete or weaken tests. No `any`, no `@ts-ignore`, no `eslint-disable`. Follow the `MotionSafe` policy in `lib/motion.tsx` — never import `motion` from `framer-motion` directly; `useReducedMotion`, `useScroll`, `useTransform`, `useInView`, and `AnimatePresence` may still be imported from there. Package manager is **npm** (not pnpm/bun).

**Chrome QA contract (applies to every task):** In the Chrome phase, navigate to the route the task touches, read the accessibility tree, interact with the new element, toggle dark mode (`document.documentElement.classList.toggle('dark')`), read console messages, and screenshot the area that changed into `.agent-logs/screenshots/`. For motion-bearing tasks, record a short GIF. Check `prefers-reduced-motion: reduce` via devtools emulation and verify the animation is stripped or short. Fail the verdict if console produces any new errors/warnings or if the element is invisible/unreachable.

---

## Phase 1 — Design System Foundation

- [x] **Task 1: Lock real club palette from crest sampling** — CHROME REVIEW NEEDED
  - **Implementation:** Use `sharp` to sample dominant pixels from `public/images/crest.webp` at 5 points (shield border, top-banner bg, bottom-bg, "Nord" text, "MÜNCHEN" banner). Write `scripts/sample-crest-palette.ts` that logs the hex values. Update `app/globals.css` `@theme` block: replace `--color-navy-*`, `--color-gold-*`, `--color-sky-*` with final-locked values derived from the samples. Document the source hex in a CSS comment above each token.
  - **Validation:** Vitest: write `scripts/sample-crest-palette.test.ts` asserting the script exits 0 and prints 5 hex codes matching `/^#[0-9a-f]{6}$/i`. Playwright: add `e2e/palette.spec.ts` that renders `/` and asserts `getComputedStyle(body).backgroundColor` is within ΔE < 10 of the navy token.

- [x] **Task 2: Add tabular-figure numeric display font**
  - **Implementation:** Add `JetBrains Mono` via `next/font/google` in `app/layout.tsx`, bound to `--font-mono`. Create a `StatNumber` component at `components/site/design.tsx` that renders a number in display font with `font-feature-settings: "tnum" "lnum"` so digits align in counters/scoreboards.
  - **Validation:** Vitest: `StatNumber.test.tsx` asserts `data-testid="stat-number"` has computed `font-variant-numeric` containing `tabular-nums`.

- [x] **Task 3: Typography utility primitives (Overline, Eyebrow, DisplayXL)**
  - **Implementation:** Extend `components/site/design.tsx` — export `Eyebrow` (uppercase tracking-widest gold small), `DisplayXL` (clamp 4rem→12rem Bebas white), `DisplayLG` (clamp 2.5rem→6rem), and `Pullquote` (Fraunces italic with left gold bar). Replace every ad-hoc hero/section heading across the codebase to use one of these primitives.
  - **Validation:** Vitest snapshot on each primitive. Grep assertion in a new `scripts/no-adhoc-display.ts` run as `npm run check:typography` that finds no `text-(5xl|6xl|7xl|8xl)` + `font-display` pair outside `components/site/design.tsx`.

- [x] **Task 4: Noise + grain texture system**
  - **Implementation:** Generate a 256×256 SVG turbulence noise at `public/textures/noise.svg`. Add `.noise` utility in `app/globals.css` as a `::before` pseudo-element overlay, `mix-blend-mode: overlay`, `opacity: 0.04`. Apply it to hero, slogan banner, and footer backgrounds.
  - **Validation:** Playwright: `e2e/design-textures.spec.ts` navigates to `/` and asserts `window.getComputedStyle(document.querySelector('[data-section="hero"]'), '::before').backgroundImage` includes `noise.svg`.

- [x] **Task 5: Reusable gradient mesh presets**
  - **Implementation:** Create `components/site/GradientMesh.tsx` with a `variant` prop: `hero | banner | footer | subtle`. Each variant is a composed set of radial gradients keyed to navy/gold/sky tokens. Replace inline `background-image` gradient declarations in hero/slogan/footer with `<GradientMesh variant=... />`.
  - **Validation:** Vitest: 4 snapshot tests for each variant rendering. Lint rule update in `eslint.config.mjs` forbids `background-image:\s*radial-gradient` inline style strings outside `GradientMesh.tsx`.

- [x] **Task 6: Elevation & glow shadow scale**
  - **Implementation:** Add `--shadow-elev-1` through `--shadow-elev-4` and `--shadow-glow-gold` / `--shadow-glow-sky` to `@theme` in `app/globals.css`. `--shadow-glow-gold` uses `0 0 32px oklch(var(--color-gold-500) / 0.35)`. Replace existing `shadow-lg` on buttons/cards with the new scale.
  - **Validation:** Visual spec `e2e/shadows.spec.ts`: hover over a `Button variant="primary"` on `/`, read `box-shadow`, assert it contains `32px` (glow).

- [x] **Task 7: Animated gold-underline primitive** — NEEDS MANUAL REVIEW
  - **Implementation:** Create `GoldUnderline` client component in `components/site/design.tsx`. It wraps children and animates a `::after` gold bar from 0 → 100% width on hover/focus via MotionSafe. Convert all nav items in `SiteHeader`, article card titles, and footer links to use it.
  - **Validation:** Vitest + RTL: assert element has a span with `data-role="underline"`. Playwright: hover a nav link, take screenshot, assert gold pixel count along underline region > 200 (via `page.evaluate` canvas sample).

---

## Phase 2 — Hero & Homepage Polish

- [x] **Task 8: Cinematic hero photo + multi-layer parallax**
  - **Implementation:** Pick the most dramatic team/match photo in `public/images/` programmatically (largest dimension × brightness median). Use it as `HeroParallax` background. Add 3 parallax layers with `useScroll + useTransform` at different rates: background photo (0.3), gold mesh overlay (0.6), foreground text (0.9). All wrapped in MotionSafe.
  - **Validation:** Playwright: scroll 600px on `/`, screenshot `docs/shots/desktop-home-scrolled.png`, assert title y-offset differs from background y-offset.

- [x] **Task 9: Kinetic hero headline reveal**
  - **Implementation:** Split "SV NORD" into individual `<span>` characters in `HeroParallax`. Stagger each with MotionSafe y: 40 → 0, opacity 0 → 1, duration 0.4, delay `i * 0.06`, ease `[0.22, 1, 0.36, 1]`.
  - **Validation:** Vitest: render, assert 7 span children with `aria-hidden="true"` wrapping individual letters plus one visually-hidden full `<span>` for screen readers.

- [x] **Task 10: Animated subtitle fade-in sequence**
  - **Implementation:** Below the hero headline, add a sequence: "SEIT 1949" (gold, Eyebrow) → short descriptor line → hashtag chip. Each animates in 0.15s after the previous under MotionSafe.
  - **Validation:** Vitest asserts render order; Playwright asserts all three elements visible within 800ms of page load via `waitForSelector`.

- [x] **Task 11: Scroll-progress gold bar (top of viewport)** — CHROME REVIEW NEEDED
  - **Implementation:** Create `components/site/ScrollProgress.tsx` — a 2px `position: fixed; top: 0; inset-x: 0` bar whose `scaleX` binds to `useScroll().scrollYProgress`. Gold gradient. Mount in `app/layout.tsx` inside `MotionProvider`.
  - **Validation:** Playwright: scroll to 50%, assert bar's `getBoundingClientRect().width` ≈ 50% of viewport.

- [x] **Task 12: Real stat counter values**
  - **Implementation:** Remove hardcoded `{ value: 0 }` stats. In `app/page.tsx` compute values at build-time: `Mitglieder: 1200` (placeholder constant in `content/club.mdx` frontmatter — add it), `Mannschaften: <count of content/teams/>`, `Abteilungen: <count of content/departments/>`, `Jahre Tradition: new Date().getFullYear() - 1949`. Expose via `lib/content/stats.ts`.
  - **Validation:** Vitest: `getClubStats()` returns `{ mitglieder, mannschaften, abteilungen, jahre }` with `jahre >= 77` and `mannschaften >= 20`.

- [x] **Task 13: StatCounter count-up animation on intersection**
  - **Implementation:** In `components/site/StatCounter.tsx`, trigger the count-up via `useInView` once per stat. Use `useMotionValue` + `useSpring` to animate from 0 to target over 1.8s. Under reduced-motion, render the final value instantly.
  - **Validation:** Vitest: with `matchMedia(prefers-reduced-motion: reduce) = true`, assert final text content equals target value within 1 render frame.

- [x] **Task 14: Inline SVG crest in hero corner**
  - **Implementation:** Create `components/site/CrestMark.tsx` — a clean SVG traced outline of the crest (shield + "SV" monogram), styled with `currentColor`. Place at hero top-left (desktop) and behind the "EINMAL NORDLER" slogan banner at 8% opacity as a watermark.
  - **Validation:** Vitest: component renders with `<svg role="img" aria-label="SV Nord Wappen">`.

- [x] **Task 15: Magnetic hashtag chip**
  - **Implementation:** Add a `Magnetic` wrapper in `components/site/design.tsx` — follows cursor with up to ±8px translate using `useMotionValue` + pointer events, under MotionSafe. Apply to the `#EINMALNORDLERIMMERNORDLER` chip in the hero.
  - **Validation:** Vitest + userEvent: simulate `pointerMove` 50px to the right of element center; assert `style.transform` contains `translate(` with positive X.

- [x] **Task 16: Pulsing glow on primary hero CTA**
  - **Implementation:** Add a subtle `box-shadow` pulse (scale 1 → 1.02, glow opacity 0.3 → 0.55) with `animation: pulse-glow 2.4s ease-in-out infinite` on `Button[data-variant="primary"]` within hero. Define keyframes in `app/globals.css`. Disable under `@media (prefers-reduced-motion: reduce)`.
  - **Validation:** Playwright: assert computed `animation-name: pulse-glow` when reduced-motion is off; asserts `animation-name: none` when Playwright context emulates `prefers-reduced-motion`.

- [x] **Task 17: Transparent-to-solid header on hero pages** — CHROME REVIEW NEEDED
  - **Implementation:** In `SiteHeader.tsx`, detect whether the current route has a hero (list hero routes in `components/site/nav-config.ts` as `HERO_ROUTES`). On those routes, render with `bg-transparent` until `scrollY > 40`, then switch to navy/85 + blur. Non-hero routes always render solid.
  - **Validation:** Playwright: `/news` asserts initial `backdropFilter` is set immediately; `/` asserts initial bg is transparent, scroll 60px → bg becomes navy.

---

## Phase 3 — Key Section Redesign

- [x] **Task 18: Department tiles with real images and overlay copy**
  - **Implementation:** In `DepartmentStrip.tsx`, render each of 5 departments as a tile with `fussball.webp`, `gymnastik.webp`, `ski.webp`, `volleyball.webp`, `e-sport.webp` from `public/images/`. If a specific image is missing, pick a contextual fallback from `public/images/manifest.json`. Add department name (DisplayLG), short 6-word tagline, arrow icon; dark navy bottom gradient; hover zoom 1.04 + gold bottom bar animate to 100%.
  - **Validation:** Vitest: renders exactly 5 tiles, each with `<Image>` `alt` matching the department name; RTL hover assertion on gold bar width.

- [x] **Task 19: NextFixtureBanner with matchup layout** — CHROME REVIEW NEEDED
  - **Implementation:** Redesign `NextFixtureBanner.tsx`: 3-column layout — home crest + name | VS + date/time/location | away crest + name. If away crest unknown, render initials circle. Add an "Alle Termine →" CTA linking `/events`.
  - **Validation:** Vitest: given a fixture with both teams, renders exactly two crests; with one team, renders one crest + one initials circle.

- [x] **Task 20: Editorial LatestNewsTeaser grid**
  - **Implementation:** Redesign `LatestNewsTeaser.tsx` as a CSS Grid: one 2/3-width featured card with tall cover + long excerpt + DisplayLG title; two 1/3-width stacked cards on the right. Below 1024px collapses to single column. Featured card has a gold "AKTUELL" chip.
  - **Validation:** Playwright at 1440px: asserts first `article` `getBoundingClientRect().width` > 600px; at 768px: asserts all articles stacked (`top` differs).

- [x] **Task 21: Marquee wordmark + 75-year timeline dots**
  - **Implementation:** Extend `SloganBanner.tsx`: add a full-width infinite-scrolling wordmark `SV NORD · MÜNCHEN-LERCHENAU · SEIT 1949 · ` in huge outlined Bebas (paused on hover, static under reduced-motion). Above it, a horizontal dotted timeline of 8 milestone years (1949, 1965, 1980, 1995, 2005, 2015, 2020, 2026) each with a gold dot and year label.
  - **Validation:** Vitest: asserts 8 `<li data-milestone>` elements; Playwright: assert marquee animation is `paused` when reduced-motion CSS is applied.

- [x] **Task 22: Tiered SponsorWall with real grid**
  - **Implementation:** Redesign `components/sponsors/SponsorWall.tsx` to group by `tier` (`haupt | premium | partner`) into 3 bands. Haupt: 1 big centered logo. Premium: 3-column. Partner: 5-column. Gold horizontal divider with tier label between bands. Extend `content/sponsors.json` with 6 placeholder entries (3 tiers × 2) using existing logo images; document replacements in a comment.
  - **Validation:** Vitest: asserts 3 `<section data-tier>` elements. If a tier is empty, renders an inline "Tier noch frei" placeholder chip.

- [x] **Task 23: 5-column footer with Öffnungszeiten block**
  - **Implementation:** Expand `SiteFooter.tsx` from 4 to 5 columns: (1) Crest + wordmark + socials, (2) Navigation, (3) Kontakt with gold icons, (4) Öffnungszeiten (Geschäftsstelle Mo–Fr 17:00–19:00 — placeholder content flagged as TODO in JSX comment), (5) Newsletter. Add a gold divider between the content grid and the copyright bar.
  - **Validation:** Vitest: asserts 5 `<div data-footer-col>` children; Playwright: at 1280px, all 5 columns on one row.

- [x] **Task 24: "Spielplan Heute" widget on home**
  - **Implementation:** New component `components/site/TodayFixtures.tsx` — reads `lib/events.ts`, filters events occurring today (Europe/Berlin). Renders compact row of chips: time + home vs away + location. Hides itself if empty. Mount on `/` between hero and stats.
  - **Validation:** Vitest: with a mocked event today, component renders; with zero today-events, renders `null`.

- [x] **Task 25: "Kommende Events" horizontal snap-scroll on home** — CHROME REVIEW NEEDED
  - **Implementation:** New component `components/site/UpcomingEventsRail.tsx` — renders next 8 events in horizontal `overflow-x-auto snap-x snap-mandatory` row. Each card is 280px wide with date block (gold), title, department chip. Left/right chevron nav buttons that scroll by 300px.
  - **Validation:** Vitest: renders N cards for N events (≤8); RTL: click `aria-label="Weiter"` → asserts `scrollLeft` increases.

- [x] **Task 26: Section rhythm + gradient dividers**
  - **Implementation:** Create `Section` layout component in `components/site/design.tsx` accepting `tone?: 'default' | 'elevated' | 'dark'`, `divider?: 'none' | 'gold' | 'mesh'`. Enforces `py-24 md:py-32`, max-width 7xl, horizontal padding. Convert every home section to use `<Section>`. `divider="gold"` renders a 1px gold-500/60 line with 20% noise above the section.
  - **Validation:** Grep check in `scripts/check-section-rhythm.ts`: every page in `app/` imports `Section` and wraps top-level content; CI script added to `package.json` as `check:sections` and runs in the `lint` chain.

---

## Phase 4 — Teams & Departments

- [x] **Task 27: Team detail hero**
  - **Implementation:** In `app/mannschaften/[slug]/page.tsx`, add a hero: full-bleed team photo if present (else gradient mesh), huge team name in DisplayXL, Eyebrow label "HERREN / JUGEND / …", meta row (Liga + Saison + Trainer count).
  - **Validation:** Playwright: navigate `/mannschaften/1-mannschaft`, assert hero height > 420px and the team name appears in `h1`.

- [x] **Task 28: Uniform-numbered RosterGrid**
  - **Implementation:** Redesign `RosterGrid.tsx`: 6-col grid of square tiles (navy-900 bg). Each tile shows giant gold tabular-num player number top-right, position icon top-left, name at bottom. Hover: ring + crest watermark reveal.
  - **Validation:** Vitest: roster of 11 players renders 11 `<li>` tiles; assert tile with `number={10}` has element containing text "10" with class matching `/text-gold/`.

- [x] **Task 29: PlayerCard redesign (number-dominant)**
  - **Implementation:** Rework `PlayerCard.tsx` front: photo fills card, bottom gradient, giant number top-right in gold Bebas 96px, name + position bottom-left. Back: two-column stats table (Alter, Größe, Position, Lieblingsfuß — placeholders if absent).
  - **Validation:** Existing PlayerCard.test.tsx adjusted: `flipped` toggles via Space or Enter; front shows number; back shows stats table with `<dl>` semantics.

- [ ] **Task 30: Departments hub with animated tab indicator**
  - **Implementation:** In `app/abteilungen/page.tsx`, render a shadcn Tabs component with one tab per department, plus an "Alle" first tab. The active tab displays a gold underline indicator that slides on change via MotionSafe `layoutId="tab-indicator"`.
  - **Validation:** Playwright: click "Ski", assert element with `data-state="active"` moves; screenshot diff shows gold bar under the clicked tab.

- [ ] **Task 31: Department landing page enhancements**
  - **Implementation:** In `app/abteilungen/[slug]/page.tsx`, add a 3-stat bar (Aktive Mannschaften, Trainer:innen, Trainingstage pro Woche), a TrainerList with avatar placeholders (gold initials circle), and a TrainingTimes block grouped by weekday.
  - **Validation:** Vitest: given a department mock with 3 teams, stat "Aktive Mannschaften" renders "3".

- [ ] **Task 32: TeamCard photo-fill redesign**
  - **Implementation:** Rework `TeamCard.tsx`: full-bleed team photo background (placeholder gradient if none), dark navy bottom gradient, team name DisplayLG bottom-left, age-group chip (gold outline) top-right, "Kader: N" pill (navy-900/80 cream text) top-left, animated gold bottom-border on hover.
  - **Validation:** Vitest: card with `photo: undefined` renders the gradient fallback (class `bg-gradient-*`); card with roster of 12 renders "Kader: 12".

- [ ] **Task 33: Empty-roster illustration**
  - **Implementation:** Create `components/teams/EmptyRoster.tsx` — a simple SVG of a stadium silhouette + gold ball + cream copy "Kader folgt bald. Trainer kontaktieren." with a "Kontakt" CTA. Render in `RosterGrid` when roster.length === 0.
  - **Validation:** Vitest: roster `[]` renders EmptyRoster; roster with entries renders RosterGrid tiles.

---

## Phase 5 — News & Article Pages

- [ ] **Task 34: Magazine-grid news index with lead article**
  - **Implementation:** In `app/news/page.tsx` + `NewsGrid.tsx`, when more than one article exists: show the most recent as a full-width lead (huge cover, DisplayXL title, 2-line excerpt, gold "AKTUELL" chip). Remaining articles render as a masonry-like CSS-columns grid (3 cols desktop, 2 tablet, 1 mobile).
  - **Validation:** Vitest: 5 articles → 1 lead + 4 column cards. 1 article → 1 lead, no column grid rendered.

- [ ] **Task 35: Full-bleed article cover + sticky reading-progress bar**
  - **Implementation:** In `app/news/[slug]/page.tsx`, add a 70vh cover image with dark navy bottom gradient and headline overlaid at bottom (DisplayXL). Add a reading-progress gold bar below `SiteHeader` that fills as the article scrolls, respecting reduced-motion.
  - **Validation:** Playwright: load a fixture article, assert cover is ≥60% viewport height, scroll 80% → progress bar scaleX ≥ 0.8.

- [ ] **Task 36: Editorial article typography + related rail**
  - **Implementation:** In `components/mdx/ArticleBody.tsx`, add drop-cap first letter (Fraunces 5xl gold). Style `<blockquote>` with a 4px gold left bar and italic Fraunces text. Render `components/news/RelatedArticles.tsx` as a horizontal snap-scroll rail below article.
  - **Validation:** Vitest: article MDX with a `> quote` renders `<blockquote>` with `data-role="pullquote"`. RelatedArticles tests already exist — extend to assert horizontal scroll container has `snap-x`.

- [ ] **Task 37: Icon ShareButtons with toast confirmation**
  - **Implementation:** Replace existing `ShareButtons.tsx` text buttons with circular gold-outline icon buttons (`Link2`, `Mail`, `Share2`). Clicking "Link" copies URL and fires a sonner toast `"Link kopiert"`. Web Share API used when available; fallback = mailto/copy.
  - **Validation:** Vitest + userEvent: click copy button, assert `navigator.clipboard.writeText` called with the URL and toast function invoked.

- [ ] **Task 38: Search overlay with keyboard hints**
  - **Implementation:** Convert `SearchBar.tsx` into a command-palette-style overlay (shadcn Dialog) triggered by `⌘K`/`Ctrl+K` and the nav search icon. Shows recent categories, top 6 results, keyboard hints ("↑↓ navigieren · ↵ öffnen · ESC schließen") in a footer strip.
  - **Validation:** RTL: `userEvent.keyboard('{Meta>}k{/Meta}')` opens the dialog; typing "fuß" filters to fixture article `fuß`-containing title; pressing Escape closes.

---

## Phase 6 — Events & Calendar

- [ ] **Task 39: Department color dots on month grid**
  - **Implementation:** In `MonthGrid.tsx`, each event dot uses a small colored swatch keyed by department (fussball=gold, gymnastik=sky, ski=cyan-300, volleyball=rose-400, e-sport=purple-400). Day cells with ≥3 events show `+N weitere` chip.
  - **Validation:** Vitest: event with `department: "ski"` renders a dot with class containing `bg-sky-*` or computed style matching token.

- [ ] **Task 40: Crest matchup EventCard variant**
  - **Implementation:** When an event has fields `homeTeam` / `awayTeam` (extend EventSchema to allow optional), render `EventCard` with 2-crest matchup layout. Fall back to standard single-title layout otherwise.
  - **Validation:** Vitest: event with homeTeam+awayTeam renders 2 `<img data-role="crest">`; event without renders neither.

- [ ] **Task 41: Timeline spine for DayView**
  - **Implementation:** In `DayView.tsx`, render events along a vertical gold spine with timestamp labels on the left; each event becomes a card to the right of the spine with a gold connecting dot. Empty hours labeled with muted tick.
  - **Validation:** Vitest: 3 events at 10:00, 14:00, 18:00 render 3 cards aligned to their hour rows; asserts timestamp text present.

- [ ] **Task 42: Add-to-calendar modal with platform options**
  - **Implementation:** Replace `IcalExportButton` single action with a shadcn Dialog that offers: Apple Kalender (`.ics` download), Google Kalender (URL launcher), Outlook Kalender (URL), and Copy iCal URL. Each action logs analytics stub (`console.debug("calendar-export", …)`).
  - **Validation:** RTL: click the button opens dialog with 4 items; clicking "Google" calls `window.open` with a `calendar.google.com/calendar/u/0/r/eventedit` URL.

---

## Phase 7 — Forms & Interactive

- [ ] **Task 43: Floating-label contact form with inline validation**
  - **Implementation:** Rework `ContactForm.tsx`: labels float above filled/focused inputs, invalid fields get a red-400 border + error text under the field. On successful submit, swap the form with a success state panel ("Nachricht erhalten. Wir melden uns." + gold check icon + confetti burst under MotionSafe).
  - **Validation:** Existing ContactForm tests updated: (a) empty submit → 3 inline error texts; (b) valid submit → success panel replaces form; (c) reduced-motion → no confetti element in DOM.

- [ ] **Task 44: Custom-pinned OSM map embed**
  - **Implementation:** In `MapEmbed.tsx`, switch to an OSM static image via `https://www.openstreetmap.org/export/embed.html` with precise bbox for 80935 München-Lerchenau. Overlay a DOM pin (gold ring + cream dot + club name badge) absolutely positioned at the click-through link.
  - **Validation:** Playwright: `/kontakt` renders an iframe AND an overlay `data-role="map-pin"` element; asserting both exist and the pin is `role="img"` with `aria-label` containing "Sportheim".

- [ ] **Task 45: Mobile drawer with stagger + active indicator**
  - **Implementation:** Update `MobileDrawer.tsx`: nav items stagger in (y: 12 → 0, opacity 0 → 1, 0.06s each) under MotionSafe. Active route gets a 3px gold left border. Close icon replaces menu icon when open; tap-outside closes.
  - **Validation:** RTL: open drawer, assert each `<a>` has increasing `data-stagger-index`; navigate mocked router to `/news`, assert the News link has class including `border-l-gold` (or `data-active="true"`).

- [ ] **Task 46: Animated theme toggle with first-visit system preference**
  - **Implementation:** Add a theme toggle to `SiteHeader` (desktop + drawer). Clicking swaps sun/moon icons with a rotate+scale spring under MotionSafe. On first visit (no `theme` localStorage entry), read system `prefers-color-scheme` and persist; subsequent visits use the stored value via `next-themes`.
  - **Validation:** RTL: initial render respects `prefers-color-scheme: light` mock by setting `html.classList = 'light'`; click → class flips to `dark` and localStorage contains `"theme":"dark"`.

---

## Phase 8 — Details, Errors, Microinteractions

- [ ] **Task 47: 404 + 500 error pages with club personality**
  - **Implementation:** Create `app/not-found.tsx` and `app/error.tsx`. 404: gradient mesh bg, huge DisplayXL "404" with a gold ball replacing the "0", copy "Diese Seite steht im Abseits.", CTA "Zurück zum Spielfeld" linking `/`. 500: similar template, copy "Technisches Foul." and a reload CTA.
  - **Validation:** Playwright: navigate `/definitely-not-a-route` → asserts 404 h1 text "Abseits"; force error by deleting a required prop in a `__test-error/page.tsx` route (under `[locale]` if applicable) — assert 500 page rendered.

- [ ] **Task 48: Skeleton loading states with gold shimmer**
  - **Implementation:** Create `components/site/Skeleton.tsx` — navy-800 block with a gold → gold/20 shimmer keyframe (`animation: shimmer 1.6s linear infinite`). Replace existing shadcn `Skeleton` usage in news/team/events loading fallbacks.
  - **Validation:** Vitest: renders with `role="progressbar"` `aria-busy="true"` and a `<span data-shimmer>` child. Playwright: visit `/news` with throttled network, assert shimmer element present during load then removed after.

- [ ] **Task 49: Favicon set + dynamic OG image generator**
  - **Implementation:** Export PNG favicon set (16, 32, 48, 180, 192, 512) from `public/images/crest.webp` via `scripts/build-favicons.ts`. Create `app/opengraph-image.tsx` using Next.js ImageResponse API — renders navy/gold gradient, huge Bebas "SV NORD MÜNCHEN-LERCHENAU", crest, slogan. Add per-route dynamic OG where title/description vary (news article, team, event).
  - **Validation:** Playwright: fetch `/opengraph-image` → asserts 200 response + `content-type: image/png`. Vitest: mock route metadata with a news slug, assert generated OG alt text contains the article title.

- [ ] **Task 50: Scroll-to-top button + keyboard hint**
  - **Implementation:** Create `components/site/ScrollToTop.tsx` — fixed bottom-right circular gold button with up-chevron, appears after `scrollY > 400` via MotionSafe fade+slide. Pressing `g t` scrolls to top (keyboard handler scoped in `LenisProvider`). Show a tiny "g t" hint tooltip on hover.
  - **Validation:** Playwright: scroll 600px, assert button is visible; click → assert `scrollY === 0`; dispatch keydown sequence `g`, `t` within 600ms → asserts `scrollY === 0`.

---

## Self-Review Footer

**Coverage:** palette/tokens (1), typography (2–3), texture/gradient/shadow/underline (4–7), hero polish (8–17), home sections (18–26), teams & departments (27–33), news & articles (34–38), events (39–42), forms & interactive (43–46), error pages + micro (47–50) — **50 tasks, 8 phases**.

**Task quality:** every task references specific files/components, names functions/classes, and has a concrete test or Playwright assertion. No task depends on more than 2 prior tasks. File paths match the current repo layout. Every task that changes visible UI has an implicit Chrome QA contract (see header).

**Non-negotiables:**

- Full gate green on every task: `npx prettier --write . && npx tsc --noEmit && npm run lint && npm test && npm run build && npm run e2e`.
- Chrome phase must emit the literal string `CHROME_VERDICT: PASS` in its log (the harness runs `grep -q` for that exact substring — no synonyms).
- Never bypass `MotionSafe`. Never widen or delete tests.

**Suggested runner config (production `run-agent-loop.sh`, npm-adapted):**

```
TODO_FILE="todo-2026_04_14_design-nightshift.md"

# Iteration budget: NUM_TASKS × (2 + MAX_FIX_ATTEMPTS + MAX_CHROME_FIX_ATTEMPTS + 2)
# = 50 × (2 + 8 + 3 + 2) = 750. Add headroom for PR phase + transient retries.
MAX_ITERATIONS=900
MAX_FIX_ATTEMPTS=8            # code-validation retries per task
MAX_CHROME_FIX_ATTEMPTS=3     # Chrome-phase fix rounds per task
COOLDOWN_SECONDS=6
COOLDOWN_MAX=120

# App + git
DEV_PORT=3100                 # matches existing Playwright config
DEV_SERVER_WAIT=20
BASE_BRANCH="main"
PR_WAIT_MINUTES=30            # overnight runs — give reviewers time before comment pass
```

**Validation function (npm, not bun):**

```bash
run_full_validation() {
  local logfile="$1" all_passed=true
  echo "=== VALIDATION ===" > "$logfile"

  echo "[1/6] Prettier..." >> "$logfile"
  npx prettier --write . >> "$logfile" 2>&1 || { all_passed=false; echo "[FAIL] prettier" >> "$logfile"; }

  echo "[2/6] TypeScript..." >> "$logfile"
  npx tsc --noEmit >> "$logfile" 2>&1 || { all_passed=false; echo "[FAIL] tsc" >> "$logfile"; }

  echo "[3/6] ESLint..." >> "$logfile"
  npm run lint --silent >> "$logfile" 2>&1 || { all_passed=false; echo "[FAIL] eslint" >> "$logfile"; }

  echo "[4/6] Vitest..." >> "$logfile"
  npm test --silent >> "$logfile" 2>&1 || { all_passed=false; echo "[FAIL] vitest" >> "$logfile"; }

  echo "[5/6] Build..." >> "$logfile"
  npm run build --silent >> "$logfile" 2>&1 || { all_passed=false; echo "[FAIL] build" >> "$logfile"; }

  echo "[6/6] Playwright E2E..." >> "$logfile"
  npm run e2e --silent >> "$logfile" 2>&1 || { all_passed=false; echo "[FAIL] e2e" >> "$logfile"; }

  $all_passed
}
```

**Parser sanity check (before launch):**

```bash
grep -c '^- \[ \] \*\*Task [0-9]\+:' todo-2026_04_14_design-nightshift.md   # expect 50
grep -nE '^- \[ \] \*\*Task' todo-2026_04_14_design-nightshift.md | head -5  # spot-check format
```

Both must pass. If the first number is not 50, a task header is malformed and the harness will skip it.

**Pre-launch checklist (Playbook §17, repo-adapted):**

- [ ] `gh auth status` succeeds; fork paths (if any) updated in `run-agent-loop.sh` (Playbook §16).
- [ ] Chrome open with Claude-in-Chrome extension **Connected**; logged into `http://localhost:3100` if any route requires it.
- [ ] `python3` on `PATH` (used by PR comment processing).
- [ ] Working tree clean; everything you care about is committed. The harness commits per task to `nightshift/$(date +%Y-%m-%d)`.
- [ ] `.agent-logs/` and `.claude_iterations` in `.gitignore`.
- [ ] Baseline clean: `npm run typecheck && npm test && npm run build` green right now.
- [ ] Baseline screenshots archived (`cp -r docs/shots docs/shots.pre-nightshift`) so morning review can diff visually.

**Morning triage commands:**

```bash
grep -E 'FAILED|MANUAL REVIEW|CHROME REVIEW|PR CREATED|NIGHTSHIFT FINISHED' .agent-logs/nightshift-summary.log
grep -E 'MANUAL REVIEW|CHROME REVIEW' todo-2026_04_14_design-nightshift.md
ls -la .agent-logs/screenshots/
git log --oneline origin/main..nightshift/$(date +%Y-%m-%d)
```
