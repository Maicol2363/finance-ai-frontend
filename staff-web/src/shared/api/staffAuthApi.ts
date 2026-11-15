const STAFF_AUTH_PATH = '/api/v1/staff/auth'
const STAFF_REQUEST_TIMEOUT_MS = 15_000
const SAFE_PROBLEM_CODES = new Set([
  'access_expired',
  'activation_invalid',
  'activation_password_invalid',
  'audit_unavailable',
  'authentication_required',
  'internal_error',
  'invalid_credentials',
  'mfa_already_enrolled',
  'mfa_challenge_invalid',
  'mfa_code_invalid',
  'mfa_enrollment_required',
  'mfa_rate_limited',
  'mfa_recovery_invalid',
  'mfa_unavailable',
  'password_confirmation_invalid',
  'request_invalid',
  'request_too_large',
  'route_not_found',
  'service_unavailable',
  'session_invalid',
  'staff_access_denied',
  'staff_origin_denied',
  'staff_request_denied',
  'staff_session_exists',
  'unsupported_media_type',
  'validation_error',
])

/** The roles that may hold a staff portal session. Admin and auditor sessions are MFA-verified. */
export type StaffRole = 'support_agent' | 'security_auditor' | 'admin'
const STAFF_ROLES: ReadonlySet<string> = new Set<StaffRole>(['support_agent', 'security_auditor', 'admin'])

export interface StaffSessionView {
  user: {
    id: number
    email: string
    role: StaffRole
  }
  access_expires_at: string
  renewable_expires_at: string
  absolute_expires_at: string
}

/** Password accepted; the account must complete TOTP before it has any staff authority. */
export interface StaffMfaChallengeView {
  status: 'mfa_required'
  enrollment_required: boolean
  challenge_expires_at: string
}

/** Shown once inside the enrollment step; never stored by the browser. */
export interface StaffMfaEnrollmentView {
  issuer: string
  account_name: string
  secret: string
  otpauth_uri: string
  qr_svg_data_url: string
}

export type StaffLoginResult = StaffSessionView | StaffMfaChallengeView

export type StaffAuthOperation =
  | 'login'
  | 'session'
  | 'refresh'
  | 'logout'
  | 'mfa_enrollment'
  | 'mfa_verify'
  | 'mfa_cancel'
  | 'mfa_reset'
  | 'mfa_recovery_codes'
  | 'activate'

export const STAFF_AUTH_OPERATION_PATHS: Readonly<Record<StaffAuthOperation, string>> = {
  login: 'login',
  session: 'session',
  refresh: 'refresh',
  logout: 'logout',
  mfa_enrollment: 'mfa/enrollment',
  mfa_verify: 'mfa/verify',
  mfa_cancel: 'mfa/cancel',
  mfa_reset: 'mfa/reset',
  mfa_recovery_codes: 'mfa/recovery-codes',
  activate: 'activate',
}

export class StaffAuthApiError extends Error {
  readonly status: number
  readonly code: string
  readonly correlationId: string | null
  readonly retryAfterSeconds: number | null
  readonly operation: StaffAuthOperation | null

