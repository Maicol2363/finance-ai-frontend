# FinanciAI Staff Web

React, TypeScript and Vite application for the internal Support Agent, Administrator and Security Auditor workspaces. It is a separate app under the Flutter repository and does not replace or change the Android/Windows client.

## Local setup

Requirements: Node.js 22.22.2 or later and npm.

On Linux, copy the example with cp .env.example .env.local. In Windows PowerShell, use Copy-Item .env.example .env.local. The commands below then work in either shell.

```sh
npm ci
cp .env.example .env.local
npm run dev
```

The Vite server binds to loopback at `http://127.0.0.1:5173`. Set `VITE_FINANCE_AI_API_BASE_URL` in `.env.local` to the backend origin if it differs from `http://127.0.0.1:8000`. Vite forwards browser requests to `/api/...` through its development proxy, so staff authentication remains same-origin in the browser. This is public configuration; never put secrets in `VITE_*` variables.

## Quality commands

```sh
npm run lint
npm run typecheck
npm test
npm run test:coverage
npm run test:e2e
npm run build
```

## Current boundary

The staff portal uses the approved cookie-backed browser-session contract. Staff auth requests use relative `/api/v1/staff/auth/...` paths with `credentials: include`; the browser always addresses the staff site itself. In development, Vite proxies `/api` to `VITE_FINANCE_AI_API_BASE_URL`. In production, the staff site's HTTPS ingress or reverse proxy must route `/api/` to the backend on the server side and preserve the request path, browser `Origin`, `X-Staff-Request`, `X-Correlation-ID`, cookies, and `Set-Cookie` attributes. Keep the staff UI and API under one browser origin; do not enable credentialed cross-origin CORS. Authentication and authorization remain enforced by the backend. The web app does not persist credentials or log request data.

The lockfile currently includes only the core React, Router, Vite, TypeScript, Tailwind and test tooling. Add server-state caching, form/validation packages, or charting only when an approved story uses them; no dashboard, business form, or Auditor chart is implemented in this scaffold.
