# Production Hardening Sweep — 10 Steps

**Runner contract:** This file is consumed by `nightshift-bulletproof.sh`. Each step is one atomic commit. The parser extracts steps numbered `### Step N — {title}` and reads the indented body until the next `### Step` or `## Category` header.

**Agent Instructions:** For each step:

1. Implement the change exactly as described.
2. Run the **code validation gate**: lint → type-check → tests → build.
3. For UI-touching steps, run Chrome QA and emit `CHROME_VERDICT: PASS` (with evidence) or `CHROME_VERDICT: FAIL`.
4. On success, commit with message `nightshift(step-N): {title}`.
5. On failure after exhausted retries, commit with ` — NEEDS MANUAL REVIEW` suffix.

---

## Category 1 — Security Headers

### Step 1 — Add Content-Security-Policy header

**Implementation:** In `next.config.ts` (or your framework's equivalent), add a CSP header to every response. Start strict: `default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://api.your-domain.com; font-src 'self' data:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'`. Adjust hosts to match your real third-party deps (Stripe, PostHog, Sentry, etc).

**Validation:** Add `e2e/security-headers.spec.ts` that fetches `/` and asserts the response has a `Content-Security-Policy` header matching the expected policy. Verify in the browser that no CSP violations appear in console on the landing page.

### Step 2 — Add HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy

**Implementation:** In the same `next.config.ts` headers array, add: `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: camera=(), microphone=(), geolocation=()`.

**Validation:** Extend `e2e/security-headers.spec.ts` to assert each header is present with the expected value.

## Category 2 — Auth Hardening

### Step 3 — Rate limit /api/auth/* endpoints

**Implementation:** Wrap every route under `src/app/api/auth/` with a rate limiter (use existing `src/lib/rate-limit.ts` or Upstash). Limits: signup 3/min/IP, login 10/min/IP, password-reset 3/min/IP. Return 429 with `Retry-After` header on limit hit.

**Validation:** Add `src/lib/__tests__/rate-limit.test.ts` (or extend) that fires 11 requests in quick succession against a mocked login route and asserts the 11th returns 429 with a `Retry-After` header.

### Step 4 — Enforce password complexity on signup

**Implementation:** In the signup Zod schema (likely `src/lib/validations.ts`), require: min 12 chars, at least 1 lowercase, 1 uppercase, 1 digit. Surface a clear error message inline on the signup form, not a generic "validation failed".

**Validation:** Unit test the Zod schema with 5 valid passwords and 5 invalid (too short, all lowercase, no digits, etc). Assert each produces the expected pass/fail.

### Step 5 — Add httpOnly + sameSite=lax + secure cookies on session

**Implementation:** Audit every `cookies().set(...)` call. Ensure every session-related cookie has `httpOnly: true`, `sameSite: 'lax'`, `secure: process.env.NODE_ENV === 'production'`. Document any exception with a code comment explaining why.

**Validation:** Add `e2e/session-cookie.spec.ts` that signs in a test user, then asserts the session cookie has all three attributes set when inspected via `context.cookies()`.

## Category 3 — Observability

### Step 6 — Wire Sentry into global error boundary

**Implementation:** In `src/components/error-boundary.tsx`, in `componentDidCatch`, call `Sentry.captureException(error, { contexts: { errorInfo } })`. Add `Sentry.init({...})` in `instrumentation.ts` (or `sentry.client.config.ts` depending on framework version) with `tracesSampleRate: 0.1` for production.

**Validation:** Add `src/components/__tests__/error-boundary.test.tsx` that mocks `Sentry.captureException`, renders a child that throws, and asserts `captureException` was called with the thrown error.

### Step 7 — Log every API 500 with request context

**Implementation:** Wrap every API route handler with a top-level try/catch (or use a shared `withErrorHandler` helper). On 500, log: route, method, status, user ID (if authenticated), trace ID, error message + stack. Never send the stack to the client.

**Validation:** Add `src/lib/__tests__/with-error-handler.test.ts` that wraps a handler that throws, calls it, and asserts (a) the response is 500 without stack in body, (b) the logger was called with the expected context.

## Category 4 — Performance

### Step 8 — Lazy-load heavy components below the fold

**Implementation:** Identify the 3 largest components currently imported in `src/app/page.tsx` (use `next build` output). Convert each to `dynamic(() => import('...'), { ssr: false })` and confirm they only render when scrolled into view via `IntersectionObserver` or `react-intersection-observer`.

**Validation:** Run `npm run build` and assert the initial bundle for `/` is smaller than the baseline (capture the baseline first). Add a Playwright test asserting the heavy component is not in the DOM until you scroll to it.

### Step 9 — Cache static API responses

**Implementation:** For every `GET /api/*` route that returns content not tied to a user, add `Cache-Control: public, max-age=60, stale-while-revalidate=300`. Identify these routes by reading every file under `src/app/api/` and checking which don't access session/cookies.

**Validation:** Add an integration test that hits each cacheable route and asserts the `Cache-Control` header matches the policy.

## Category 5 — Legal + Compliance

### Step 10 — Cookie consent gates non-essential scripts

**Implementation:** In `src/components/cookie-consent.tsx`, ensure that PostHog/analytics/marketing scripts are gated behind explicit user opt-in. Until the user clicks "Accept", these scripts must not load. Use a state machine: `unknown` → `denied` | `accepted`. Persist the choice to `localStorage`.

**Validation:** Add `e2e/cookie-consent.spec.ts` that visits the landing page in incognito, opens devtools network panel, asserts no requests to `app.posthog.com` (or your analytics host) before clicking accept, then clicks accept and asserts the analytics request fires.