  constructor(
    status: number,
    code: string,
    correlationId: string | null = null,
    retryAfterSeconds: number | null = null,
    operation: StaffAuthOperation | null = null,
  ) {
    super('The staff authentication request could not be completed.')
    this.name = 'StaffAuthApiError'
    this.status = status
    this.code = code
    this.correlationId = correlationId
    this.retryAfterSeconds = retryAfterSeconds
    this.operation = operation
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function isValidDateTime(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/i.test(value) &&
    Number.isFinite(Date.parse(value))
  )
}

export function isStaffRole(value: unknown): value is StaffRole {
  return typeof value === 'string' && STAFF_ROLES.has(value)
}

export function parseStaffSessionView(value: unknown): StaffSessionView {
  if (!isRecord(value) || !isRecord(value.user)) {
    throw new StaffAuthApiError(0, 'invalid_response')
  }

  const { user } = value
  if (!isStaffRole(user.role)) {
    throw new StaffAuthApiError(403, 'staff_access_denied')
  }
  if (
    !Number.isSafeInteger(user.id) ||
    Number(user.id) < 1 ||
    typeof user.email !== 'string' ||
    !isValidDateTime(value.access_expires_at) ||
    !isValidDateTime(value.renewable_expires_at) ||
    !isValidDateTime(value.absolute_expires_at)
  ) {
    throw new StaffAuthApiError(0, 'invalid_response')
  }

  return {
    user: {
      id: Number(user.id),
      email: user.email,
      role: user.role,
    },
    access_expires_at: value.access_expires_at,
    renewable_expires_at: value.renewable_expires_at,
    absolute_expires_at: value.absolute_expires_at,
  }
}

export function parseStaffMfaChallenge(value: unknown): StaffMfaChallengeView {
  if (
    !isRecord(value) ||
    value.status !== 'mfa_required' ||
    typeof value.enrollment_required !== 'boolean' ||
    !isValidDateTime(value.challenge_expires_at)
  ) {
    throw new StaffAuthApiError(0, 'invalid_response')
  }
  return {
    status: 'mfa_required',
    enrollment_required: value.enrollment_required,
    challenge_expires_at: value.challenge_expires_at,
  }
}

const QR_DATA_URL_PREFIX = 'data:image/svg+xml;base64,'

export function parseStaffMfaEnrollment(value: unknown): StaffMfaEnrollmentView {
  if (
    !isRecord(value) ||
    typeof value.issuer !== 'string' ||
    typeof value.account_name !== 'string' ||
    typeof value.secret !== 'string' ||
    !/^[A-Z2-7]{16,128}$/.test(value.secret) ||
    typeof value.otpauth_uri !== 'string' ||
    !value.otpauth_uri.startsWith('otpauth://totp/') ||
    typeof value.qr_svg_data_url !== 'string' ||
    !value.qr_svg_data_url.startsWith(QR_DATA_URL_PREFIX) ||
    !/^[A-Za-z0-9+/]+=*$/.test(value.qr_svg_data_url.slice(QR_DATA_URL_PREFIX.length))
  ) {
    throw new StaffAuthApiError(0, 'invalid_response')
  }
  return {
    issuer: value.issuer,
    account_name: value.account_name,
    secret: value.secret,
    otpauth_uri: value.otpauth_uri,
    qr_svg_data_url: value.qr_svg_data_url,
  }
}

const RECOVERY_CODE_PATTERN = /^[A-Z2-7]{4}(?:-[A-Z2-7]{4}){3}$/

/** Single-use recovery codes are shown once; the browser never stores them. */
export function parseRecoveryCodes(value: unknown): string[] {
  if (!isRecord(value) || !Array.isArray(value.recovery_codes)) {
    throw new StaffAuthApiError(0, 'invalid_response')
  }
  const codes = value.recovery_codes
  if (
    codes.length < 1 ||
    codes.length > 20 ||
    !codes.every((code) => typeof code === 'string' && RECOVERY_CODE_PATTERN.test(code))
  ) {
    throw new StaffAuthApiError(0, 'invalid_response')
  }
  return codes as string[]
}

/** Exactly one proof of identity, besides the password, for an authenticator reset. */
export type MfaResetProof = { recoveryCode: string } | { code: string }

export function isMfaChallenge(result: StaffLoginResult): result is StaffMfaChallengeView {
  return 'status' in result && result.status === 'mfa_required'
}

function parseRetryAfter(value: string | null): number | null {
  if (!value) return null
  const seconds = Number(value)
  if (Number.isFinite(seconds)) return Math.min(86_400, Math.max(1, Math.ceil(seconds)))
  const dateMilliseconds = Date.parse(value)
  if (!Number.isFinite(dateMilliseconds)) return null
  return Math.min(86_400, Math.max(1, Math.ceil((dateMilliseconds - Date.now()) / 1000)))
}

async function readProblemCode(response: Response): Promise<string> {
  try {
    const body: unknown = await response.json()
    if (isRecord(body) && typeof body.code === 'string' && SAFE_PROBLEM_CODES.has(body.code)) {
      return body.code
    }
  } catch {
    // A malformed error body is represented by one generic code.
  }
  return 'unknown_error'
}

async function request<T>(
  operation: StaffAuthOperation,
  body: unknown,
  readResponse: (response: Response) => Promise<T>,
): Promise<T> {
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), STAFF_REQUEST_TIMEOUT_MS)
  const isMutation = operation !== 'session'
  const headers = new Headers({
    Accept: 'application/json',
    'X-Staff-Request': '1',
  })
  if (isMutation) headers.set('Content-Type', 'application/json')

  try {
    const response = await fetch(`${STAFF_AUTH_PATH}/${STAFF_AUTH_OPERATION_PATHS[operation]}`, {
      method: isMutation ? 'POST' : 'GET',
      body: isMutation ? JSON.stringify(body ?? {}) : undefined,
      cache: 'no-store',
      credentials: 'include',
      headers,
      signal: controller.signal,
    })
    if (!response.ok) {
      throw new StaffAuthApiError(
        response.status,
        await readProblemCode(response),
        response.headers.get('X-Correlation-ID'),
        parseRetryAfter(response.headers.get('Retry-After')),
        operation,
      )
    }
    return await readResponse(response)
  } catch (error) {
    if (controller.signal.aborted) throw new StaffAuthApiError(0, 'request_timeout', null, null, operation)
    if (error instanceof StaffAuthApiError) {
      throw new StaffAuthApiError(error.status, error.code, error.correlationId, error.retryAfterSeconds, operation)
    }
    throw new StaffAuthApiError(0, 'network_error', null, null, operation)
  } finally {
    clearTimeout(timeoutId)
  }
}

