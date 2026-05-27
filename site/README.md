# Site

Static landing page for autonomous-agent-nightshift. Single-file HTML, no build step.

**Deployed at:** https://noluyorabi.github.io/autonomous-agent-nightshift/

## Edit

- `index.html` — entire site (HTML + embedded CSS + minimal JS)

No bundler, no dependencies. Edit, commit, push. GitHub Pages picks up the change in ~30s.

## Why no build step

Site is one page with no dynamic data. A bundler would add complexity without value. If the site ever needs many pages or dynamic content, swap to Astro/11ty without changing the deploy pipeline.

## Local preview

```bash
python3 -m http.server -d site 8000
# open http://localhost:8000
```

Or any other static server.
