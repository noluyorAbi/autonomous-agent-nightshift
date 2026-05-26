# Production Ship QA Checklist — `nightshift/bulletproof-2026-04-05`

Target environment: `http://localhost:3000/` (local smoke) → production.
Run this before pressing deploy. Tick every box or file a blocker.

Legend: `[ ]` pending · `[x]` verified · `[!]` bug found · `[~]` known-skip with reason.

---

## 0. Pre-flight

- [ ] `bun install` clean, no warnings
- [ ] `bun run lint` — 0 errors
- [ ] `bun run typecheck` (or `bunx tsc --noEmit`) — 0 errors
- [ ] `bun run test` — all vitest suites green
- [ ] `bun run test:e2e` — Playwright green on chromium + mobile
- [ ] `bun run build` — no warnings from Turbopack
- [ ] `.env` has: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `ENCRYPTION_MASTER_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_1_WEEK`, `STRIPE_PRICE_1_MONTH`, `STRIPE_PRICE_3_MONTHS`, `GEMINI_API_KEY`, `REQUEST_SIGNING_SECRET`, `OAUTH_CLIENT_ID`
- [ ] Supabase migrations applied (especially `web_vitals` 20260326 migration)

---

## 1. Landing page (`/`)

- [ ] Opens in **dark mode only** (no flash of light theme)
- [ ] Hero headline + CTA render within ~500ms (no long blank hold)
- [ ] GSAP animations play smoothly, no stutter, no blur artifacts
- [ ] **All three pricing cards visible**: Quick Prep (1 Week €17), Best Value (1 Month €21, "Popular"), Serious Prep (3 Months €28)
- [ ] Pricing cards align with equal height, no missing card on tablet widths (641–1023px)
- [ ] Privacy blurb reads "Privacy you stay in control of…" (NOT the old "doesn't leave the room" copy)
- [ ] Every CTA ("Start Free", "Choose Plan", etc.) navigates correctly
- [ ] Footer links (Privacy, Terms, Imprint, Blog) all 200 OK
- [ ] No console errors
- [ ] Lighthouse: Performance ≥ 85, Accessibility ≥ 95

## 2. Navbar

- [ ] **Fits on one line** at 1024px, 1280px, 1440px, 1920px — no wrap
- [ ] Hamburger appears below `lg:` (< 1024px)
- [ ] No **German labels** (no "Anmelden", "Loslegen"); English text for "Log in", "Get Started", "Pricing", "Updates"
- [ ] **No UI language switcher** (neither desktop nor mobile menu)
- [ ] Theme toggle is absent OR non-functional (always-dark is enforced)
- [ ] Logo link to `/`

## 3. Auth — Signup (`/signup`)

- [ ] Email + password fields visible
- [ ] Weak password → inline validation error
- [ ] Valid signup → redirects to `/verify-email` within 20s (never spins forever)
- [ ] If Supabase SMTP is misconfigured → friendly error, not a hang
- [ ] Verification email arrives, link works, lands on `/dashboard`
- [ ] Google OAuth button → (a) redirects to Google consent OR (b) shows clear "provider not enabled" if Google social login isn't configured
- [ ] GitHub / LinkedIn buttons: **either remove OR wire them up** — decide before ship
- [ ] No console errors

## 4. Auth — Login (`/login`)

- [ ] Valid creds → `/dashboard`
- [ ] Wrong password → error surfaced inline
- [ ] "Forgot password" flow sends reset email and updates password successfully
- [ ] `/login?error=oauth_not_configured` and `/login?error=invalid_oauth_state` render error banners
- [ ] Session persists after browser close (within TTL)

## 5. OAuth 2.1 / PKCE flow

