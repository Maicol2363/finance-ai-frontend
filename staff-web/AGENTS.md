# Staff Web Agent Guide

This app is the React/Vite/TypeScript staff portal in the Flutter repository. It is a separate web target; preserve the Flutter app and its Android/Windows delivery behavior.

## Local work

- Use Node.js 22.22.2 or later and `npm ci` from `staff-web/`.
- Run `npm run lint`, `npm run typecheck`, `npm test`, and `npm run build` for changes here.
- Use the backend OpenAPI contract as the API authority. Do not invent endpoints, roles, authorization rules, or alternate validation rules.
- Keep secrets out of `VITE_*` settings and browser storage. The API base URL is public configuration. Access credentials may only be passed transiently in memory after an approved authentication flow exists.

## Scope and security

- SUP-01 is approved for implementation in the Support portal: show the backend-authorized global queue to `support_agent`, filter by the approved ticket states, claim only unassigned `open` tickets, transition successful claims to `in_progress`, and do not allow reassignment. Keep the queue projection limited and show ticket detail only after the backend authorizes the assigned agent.
- Admin and Auditor pages remain explicit placeholders with no live data or privileged actions until their stories and shared security prerequisites are approved.
- Do not simulate authentication or authorization. Enable staff sign-in only against the approved backend browser-session contract; the backend must enforce every protected operation.
- Staff authorization and ticket field visibility must be enforced by the backend; hidden navigation is not access control.
- Follow the approved role stories and shared security requirements. Do not add a general private-note or messaging feature.
- Keep frontend code and tooling under this directory. Preserve the Flutter workflows, platform code, and secure-storage contract.
