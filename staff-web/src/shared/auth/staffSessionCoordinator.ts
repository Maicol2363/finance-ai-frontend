import {
  isMfaChallenge,
  STAFF_AUTH_OPERATION_PATHS,
  StaffAuthApiError,
  staffAuthApi,
  type MfaResetProof,
  type StaffAuthOperation,
  type StaffMfaChallengeView,
  type StaffMfaEnrollmentView,
  type StaffSessionView,
} from '../api/staffAuthApi'

const PENDING_LOGOUT_MARKER = 'finance-ai-staff-logout-pending'
const AUTH_CHANNEL_NAME = 'finance-ai-staff-auth'
const REFRESH_LOCK_NAME = 'finance-ai-staff-refresh'
const REVALIDATION_INTERVAL_MS = 30_000
const DIAGNOSTIC_API_PATH = '/api/v1/staff/auth'
const SAFE_DIAGNOSTIC_CODES = new Set([
  'access_expired',
  'activation_invalid',
  'activation_password_invalid',
  'audit_unavailable',
  'authentication_required',
  'internal_error',
  'invalid_credentials',
  'invalid_response',
  'logout_unconfirmed',
  'mfa_already_enrolled',
  'mfa_challenge_invalid',
  'mfa_code_invalid',
  'mfa_enrollment_required',
  'mfa_rate_limited',
  'mfa_recovery_invalid',
  'mfa_unavailable',
  'password_confirmation_invalid',
  'request_invalid',
  'network_error',
  'request_timeout',
  'request_too_large',
  'route_not_found',
  'service_unavailable',
  'session_invalid',
  'staff_access_denied',
  'staff_origin_denied',
  'staff_request_denied',
  'staff_session_exists',
  'unknown_error',
  'unclassified_error',
  'unsupported_media_type',
  'validation_error',
])
const SAFE_DIAGNOSTIC_REASONS: Record<string, string> = {
  access_expired: 'access_expired',
  activation_invalid: 'activation_link_rejected',
  activation_password_invalid: 'activation_password_rejected',
  audit_unavailable: 'security_evidence_unavailable',
  authentication_required: 'authentication_required',
  internal_error: 'server_error',
  invalid_credentials: 'credentials_rejected',
  invalid_response: 'invalid_server_response',
  logout_unconfirmed: 'logout_unconfirmed',
  mfa_already_enrolled: 'mfa_already_enrolled',
  mfa_challenge_invalid: 'mfa_challenge_invalid',
  mfa_code_invalid: 'mfa_code_rejected',
  mfa_enrollment_required: 'mfa_enrollment_required',
  mfa_rate_limited: 'mfa_rate_limited',
  mfa_recovery_invalid: 'mfa_recovery_rejected',
  mfa_unavailable: 'mfa_unavailable',
  password_confirmation_invalid: 'password_confirmation_rejected',
  request_invalid: 'request_validation_failed',
  network_error: 'network_unavailable',
  request_timeout: 'request_timed_out',
  request_too_large: 'request_rejected',
  route_not_found: 'api_route_unavailable',
  service_unavailable: 'service_unavailable',
  session_invalid: 'session_invalid',
  staff_access_denied: 'staff_access_denied',
  staff_origin_denied: 'request_origin_denied',
  staff_request_denied: 'request_denied',
  staff_session_exists: 'staff_session_exists',
  unknown_error: 'unknown_error',
  unclassified_error: 'unclassified_error',
  unsupported_media_type: 'unsupported_request_format',
  validation_error: 'request_validation_failed',
}
const SAFE_CORRELATION_ID = /^[A-Za-z0-9._-]{1,64}$/

export interface StaffAuthDiagnostic {
  code: string
  operation: StaffAuthOperation
  occurredAtUtc: string
  platform: 'web'
  apiLocation: string
  correlationId: string | null
  reason: string
}

// MFA operations default to the real client so callers that only exercise password
// sessions can provide the four session methods.
type SessionApi = Pick<typeof staffAuthApi, 'login' | 'session' | 'refresh' | 'logout'> &
  Partial<Pick<typeof staffAuthApi, 'startMfaEnrollment' | 'verifyMfa' | 'cancelMfa' | 'resetMfa'>>
type AuthMessage = { type: 'clear-protected-view' }

