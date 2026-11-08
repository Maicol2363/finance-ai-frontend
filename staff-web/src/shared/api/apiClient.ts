const defaultBaseUrl = 'http://127.0.0.1:8000'

export class ApiClientError extends Error {
  readonly status: number
  readonly correlationId: string | null

  constructor(status: number, correlationId: string | null) {
    super('The API request could not be completed.')
    this.name = 'ApiClientError'
    this.status = status
    this.correlationId = correlationId
  }
}

export type ApiRequestOptions = Omit<RequestInit, 'body' | 'credentials' | 'headers'> & {
  body?: unknown
  headers?: HeadersInit
  accessCredential?: string
}

function getApiBaseUrl(): URL {
  const baseUrl = new URL(import.meta.env.VITE_FINANCE_AI_API_BASE_URL ?? defaultBaseUrl)
  if (
    !['http:', 'https:'].includes(baseUrl.protocol) ||
    baseUrl.username !== '' ||
    baseUrl.password !== ''
  ) {
    throw new Error('The configured API base URL is invalid.')
  }
  return baseUrl
}

export async function apiRequest<T>(path: string, options: ApiRequestOptions = {}): Promise<T> {
  const baseUrl = getApiBaseUrl()
  const requestUrl = new URL(path, baseUrl)
  if (requestUrl.origin !== baseUrl.origin) {
    throw new Error('API request paths must remain on the configured backend origin.')
  }

  const { accessCredential, ...requestOptions } = options
  const headers = new Headers(requestOptions.headers)
  headers.set('Accept', 'application/json')
  headers.set('X-Correlation-ID', crypto.randomUUID())
  if (requestOptions.body !== undefined) headers.set('Content-Type', 'application/json')
  if (accessCredential) {
    headers.set('Authorization', `Bearer ${accessCredential}`)
  }

  const response = await fetch(requestUrl, {
    ...requestOptions,
    body: requestOptions.body === undefined ? undefined : JSON.stringify(requestOptions.body),
    credentials: 'omit',
    headers,
  })
  if (!response.ok) {
    throw new ApiClientError(response.status, response.headers.get('X-Correlation-ID'))
  }
  if (response.status === 204) return undefined as T

  return (await response.json()) as T
}
