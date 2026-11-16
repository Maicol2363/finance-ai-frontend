const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/

/** Reads the one-time token from the URL fragment (never sent to a server). */
export function readActivationToken(hash: string): string | null {
  const token = new URLSearchParams(hash.replace(/^#/, '')).get('token')
  return token !== null && TOKEN_PATTERN.test(token) ? token : null
}