export type StaffAuthState =
  | { status: 'restoring' }
  | { status: 'anonymous'; message?: string; diagnostic?: StaffAuthDiagnostic }
  | { status: 'authenticating' }
  | { status: 'authenticated'; session: StaffSessionView }
  | { status: 'refreshing' }
  | { status: 'recoverable_error'; message: string; retryAfterSeconds?: number; diagnostic?: StaffAuthDiagnostic }
  | { status: 'logout_pending'; message: string; diagnostic?: StaffAuthDiagnostic }
  | {
      status: 'mfa_required'
      challenge: StaffMfaChallengeView
      pending: boolean
      message?: string
      retryAfterSeconds?: number
      diagnostic?: StaffAuthDiagnostic
    }

function isStaffAuthOperation(value: unknown): value is StaffAuthOperation {
  return typeof value === 'string' && Object.hasOwn(STAFF_AUTH_OPERATION_PATHS, value)
}

/** Errors after which the second-factor step cannot continue: the person signs in again. */
function endsMfaStep(error: unknown): boolean {
  return (
    error instanceof StaffAuthApiError &&
    (error.code === 'mfa_challenge_invalid' ||
      error.code === 'staff_access_denied' ||
      error.code === 'staff_session_exists' ||
      error.code === 'session_invalid')
  )
}

export function safeStaffAuthDiagnostic(
  error: unknown,
  fallbackOperation: StaffAuthOperation,
  occurredAt = new Date(),
): StaffAuthDiagnostic {
  const errorCode = error instanceof StaffAuthApiError ? error.code : 'unclassified_error'
  const code = SAFE_DIAGNOSTIC_CODES.has(errorCode) ? errorCode : 'unknown_error'
  const safeFallbackOperation = isStaffAuthOperation(fallbackOperation) ? fallbackOperation : 'session'
  const operation = error instanceof StaffAuthApiError && isStaffAuthOperation(error.operation)
    ? error.operation
    : safeFallbackOperation
  const candidateCorrelationId = error instanceof StaffAuthApiError ? error.correlationId : null
  const correlationId = candidateCorrelationId && SAFE_CORRELATION_ID.test(candidateCorrelationId)
    ? candidateCorrelationId
    : null
  const validTime = Number.isFinite(occurredAt.getTime()) ? occurredAt : new Date()

  return {
    code,
    operation,
    occurredAtUtc: validTime.toISOString(),
    platform: 'web',
    apiLocation: `${DIAGNOSTIC_API_PATH}/${STAFF_AUTH_OPERATION_PATHS[operation]}`,
    correlationId,
    reason: SAFE_DIAGNOSTIC_REASONS[code] ?? SAFE_DIAGNOSTIC_REASONS.unclassified_error,
  }
}

const MFA_MESSAGES: Record<string, string> = {
  mfa_code_invalid: 'El código no es válido o ya se usó. Espera el siguiente código de tu aplicación e inténtalo de nuevo.',
  mfa_challenge_invalid: 'La verificación expiró o ya no es válida. Inicia sesión de nuevo con tu correo y contraseña.',
  mfa_enrollment_required: 'Primero configura tu aplicación de autenticación con el código QR.',
  mfa_already_enrolled: 'Tu autenticador ya está configurado. Ingresa el código que muestra.',
  mfa_unavailable: 'La verificación en dos pasos no está disponible en este momento. Inténtalo más tarde.',
  mfa_recovery_invalid: 'No se pudo verificar la recuperación. Revisa tu correo, tu contraseña y el código, o pide a un administrador que restablezca tu autenticador.',
}

export function safeStaffAuthMessage(
  error: unknown,
  context: 'login' | 'session' | 'logout' | 'mfa',
): string {
  if (!(error instanceof StaffAuthApiError)) {
    return 'Ocurrió un error. Inténtalo de nuevo.'
  }
  if (context === 'login' && error.code === 'invalid_credentials') {
    return 'No se pudo verificar el correo electrónico o la contraseña.'
  }
  const mfaMessage = MFA_MESSAGES[error.code]
  if (mfaMessage) return mfaMessage
  if (error.code === 'staff_session_exists') {
    return 'Ya hay una sesión del personal activa. Ciérrala allí y vuelve a intentarlo.'
  }
  if (error.code === 'staff_access_denied' || error.code === 'session_invalid') {
    return 'El acceso del personal ya no está disponible. Inicia sesión otra vez si aún tienes autorización.'
  }
  if (error.code === 'route_not_found') {
    return 'El servicio de autenticación no está disponible en este backend. Comparte el informe de diagnóstico con soporte.'
  }
  if (error.status === 429 && error.retryAfterSeconds) {
    return `Demasiados intentos. Vuelve a intentarlo en ${error.retryAfterSeconds} segundos.`
  }
  if (error.code === 'request_timeout' || error.code === 'network_error') {
    return 'No se pudo conectar con el servicio. Comprueba tu conexión e inténtalo de nuevo.'
  }
  if (context === 'logout') return 'No se pudo confirmar el cierre de sesión. Vuelve a intentarlo para completarlo.'
  return 'El servicio no está disponible temporalmente. Inténtalo de nuevo.'
}