- [ ] `/.well-known/openid-configuration` returns Supabase OIDC doc, `Cache-Control: max-age=3600` set
- [ ] `/.well-known/oauth-authorization-server` returns RFC 8414 metadata
- [ ] `/.well-known/jwks.json` returns JWKS from Supabase
- [ ] `/login/oauth` renders "Continue" button
- [ ] Clicking Continue → `/api/auth/oauth/start` → sets `oauth_pkce_verifier`, `oauth_pkce_state`, `oauth_next` cookies (httpOnly, path `/api/auth/oauth`, 10min)
- [ ] Redirects to `${supabaseUrl}/auth/v1/oauth/authorize` with `code_challenge_method=S256`
- [ ] Tampering with `state` on callback → `/login?error=invalid_oauth_state`
- [ ] Missing `code` on callback → `/login?error=missing_oauth_params`
- [ ] Happy path: after IdP round-trip, session cookies are set and user lands on `/dashboard`

## 6. CV + JD upload (`/` → interview setup)

- [ ] CV text OR CV file upload works (PDF, DOCX, MD)
- [ ] **JD is mandatory** — submit with neither text nor file → blocked with "Job Description is required — paste it as text or upload a file."
- [ ] JD text alone → allowed
- [ ] JD file alone → allowed
- [ ] Motivation letter optional
- [ ] Additional files optional, up to the configured limit
- [ ] Question count respected (1–15)
- [ ] Language dropdown shows **only English and Deutsch** (no ES/FR/IT)

## 7. Quota enforcement

- [ ] User with 0 remaining interviews clicks Start → **upgrade modal appears** (not the interview)
- [ ] User with ≥1 credit can start
- [ ] `/api/interviews/check-quota` returns 403 with `canStart: false` when limit hit
- [ ] If check-quota request throws/timeouts on the client → **fail-closed**, upgrade modal still appears
- [ ] Warning email fires once per billing cycle at ≥80% usage

## 8. Interview session (`/dashboard/interview/start` → question flow)

- [ ] Intro view greets user, references "competencies and values in the job description" (NOT BMW / generic values)
- [ ] AI questions are JD-specific (no generic STAR fabrication when JD supplies content)
- [ ] Voice recording: start / stop / replay works
- [ ] Transcription returns text (Gemini `transcribe` action)
- [ ] Keyboard shortcuts modal (`?` key) displays, all shortcuts functional
- [ ] "Finish" → confirmation modal → submits transcript
- [ ] Mid-session reload → session recovery prompt restores state
- [ ] Network drop mid-session → UI shows offline indicator, retries on reconnect

## 9. Analysis + feedback

- [ ] `analyzeInterview` happy path → feedback view renders overall score + per-competency scores + STAR breakdown
- [ ] Dashboard "recent sessions" shows the just-finished session with non-null score
- [ ] **Truncation case**: when Gemini response is cut off, user sees a **red "Analysis failed"** message (NOT a fabricated 50/100 score), and the session row shows `status = failed`
- [ ] **DB save failure case**: response succeeds, but DB write fails → red toast "Results not saved" surfaces (tested by dropping DB connectivity briefly or revoking `interview_sessions` insert perms in staging)
- [ ] `X-Save-Status` header is `ok` on success, `error` on DB failure

## 10. Dashboard (`/dashboard`)

- [ ] Loads list of sessions decrypted (never shows raw `enc:v1:…` strings)
- [ ] Charts (DashboardAnalytics) render with real data, no "Unable to parse" errors
- [ ] Clicking a session → `/dashboard/interview/[id]` shows full decrypted feedback
- [ ] Other user's session ID in the URL → 404 (ownership enforced)
- [ ] Session without feedback_report (in-progress) → graceful empty state

## 11. Stripe checkout & subscription

- [ ] From pricing page or upgrade modal: select plan → Stripe Checkout opens (HMAC-signed request succeeds, no 403)
- [ ] Completed test payment → webhook lands, subscription row created, user promoted to `business` tier
- [ ] Quota updates immediately after upgrade
- [ ] Invoices list populates under `/settings/subscription`
- [ ] Portal link opens Stripe Customer Portal (HMAC-signed)
- [ ] Plan change (upgrade/downgrade) preview + commit flow works
- [ ] Coupon validation (valid + invalid + expired)
- [ ] Cancel subscription flow → downgrade at period end

