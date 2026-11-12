const STAFF_AUTH_PATH = '/api/v1/staff/auth'
const STAFF_REQUEST_TIMEOUT_MS = 15_000
const SAFE_PROBLEM_CODES = new Set([
  'access_expired',
  'authentication_required',
  'internal_error',
  'invalid_credentials',
  'request_too_large',
  'service_unavailable',
  'session_invalid',
  'staff_access_denied',
  'staff_origin_denied',
  'staff_request_denied',
  'staff_session_exists',
  'unsupported_media_type',
  'validation_error',
])

export interface StaffSessionView {
  user: {
    id: number
    email: string
    role: 'support_agent'
  }
  access_expires_at: string
  renewable_expires_at: string
  absolute_expires_at: string
}

export class StaffAuthApiError extends Error {
  readonly status: number
  readonly code: string
  readonly correlationId: string | null
  readonly retryAfterSeconds: number | null

  constructor(
    status: number,
    code: string,
    correlationId: string | null = null,
    retryAfterSeconds: number | null = null,
  ) {
    super('The staff authentication request could not be completed.')
    this.name = 'StaffAuthApiError'
    this.status = status
    this.code = code
    this.correlationId = correlationId
    this.retryAfterSeconds = retryAfterSeconds
  }
}

type MutationPath = 'login' | 'refresh' | 'logout'

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

export function parseStaffSessionView(value: unknown): StaffSessionView {
  if (!isRecord(value) || !isRecord(value.user)) {
    throw new StaffAuthApiError(0, 'invalid_response')
  }

  const { user } = value
  if (user.role !== 'support_agent') {
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
      role: 'support_agent',
    },
    access_expires_at: value.access_expires_at,
    renewable_expires_at: value.renewable_expires_at,
    absolute_expires_at: value.absolute_expires_at,
  }
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
  path: MutationPath | 'session',
  body: unknown,
  readResponse: (response: Response) => Promise<T>,
): Promise<T> {
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), STAFF_REQUEST_TIMEOUT_MS)
  const isMutation = path !== 'session'
  const headers = new Headers({
    Accept: 'application/json',
    'X-Staff-Request': '1',
  })
  if (isMutation) headers.set('Content-Type', 'application/json')

  try {
    const response = await fetch(`${STAFF_AUTH_PATH}/${path}`, {
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
      )
    }
    return await readResponse(response)
  } catch (error) {
    if (controller.signal.aborted) throw new StaffAuthApiError(0, 'request_timeout')
    if (error instanceof StaffAuthApiError) throw error
    throw new StaffAuthApiError(0, 'network_error')
  } finally {
    clearTimeout(timeoutId)
  }
}

async function readSession(response: Response): Promise<StaffSessionView> {
  try {
    return parseStaffSessionView(await response.json())
  } catch (error) {
    if (error instanceof StaffAuthApiError) throw error
    throw new StaffAuthApiError(0, 'invalid_response', response.headers.get('X-Correlation-ID'))
  }
}

export const staffAuthApi = {
  async login(email: string, password: string): Promise<StaffSessionView> {
    return request('login', { email, password }, readSession)
  },

  async session(): Promise<StaffSessionView> {
    return request('session', undefined, readSession)
  },

  async refresh(): Promise<StaffSessionView> {
    return request('refresh', {}, readSession)
  },

  async logout(): Promise<void> {
    return request('logout', {}, async (response) => {
      if (response.status !== 204) throw new StaffAuthApiError(0, 'invalid_response')
    })
  },
}

export const staffAuthTestHooks = {
  parseRetryAfter,
}