function shouldRefresh(error: unknown): boolean {
  return (
    error instanceof StaffAuthApiError &&
    error.status === 401 &&
    (error.code === 'access_expired' || error.code === 'authentication_required')
  )
}

function isDefinitiveDenial(error: unknown): boolean {
  return (
    error instanceof StaffAuthApiError &&
    ((error.status === 401 && error.code === 'session_invalid') ||
      (error.status === 403 && error.code === 'staff_access_denied'))
  )
}

function readLogoutPending(storage: Storage | null): boolean {
  try {
    return storage?.getItem(PENDING_LOGOUT_MARKER) === '1'
  } catch {
    return false
  }
}

function writeLogoutPending(storage: Storage | null): void {
  try {
    storage?.setItem(PENDING_LOGOUT_MARKER, '1')
  } catch {
    // Keep the current tab blocked even when browser storage is unavailable.
  }
}

function clearLogoutPending(storage: Storage | null): void {
  try {
    storage?.removeItem(PENDING_LOGOUT_MARKER)
  } catch {
    // A stale marker also keeps the next page load fail-closed.
  }
}

export class StaffSessionCoordinator {
  private state: StaffAuthState = { status: 'restoring' }
  private session: StaffSessionView | null = null
  private readonly listeners = new Set<(state: StaffAuthState) => void>()
  private readonly api: SessionApi
  private readonly documentRef: Document | null
  private readonly storage: Storage | null
  private readonly locks: LockManager | null
  private readonly channelFactory: ((name: string) => BroadcastChannel | null) | null
  private channel: BroadcastChannel | null = null
  private timer: ReturnType<typeof setTimeout> | null = null
  private restorePromise: Promise<void> | null = null
  private refreshPromise: Promise<StaffSessionView> | null = null
  private logoutPromise: Promise<void> | null = null
  private authGeneration = 0
  private logoutPendingInMemory = false
  private started = false

  constructor(
    api: SessionApi = staffAuthApi,
    environment: {
      document?: Document | null
      storage?: Storage | null
      locks?: LockManager | null
      channelFactory?: ((name: string) => BroadcastChannel | null) | null
    } = {},
  ) {
    this.api = api
    this.documentRef = environment.document ?? (typeof document === 'undefined' ? null : document)
    this.storage = environment.storage ?? this.getSessionStorage()
    this.locks = environment.locks ?? this.getLockManager()
    this.channelFactory = environment.channelFactory === null
      ? null
      : environment.channelFactory ?? this.getChannelFactory()
  }

  get currentState(): StaffAuthState {
    return this.state
  }

  subscribe(listener: (state: StaffAuthState) => void): () => void {
    this.listeners.add(listener)
    listener(this.state)
    return () => this.listeners.delete(listener)
  }

  start(): () => void {
    if (!this.started) {
      this.started = true
      this.channel = this.channelFactory?.(AUTH_CHANNEL_NAME) ?? null
      this.channel?.addEventListener('message', this.handleBroadcast)
      this.documentRef?.addEventListener('visibilitychange', this.handleVisibilityChange)
      if (readLogoutPending(this.storage)) {
        this.logoutPendingInMemory = true
        this.setLogoutPendingState(true)
      } else {
        void this.restore()
      }
    }
    return () => this.stop()
  }

  stop(): void {
    this.started = false
    this.clearTimer()
    this.documentRef?.removeEventListener('visibilitychange', this.handleVisibilityChange)
    this.channel?.removeEventListener('message', this.handleBroadcast)
    this.channel?.close()
    this.channel = null
  }

