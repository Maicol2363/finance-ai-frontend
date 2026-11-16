import type { StaffRole } from '../api/staffAuthApi'

/** Each staff role has exactly one workspace. Navigation is presentation; the backend authorizes. */
export const ROLE_HOME: Readonly<Record<StaffRole, string>> = {
  support_agent: '/support',
  security_auditor: '/audit',
  admin: '/admin',
}

/** Honour a requested return path only when it stays inside the role's own workspace. */
export function roleDestination(role: StaffRole, requested: unknown): string {
  const home = ROLE_HOME[role]
  if (typeof requested === 'string' && (requested === home || requested.startsWith(`${home}/`))) return requested
  return home
}
