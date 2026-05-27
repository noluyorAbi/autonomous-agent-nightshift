# Examples

Two synthetic templates to start from, plus two real (sanitized) production artifacts so you can see what they look like at scale.

| File | What it is | Read order |
|------|------------|------------|
| [`todo-simple-example.md`](./todo-simple-example.md) | **Synthetic** 5-task dark-mode toggle. Pure template fill — no project-specific context. **Start here** for your first nightshift. | 1st |
| [`bulletproof-steps-example.md`](./bulletproof-steps-example.md) | **Synthetic** 10-step production hardening sweep (CSP, HSTS, rate limiting, Sentry, cookie consent). Shows what `BULLETPROOF-STEPS.md` input looks like. | 2nd |
| [`qa-checklist-saas.md`](./qa-checklist-saas.md) | **Real (sanitized)** 22-section production-ship checklist from a SaaS run. OAuth 2.1 / PKCE, Stripe checkout, RLS, quota enforcement, security headers, observability, legal pages. | 3rd |
| [`bulletproof-summary.log`](./bulletproof-summary.log) | **Real (sanitized)** 100-step Bulletproof run timeline. Shows how PASS / FAIL / CHROME / GIT events interleave and what rate-limit backoff looks like in the wild. | 4th |

## How to read these

These are **reference artifacts, not templates** — your project's todo / checklist / log will look different. The shape is what matters:

- **Tasks are dense:** Each Implementation paragraph names exact files, functions, props, classes. Each Validation paragraph specifies the assertion. There is no "make it work" anywhere.
- **The Chrome QA contract is literal:** Every UI task ends with `CHROME_VERDICT: PASS` or `FAIL`. The harness greps for the exact string. The contract is enforced by the prompt, not by good behavior.
- **Annotations are tracked in the file itself:** When the runner fails a task, it appends ` — NEEDS MANUAL REVIEW` to the checkbox line. You see the failure right next to the task spec.

Copy the templates from `../templates/` — not these files — into your project. Use these only as reference for what "real" looks like.