async function readJson<T>(response: Response, parse: (value: unknown) => T): Promise<T> {
  try {
    return parse(await response.json())
  } catch (error) {
    if (error instanceof StaffAuthApiError) throw error
    throw new StaffAuthApiError(0, 'invalid_response', response.headers.get('X-Correlation-ID'))
  }
}

async function readSession(response: Response): Promise<StaffSessionView> {
  return readJson(response, parseStaffSessionView)
}

async function readLogin(response: Response): Promise<StaffLoginResult> {
  if (response.status === 202) return readJson(response, parseStaffMfaChallenge)
  return readSession(response)
}

async function readNoContent(response: Response): Promise<void> {
  if (response.status !== 204) throw new StaffAuthApiError(0, 'invalid_response')
}

export const staffAuthApi = {
  /** Support Agents receive a session; MFA roles receive a second-factor challenge (HTTP 202). */
  async login(email: string, password: string): Promise<StaffLoginResult> {
    return request('login', { email, password }, readLogin)
  },

  async session(): Promise<StaffSessionView> {
    return request('session', undefined, readSession)
  },

  async refresh(): Promise<StaffSessionView> {
    return request('refresh', {}, readSession)
  },

  async logout(): Promise<void> {
    return request('logout', {}, readNoContent)
  },

  async startMfaEnrollment(): Promise<StaffMfaEnrollmentView> {
    return request('mfa_enrollment', {}, (response) => readJson(response, parseStaffMfaEnrollment))
  },

  async verifyMfa(code: string): Promise<StaffSessionView> {
    return request('mfa_verify', { code }, readSession)
  },

  async cancelMfa(): Promise<void> {
    return request('mfa_cancel', {}, readNoContent)
  },

  /** Lost-device recovery or voluntary replacement; success opens a new enrollment challenge. */
  async resetMfa(email: string, password: string, proof: MfaResetProof): Promise<StaffMfaChallengeView> {
    const body = 'recoveryCode' in proof
      ? { email, password, recovery_code: proof.recoveryCode }
      : { email, password, code: proof.code }
    return request('mfa_reset', body, (response) => readJson(response, parseStaffMfaChallenge))
  },

  /** Replaces the single-use recovery codes after re-confirming the password. */
  async issueRecoveryCodes(password: string): Promise<string[]> {
    return request('mfa_recovery_codes', { password }, (response) => readJson(response, parseRecoveryCodes))
  },

  /** Public: consumes an invitation token and creates the invited staff account. */
  async activate(token: string, password: string, passwordConfirmation: string): Promise<void> {
    return request(
      'activate',
      { token, password, password_confirmation: passwordConfirmation },
      readNoContent,
    )
  },
}

export const staffAuthTestHooks = {
  parseRetryAfter,
}