## 12. Settings

### /settings
- [ ] Profile name/email editable
- [ ] Password change flow works
- [ ] Notification preferences persist

### /settings/subscription
- [ ] Current plan rendered correctly
- [ ] Payment method update works (Stripe portal)
- [ ] Invoice download works

### /settings/privacy
- [ ] "Export my data" triggers email with archive link OR in-page download
- [ ] "Delete account" requires password reauth, then deletes + signs out (HMAC-signed)
- [ ] Cookie consent banner honors opt-out (PostHog, Crisp not loaded when denied)

## 13. Share view (`/share/[token]`)

- [ ] Valid token → read-only feedback view
- [ ] Revoked / invalid token → 404 page
- [ ] Link expiration honored

## 14. Referrals (`/referrals`)

- [ ] Email invite submission works
- [ ] Bonus credit applies when invitee signs up
- [ ] Referral list shows status (pending / redeemed)

## 15. Admin (`/admin`)

- [ ] Non-admin redirected away
- [ ] Users table loads, search works, HMAC-signed actions (ban, refund) succeed
- [ ] Stats page renders
- [ ] Audit log captures each admin action

## 16. Blog (`/blog`, `/blog/[slug]`)

- [ ] Index lists posts
- [ ] Slug page renders MDX, images load
- [ ] 404 for unknown slug

## 17. API routes — smoke

- [ ] `GET /api/health` → 200 `{ ok: true }`
- [ ] `GET /api/interviews/list` without auth → 401
- [ ] `GET /api/interviews/list` with auth → decrypted sessions array
- [ ] `GET /api/interviews/[id]` — 401 no-auth, 404 wrong-user, 200 owner
- [ ] `POST /api/vitals` with bad payload → 400; with missing table → 204 silent
- [ ] `POST /api/stripe/webhook` with invalid signature → 400; with valid → 200
- [ ] Every POST/PUT/DELETE requires CSRF token (try with & without)
- [ ] HMAC-signed routes (`/api/stripe/checkout`, `/api/stripe/portal`, `/api/user/delete-account`, `/api/admin/users/*`) return 403 on unsigned requests

## 18. Security headers

- [ ] `Content-Security-Policy` present
- [ ] `Strict-Transport-Security` present (HTTPS only)
- [ ] `X-Frame-Options: DENY`
- [ ] `X-Content-Type-Options: nosniff`
- [ ] `Referrer-Policy: strict-origin-when-cross-origin`
- [ ] `Permissions-Policy` present
- [ ] (run `bun run test:e2e -- security-headers.spec.ts`)

## 19. Error handling

- [ ] `/error` route renders sanitized error
- [ ] Global error boundary catches component throws
- [ ] 404 page on unknown route
- [ ] API 500s log but never expose stack traces to client
- [ ] Rate-limit hit → 429 response + Retry-After header

## 20. Mobile + responsive

- [ ] iPhone 14 viewport: every screen readable, no horizontal scroll
- [ ] Hamburger menu opens + closes correctly
- [ ] Interview audio controls usable with touch
- [ ] Dictation modal fits on small screens

## 21. Observability

- [ ] Sentry / logger receives errors (trigger one on `/api/gemini` deliberately)
- [ ] PostHog events fire (or are blocked by consent correctly)
- [ ] Web vitals POSTs arrive (or silently 204 if migration not yet applied — acceptable)

## 22. Legal + marketing

- [ ] `/privacy` renders, reflects current processor list (Supabase, Stripe, Gemini, Resend, PostHog, Crisp)
- [ ] `/terms` renders
- [ ] `/imprint` (DE required) renders
- [ ] Cookie consent shows before any non-essential script loads

---

## Sign-off

Reviewer: ______________________   Date: ____________

Blocker count: ___   Ship? [ ] Yes  [ ] No — see bug list
