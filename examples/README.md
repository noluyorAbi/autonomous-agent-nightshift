# Examples — Real Sanitized Artifacts

Every file here is from a production nightshift run on a real codebase, with project-specific identifiers (BMW, InterviewPilot, client/app names) genericized. The structure and patterns are intact so you can see what these documents actually look like in practice — not just a template.

| File | What it is |
|------|------------|
| [`todo-design-nightshift.md`](./todo-design-nightshift.md) | 50-task design-system overhaul for a real estate / club website (SV Nord München). Demonstrates Phase 1–N structure, dense Implementation+Validation pairs, Chrome QA contract, and the `— CHROME REVIEW NEEDED` / `— NEEDS MANUAL REVIEW` annotations the runner appends. |
| [`qa-checklist-saas.md`](./qa-checklist-saas.md) | 22-section production-ship checklist from a German SaaS. Touches OAuth 2.1 / PKCE, Stripe checkout, Supabase RLS, quota enforcement, security headers, observability, legal pages. A useful concrete reference for what "good" looks like. |
| [`bulletproof-summary.log`](./bulletproof-summary.log) | 100-step Bulletproof run timeline. Read it to see how PASS / FAIL / CHROME / GIT events interleave in practice, and what the rate-limit backoff looks like in the wild. |

## How to read these

These are **examples, not templates** — your project's todo / checklist / log will look different. The shape is what matters:

- **Tasks are dense:** Each Implementation paragraph names exact files, functions, props, classes. Each Validation paragraph specifies the assertion. There is no "make it work" anywhere.
- **The Chrome QA contract is literal:** Every UI task ends with `CHROME_VERDICT: PASS` or `FAIL`. The harness greps for the exact string. The contract is enforced by the prompt, not by good behavior.
- **Annotations are tracked in the file itself:** When the runner fails a task, it appends ` — NEEDS MANUAL REVIEW` to the checkbox line. You see the failure right next to the task spec.

Copy the templates from `../templates/` — not these files — into your project. Use these only as reference for what "real" looks like.