  async login(email: string, password: string): Promise<void> {
    if (this.isLogoutPending()) {
      this.logoutPendingInMemory = true
      this.setLogoutPendingState(true)
      return
    }
    const generation = ++this.authGeneration
    this.restorePromise = null
    this.clearTimer()
    this.session = null
    this.setState({ status: 'authenticating' })
    try {
      const result = await this.api.login(email, password)
      if (generation !== this.authGeneration) return
      if (isMfaChallenge(result)) {
        this.setState({ status: 'mfa_required', challenge: result, pending: false })
        return
      }
      this.setAuthenticated(result)
    } catch (error) {
      if (generation !== this.authGeneration) return
      if (isDefinitiveDenial(error) || (error instanceof StaffAuthApiError && error.status === 401)) {
        this.setState({
          status: 'anonymous',
          message: safeStaffAuthMessage(error, 'login'),
          diagnostic: safeStaffAuthDiagnostic(error, 'login'),
        })
        return
      }
      this.setState({
        status: 'recoverable_error',
        message: safeStaffAuthMessage(error, 'login'),
        diagnostic: safeStaffAuthDiagnostic(error, 'login'),
      })
    }
  }

  /** Creates the pending authenticator. The secret is returned to the caller, never kept in state. */
  async startMfaEnrollment(): Promise<StaffMfaEnrollmentView | null> {
    const state = this.state
    if (state.status !== 'mfa_required' || state.pending) return null
    const generation = this.authGeneration
    this.setState({ status: 'mfa_required', challenge: state.challenge, pending: true })
    try {
      const enrollment = await (this.api.startMfaEnrollment ?? staffAuthApi.startMfaEnrollment)()
      if (generation !== this.authGeneration) return null
      this.setState({ status: 'mfa_required', challenge: state.challenge, pending: false })
      return enrollment
    } catch (error) {
      if (generation === this.authGeneration) this.handleMfaError(error, state.challenge, 'mfa_enrollment')
      return null
    }
  }

  async verifyMfa(code: string): Promise<void> {
    const state = this.state
    if (state.status !== 'mfa_required' || state.pending) return
    const generation = this.authGeneration
    this.setState({ status: 'mfa_required', challenge: state.challenge, pending: true })
    try {
      const session = await (this.api.verifyMfa ?? staffAuthApi.verifyMfa)(code)
      if (generation === this.authGeneration) this.setAuthenticated(session)
    } catch (error) {
      if (generation === this.authGeneration) this.handleMfaError(error, state.challenge, 'mfa_verify')
    }
  }

  /**
   * Lost-device recovery or authenticator replacement. Success revokes every session of the
   * account server-side and opens a fresh enrollment challenge, so the second-factor step
   * continues with enrollment; the credentials are never kept in state.
   */
  async resetMfa(email: string, password: string, proof: MfaResetProof): Promise<void> {
    if (this.isLogoutPending()) {
      this.logoutPendingInMemory = true
      this.setLogoutPendingState(true)
      return
    }
    const generation = ++this.authGeneration
    this.restorePromise = null
    this.clearTimer()
    this.session = null
    this.setState({ status: 'authenticating' })
    try {
      const challenge = await (this.api.resetMfa ?? staffAuthApi.resetMfa)(email, password, proof)
      if (generation !== this.authGeneration) return
      this.setState({ status: 'mfa_required', challenge, pending: false })
    } catch (error) {
      if (generation !== this.authGeneration) return
      const message = safeStaffAuthMessage(error, 'mfa')
      const diagnostic = safeStaffAuthDiagnostic(error, 'mfa_reset')
      this.setState(
        error instanceof StaffAuthApiError && error.status === 429 && error.retryAfterSeconds
          ? { status: 'recoverable_error', message, diagnostic, retryAfterSeconds: error.retryAfterSeconds }
          : { status: 'anonymous', message, diagnostic },
      )
    }
  }

  async cancelMfa(): Promise<void> {
    if (this.state.status !== 'mfa_required') return
    this.authGeneration += 1
    this.setState({ status: 'anonymous' })
    try {
      await (this.api.cancelMfa ?? staffAuthApi.cancelMfa)()
    } catch {
      // The challenge expires on its own and grants no authority; nothing else to undo.
    }
  }

  private handleMfaError(
    error: unknown,
    challenge: StaffMfaChallengeView,
    operation: 'mfa_enrollment' | 'mfa_verify',
  ): void {
    const message = safeStaffAuthMessage(error, 'mfa')
    const diagnostic = safeStaffAuthDiagnostic(error, operation)
    if (endsMfaStep(error)) {
      this.setState({ status: 'anonymous', message, diagnostic })
      return
    }
    const retryAfterSeconds = error instanceof StaffAuthApiError ? error.retryAfterSeconds : null
    this.setState({
      status: 'mfa_required',
      challenge,
      pending: false,
      message,
      diagnostic,
      ...(retryAfterSeconds ? { retryAfterSeconds } : {}),
    })
  }

