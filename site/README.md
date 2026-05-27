# site/

Vite + React + Tailwind + Framer Motion. Static landing for autonomous-agent-nightshift.

**Live:** https://noluyorabi.github.io/autonomous-agent-nightshift/ (or iyikivarsin.me once DNS lands)

## Develop

```bash
npm install
npm run dev          # http://localhost:5173
```

## Build

```bash
npm run build        # outputs site/dist/
npm run preview      # local preview of build
```

## Sync content from canonical source

Some site content is derived from canonical files outside `site/`:
- `package.json` → `src/content/meta.ts`
- `commands/*.md` → `src/content/commands.ts`
- `docs/*.md` → imported at build time via Vite `?raw` (no sync needed)

When the canonical source changes (new version bump, new slash command), run:

```bash
npm run sync         # rewrites meta.ts; detects new commands and warns
```

The sync agent is deliberately deterministic — no LLM calls, just reads + transforms + writes. See `scripts/sync-content.ts`.

## Pages

- `/` — landing (hero, how-it-works, slash commands preview, cost callout, use cases, CTA)
- `/install` — six install channels with copyable commands + comparison table
- `/commands` — full slash command reference
- `/onboarding` — 7-step interactive walkthrough from install to morning review
- `/docs/*` — markdown docs rendered with sidebar nav (playbook, bulletproof, chrome, qa, failures, test-loop, cost, FAQ)

## Stack rationale

- **Vite** — fast HMR, sane defaults, native TypeScript, native `?raw` markdown imports
- **React Router** — multi-page SPA, no SSR needed (this is a marketing/docs site)
- **Tailwind** — utility-first, easy to maintain consistency, fits a single-developer project
- **Framer Motion** — tasteful scroll animations, page transitions, progress bar in onboarding
- **react-markdown + remark-gfm** — render the existing docs/ markdown without rewriting
- **lucide-react** — icon set that pairs well with the dark amber theme

## Deploy

GitHub Actions workflow `.github/workflows/deploy-site.yml` runs on changes to `site/`, `docs/`, `commands/`, `SKILL.md`, or `package.json`. Builds the site and deploys to GitHub Pages.

## Why no SSG / Next.js / Astro

The site is small enough that a SPA with route-level code splitting (future) works fine. Build is 2-3 seconds. Bundle is ~580 KB (most of which is the inlined markdown docs). For docs-heavy sites that grow past 30 pages, consider Astro or VitePress. We're not there.
