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

The Vite server binds to loopback at `http://127.0.0.1:5173`. Set `VITE_FINANCE_AI_API_BASE_URL` in `.env.local` to the local backend URL if it differs from `http://127.0.0.1:8000`. This value is public and compiled into browser code; never put secrets in `VITE_*` variables.

## Quality commands

```sh
npm run lint
npm run typecheck
npm test
npm run build
```

## Current boundary

This is a navigation and component foundation only. Workspaces display no live user or staff data and perform no privileged actions. Browser sign-in stays unavailable until the backend defines and implements a secure browser-session contract. The API client omits cookies, does not persist access credentials, and never logs request data. Implement each role's approved stories in its own feature branch after the shared backend contracts are ready.

The lockfile currently includes only the core React, Router, Vite, TypeScript, Tailwind and test tooling. Add server-state caching, form/validation packages, or charting only when an approved story uses them; no dashboard, business form, or Auditor chart is implemented in this scaffold.
