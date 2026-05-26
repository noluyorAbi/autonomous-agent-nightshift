# Production Ship QA Checklist — `{branch-name}`

Target environment: `http://localhost:{port}` (local smoke) → production.
Run this before pressing deploy. Tick every box or file a blocker.

Legend: `[ ]` pending · `[x]` verified · `[!]` bug found · `[~]` known-skip with reason.

---

## 0. Pre-flight

- [ ] `{install command}` clean, no warnings
- [ ] `{lint command}` — 0 errors
- [ ] `{type-check command}` — 0 errors
- [ ] `{unit test command}` — all suites green
- [ ] `{e2e test command}` — green on target browsers
- [ ] `{build command}` — no warnings
- [ ] `.env` has all required keys: {list them}
- [ ] DB migrations applied

---

## 1. Landing / Marketing pages

- [ ] {Specific element renders} (no flash of unstyled content)
- [ ] {Animation/perf assertion}
- [ ] {Copy assertion — e.g. "headline reads ABC"}
- [ ] Every CTA navigates correctly
- [ ] Footer links 200 OK
- [ ] No console errors
- [ ] Lighthouse: Performance ≥ {N}, Accessibility ≥ {N}

## 2. Navbar / Global chrome

- [ ] Fits on one line at all target breakpoints
- [ ] Hamburger menu opens + closes
- [ ] No untranslated copy / wrong-language strings
- [ ] Theme toggle behaves as designed (or is absent)
- [ ] Logo links to `/`

## 3. Auth — Signup

- [ ] Form validation: weak password / bad email surfaces inline
- [ ] Valid signup → expected redirect within {N}s
- [ ] If email provider misconfigured → friendly error, not hang
- [ ] Verification email arrives, link works
- [ ] OAuth buttons → either work OR show clear "not configured" error
- [ ] No console errors

## 4. Auth — Login

- [ ] Valid creds → expected redirect
- [ ] Wrong password → error surfaced inline
- [ ] Forgot-password flow completes end-to-end
- [ ] OAuth error states render correctly
- [ ] Session persists after browser restart (within TTL)

## 5. {Main feature flow}

- [ ] {Happy path step 1}
- [ ] {Happy path step 2}
- [ ] {Validation: required field blocked}
- [ ] {Validation: malformed input rejected}
- [ ] {Edge case: empty state}
- [ ] {Edge case: max input size}

## 6. {Critical business action — payment / submission / etc}

- [ ] Happy path completes
- [ ] Test payment / submission registers in DB
- [ ] Webhook (if any) lands and is processed idempotently
- [ ] User is redirected to expected page
- [ ] Notifications fire (email, in-app, etc)

## 7. Quota / rate limiting

- [ ] Hitting limit → expected block (modal, banner, 429)
- [ ] Under limit → action allowed
- [ ] Server fail-closed if quota check errors

## 8. Admin (if applicable)

- [ ] Non-admin redirected away from /admin
- [ ] Admin actions audit-logged
- [ ] Admin stats render correctly

## 9. API smoke

- [ ] `GET /api/health` → 200
- [ ] Unauthenticated request → 401
- [ ] Authenticated → expected payload
- [ ] CSRF / HMAC protections enforced
- [ ] Bad payload → 400, never 500

## 10. Security headers

- [ ] `Content-Security-Policy` present
- [ ] `Strict-Transport-Security` present (HTTPS only)
- [ ] `X-Frame-Options: DENY`
- [ ] `X-Content-Type-Options: nosniff`
- [ ] `Referrer-Policy: strict-origin-when-cross-origin`
- [ ] `Permissions-Policy` present

## 11. Error handling

- [ ] Global error boundary catches component throws
- [ ] 404 page on unknown route
- [ ] API 500s log but never leak stack traces to client
- [ ] Rate-limit hit → 429 + Retry-After header

## 12. Mobile + responsive

- [ ] Smallest target viewport: every screen readable, no horizontal scroll
- [ ] Touch interactions work
- [ ] Modals fit on small screens

## 13. Observability

- [ ] Error monitoring receives errors (deliberately trigger one)
- [ ] Analytics events fire (or are blocked by consent correctly)
- [ ] Web vitals reported (or silently dropped — acceptable)

## 14. Legal + marketing

- [ ] `/privacy` renders, reflects current processor list
- [ ] `/terms` renders
- [ ] `/imprint` (if required by jurisdiction) renders
- [ ] Cookie consent shows before any non-essential script loads

---

## Sign-off

Reviewer: ______________________   Date: ____________

Blocker count: ___   Ship? [ ] Yes  [ ] No — see bug list
