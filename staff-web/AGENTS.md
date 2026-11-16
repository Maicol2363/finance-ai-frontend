# Staff Web Agent Guide

This app is the React/Vite/TypeScript staff portal in the Flutter repository. It is a separate web target; preserve the Flutter app and its Android/Windows delivery behavior.

## Local work

- Use Node.js 22.22.2 or later and `npm ci` from `staff-web/`.
- Run `npm run lint`, `npm run typecheck`, `npm test`, and `npm run build` for changes here.
- Use the backend OpenAPI contract as the API authority. Do not invent endpoints, roles, authorization rules, or alternate validation rules.
- Keep secrets out of `VITE_*` settings and browser storage. The API base URL is public configuration. Access credentials may only be passed transiently in memory after an approved authentication flow exists.

## Scope and security

- PB-012 SUP-02–SUP-06 and its Flutter dependencies are authorized by the 2026-11-14 implementation request. Use the backend creation, restricted lookup, conversation, escalation and resolution contracts; preserve staff-only internal reasons and never add administrative operations here.
- SUP-01 is approved for implementation in the Support portal: show the backend-authorized global queue to `support_agent`, filter by the approved ticket states, claim only unassigned `open` tickets, transition successful claims to `in_progress`, and do not allow reassignment. Keep the queue projection limited and show ticket detail only after the backend authorizes the assigned agent.
- PB-016 AUD-01–AUD-04 are implemented for `security_auditor` under `src/features/audit/` (events, detail, investigation, summary, PDF reports) with the password+TOTP step in `src/features/auth/MfaStep.tsx`. Every view is read-only; never add administrative, account, ticket or evidence-mutation actions there. Keep enrollment secrets in component memory only.
- Each staff role sees only its own workspace (`RequireStaffRole`, `src/shared/auth/roleHome.ts`); another role gets a no-data denial page.
- ADM-01–ADM-05 are implemented for `admin` under `src/features/admin/` (account lookup and suspension, staff invitations and role changes, escalated cases, recovery codes) against `/api/v1/staff/admin`; the backend enforces the active admin role, MFA-verified session and ownership on every call. Administrators use the same password+TOTP step as auditors. Keep activation tokens (URL fragment only), recovery codes and enrollment secrets in component memory; never add portal admin grants or revocations, billing, infrastructure settings, financial-record access or general internal notes. Admin navigation links must stay absolute (relative links inside the `admin/*` splat route resolve against the current sub-page).
- `/activate` (single-use staff invitation) and `/recover` (authenticator recovery) are the only public staff routes besides sign-in. Every failure that depends on the token or the account collapses to one generic message (activation: unknown, malformed, expired and replayed links; recovery: wrong email, password or proof). Only outcomes that cannot reveal that (password policy, which the backend checks before the token; rate limits; transport errors) have their own wording. Failures carry the copyable diagnostic report (`AuthDiagnosticPanel`) and never the token, password or codes.
- Protected content is visible only while the session is confirmed. While an already authenticated view is re-confirmed (the 30 s revalidation, a returning tab, a renewal) `RequireStaffSession` hides it at once (`visibility: hidden`, `inert`, `aria-hidden`) and shows a loading notice, but keeps it mounted so a quick revalidation does not discard open forms or one-time secrets held in memory; focus returns to the last field. A definitive denial or a recoverable error unmounts it. Never make revalidation silent: `e2e/staffAuth.spec.ts` asserts the content is hidden while revalidation is unresolved.
- Administrator failures use `useAdminFailure` (re-confirms the session after a 401/403) and `AdminFailureNotice` (safe message, code, correlation reference and a copyable report with allow-listed fields only: no emails, typed reasons, conversation text, ids in the path, cookies or tokens).
- Do not simulate authentication or authorization. Enable staff sign-in only against the approved backend browser-session contract; the backend must enforce every protected operation.
- Staff authorization and ticket field visibility must be enforced by the backend; hidden navigation is not access control.
- Follow the approved role stories and shared security requirements. Do not add a general private-note or messaging feature.
- Keep frontend code and tooling under this directory. Preserve the Flutter workflows, platform code, and secure-storage contract.