  async restore(): Promise<void> {
    if (this.isLogoutPending()) {
      this.logoutPendingInMemory = true
      this.clearTimer()
      if (this.state.status !== 'logout_pending') this.setLogoutPendingState(true)
      return
    }
    if (this.restorePromise) return this.restorePromise
    const restore = this.performRestore()
    this.restorePromise = restore
    try {
      await restore
    } finally {
      if (this.restorePromise === restore) this.restorePromise = null
    }
  }

  private async performRestore(): Promise<void> {
    if (this.isLogoutPending()) {
      this.logoutPendingInMemory = true
      this.setLogoutPendingState(true)
      return
    }
    const generation = this.authGeneration
    const hadConfirmedSession = this.session !== null
    // Background revalidation of a confirmed session is silent: replacing the authenticated
    // state would unmount the workspace and discard open forms and one-time secrets.
    if (!hadConfirmedSession) this.setState({ status: 'restoring' })
    try {
      const session = await this.api.session()
      if (generation === this.authGeneration && !this.isLogoutPending()) this.setAuthenticated(session)
    } catch (error) {
      if (generation !== this.authGeneration || this.isLogoutPending()) return
      if (shouldRefresh(error)) {
        if (!hadConfirmedSession) this.setState({ status: 'refreshing' })
        try {
          const session = await this.coordinateRefresh()
          if (generation === this.authGeneration && !this.isLogoutPending()) this.setAuthenticated(session)
        } catch (refreshError) {
          if (generation !== this.authGeneration || this.isLogoutPending()) return
          this.handleSessionError(refreshError, hadConfirmedSession, 'refresh')
        }
        return
      }
      this.handleSessionError(error, hadConfirmedSession, 'session')
    }
  }

  async retry(): Promise<void> {
    if (this.state.status !== 'logout_pending') {
      await this.restore()
    }
  }

  async logout(): Promise<void> {
    if (this.isLogoutPending()) {
      this.logoutPendingInMemory = true
      if (this.state.status !== 'logout_pending') this.setLogoutPendingState(true)
      return
    }
    this.authGeneration += 1
    this.restorePromise = null
    this.clearTimer()
    this.session = null
    this.logoutPendingInMemory = true
    writeLogoutPending(this.storage)
    this.setState({ status: 'logout_pending', message: 'Cerrando sesión…' })
    await this.completeLogout()
  }

  async retryPendingLogout(): Promise<void> {
    if (this.state.status === 'logout_pending' || this.isLogoutPending()) {
      this.logoutPendingInMemory = true
      await this.completeLogout()
    }
  }

  private async completeLogout(): Promise<void> {
    if (!this.logoutPendingInMemory) return
    if (this.logoutPromise) return this.logoutPromise
    if (!readLogoutPending(this.storage)) writeLogoutPending(this.storage)
    const generation = this.authGeneration
    const attempt = (async () => {
      try {
        await this.api.logout()
        if (generation !== this.authGeneration) return
        this.logoutPendingInMemory = false
        clearLogoutPending(this.storage)
        this.session = null
        this.channel?.postMessage({ type: 'clear-protected-view' } satisfies AuthMessage)
        this.setState({ status: 'anonymous', message: 'Has cerrado sesión.' })
      } catch (error) {
        if (generation !== this.authGeneration) return
        this.logoutPendingInMemory = true
        writeLogoutPending(this.storage)
        this.setState({
          status: 'logout_pending',
          message: safeStaffAuthMessage(error, 'logout'),
          diagnostic: safeStaffAuthDiagnostic(error, 'logout'),
        })
      }
    })()
    this.logoutPromise = attempt
    try {
      await attempt
    } finally {
      if (this.logoutPromise === attempt) this.logoutPromise = null
    }
  }

