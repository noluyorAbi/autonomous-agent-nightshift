# Examples — Real Sanitized Artifacts

Every file here is from a production nightshift run on a real codebase, with project-specific identifiers (BMW, InterviewPilot, client/app names) genericized. The structure and patterns are intact so you can see what these documents actually look like in practice — not just a template.

| File | What it is | Read order |
|------|------------|------------|
| [`todo-simple-example.md`](./todo-simple-example.md) | **Synthetic** 5-task dark-mode toggle. Pure template fill — no project-specific context. **Start here** for your first nightshift. | 1st |
| [`bulletproof-steps-example.md`](./bulletproof-steps-example.md) | **Synthetic** 10-step production hardening sweep (CSP, HSTS, rate limiting, Sentry, cookie consent). Shows what `BULLETPROOF-STEPS.md` input looks like. | 2nd |
| [`todo-design-nightshift.md`](./todo-design-nightshift.md) | **Real (sanitized)** 50-task design-system overhaul. Demonstrates dense Implementation+Validation pairs at scale, Chrome QA contract, and the `— CHROME REVIEW NEEDED` / `— NEEDS MANUAL REVIEW` annotations. | 3rd |
| [`qa-checklist-saas.md`](./qa-checklist-saas.md) | **Real (sanitized)** 22-section production-ship checklist. OAuth 2.1 / PKCE, Stripe checkout, RLS, quota enforcement, security headers, observability, legal pages. | 4th |
| [`bulletproof-summary.log`](./bulletproof-summary.log) | **Real (sanitized)** 100-step Bulletproof run timeline. Shows how PASS / FAIL / CHROME / GIT events interleave and what rate-limit backoff looks like in the wild. | 5th |

## How to read these

These are **examples, not templates** — your project's todo / checklist / log will look different. The shape is what matters:

- **Tasks are dense:** Each Implementation paragraph names exact files, functions, props, classes. Each Validation paragraph specifies the assertion. There is no "make it work" anywhere.
- **The Chrome QA contract is literal:** Every UI task ends with `CHROME_VERDICT: PASS` or `FAIL`. The harness greps for the exact string. The contract is enforced by the prompt, not by good behavior.
- **Annotations are tracked in the file itself:** When the runner fails a task, it appends ` — NEEDS MANUAL REVIEW` to the checkbox line. You see the failure right next to the task spec.

Copy the templates from `../templates/` — not these files — into your project. Use these only as reference for what "real" looks like.