  private async coordinateRefresh(): Promise<StaffSessionView> {
    if (this.refreshPromise) return this.refreshPromise

    const refresh = async (): Promise<StaffSessionView> => {
      if (!this.locks) return this.api.refresh()
      return this.locks.request(REFRESH_LOCK_NAME, { mode: 'exclusive' }, async () => {
        try {
          return await this.api.session()
        } catch (error) {
          if (!shouldRefresh(error)) throw error
          return this.api.refresh()
        }
      })
    }

    this.refreshPromise = refresh()
    try {
      return await this.refreshPromise
    } finally {
      this.refreshPromise = null
    }
  }

  private handleSessionError(
    error: unknown,
    hadConfirmedSession: boolean,
    operation: 'session' | 'refresh',
  ): void {
    if (isDefinitiveDenial(error)) {
      this.session = null
      this.clearTimer()
      // On first load, a missing access cookie can still have a valid refresh
      // cookie, so restoration must try refresh. If no refresh session exists,
      // `session_invalid` is simply an anonymous visit; keep the sign-in page
      // clear. Once this tab confirmed a session, continue explaining denials.
      const silentInitialInvalidSession =
        !hadConfirmedSession &&
        error instanceof StaffAuthApiError &&
        error.code === 'session_invalid'
      this.setState({
        status: 'anonymous',
        ...(!silentInitialInvalidSession && {
          message: safeStaffAuthMessage(error, 'session'),
          diagnostic: safeStaffAuthDiagnostic(error, operation),
        }),
      })
      return
    }
    const state: StaffAuthState = {
      status: 'recoverable_error',
      message: safeStaffAuthMessage(error, 'session'),
      diagnostic: safeStaffAuthDiagnostic(error, operation),
    }
    if (error instanceof StaffAuthApiError && error.retryAfterSeconds) {
      state.retryAfterSeconds = error.retryAfterSeconds
    }
    this.setState(state)
    if (hadConfirmedSession) this.scheduleRevalidation()
  }

  private setAuthenticated(session: StaffSessionView): void {
    this.session = session
    this.setState({ status: 'authenticated', session })
    this.scheduleRevalidation()
  }

  private setState(state: StaffAuthState): void {
    this.state = state
    for (const listener of this.listeners) listener(state)
  }

  private scheduleRevalidation(): void {
    this.clearTimer()
    if (!this.started || !this.session || this.isLogoutPending() || this.documentRef?.visibilityState === 'hidden') return
    this.timer = setTimeout(() => {
      this.timer = null
      void this.restore()
    }, REVALIDATION_INTERVAL_MS)
  }

  private clearTimer(): void {
    if (this.timer !== null) clearTimeout(this.timer)
    this.timer = null
  }

  private handleVisibilityChange = (): void => {
    if (this.documentRef?.visibilityState === 'hidden') {
      this.clearTimer()
      return
    }
    // Switching to an authenticator app must not discard the second-factor step.
    if (this.state.status === 'mfa_required') return
    if (this.isLogoutPending()) {
      this.logoutPendingInMemory = true
      if (this.state.status !== 'logout_pending') this.setLogoutPendingState(true)
      return
    }
    void this.restore()
  }

  private handleBroadcast = (event: MessageEvent<unknown>): void => {
    if (
      !isRecord(event.data) ||
      event.data.type !== 'clear-protected-view' ||
      Object.keys(event.data).length !== 1
    ) {
      return
    }
    this.authGeneration += 1
    this.clearTimer()
    this.logoutPendingInMemory = false
    this.session = null
    clearLogoutPending(this.storage)
    this.setState({ status: 'anonymous' })
  }

  private isLogoutPending(): boolean {
    return this.logoutPendingInMemory || readLogoutPending(this.storage)
  }

  private setLogoutPendingState(hasFailedAttempt: boolean): void {
    this.setState({
      status: 'logout_pending',
      message: 'No se pudo confirmar el cierre de sesión. Vuelve a intentarlo para completarlo.',
      ...(hasFailedAttempt && {
        diagnostic: safeStaffAuthDiagnostic(
          new StaffAuthApiError(0, 'logout_unconfirmed', null, null, 'logout'),
          'logout',
        ),
      }),
    })
  }

  private getSessionStorage(): Storage | null {
    try {
      return typeof sessionStorage === 'undefined' ? null : sessionStorage
    } catch {
      return null
    }
  }

  private getLockManager(): LockManager | null {
    return typeof navigator === 'undefined' ? null : (navigator.locks ?? null)
  }

  private getChannelFactory(): ((name: string) => BroadcastChannel | null) | null {
    return typeof BroadcastChannel === 'undefined' ? null : (name) => new BroadcastChannel(name)
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}
