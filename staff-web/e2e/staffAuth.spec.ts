import { expect, test, type Page, type Route } from '@playwright/test'

const supportAgentSession = {
  user: { id: 73, email: 'support@example.test', role: 'support_agent' },
  access_expires_at: '2026-11-11T16:00:00Z',
  renewable_expires_at: '2026-11-12T16:00:00Z',
  absolute_expires_at: '2026-11-18T16:00:00Z',
}

async function respondProblem(route: Route, status: number, code: string): Promise<void> {
  await route.fulfill({
    status,
    contentType: 'application/problem+json',
    body: JSON.stringify({ code, status, title: 'Request denied' }),
  })
}

async function installUnauthenticatedRoutes(page: Page): Promise<void> {
  await page.route('**/api/v1/staff/auth/**', async (route) => {
    const request = route.request()
    if (request.url().endsWith('/session')) {
      await respondProblem(route, 401, 'session_invalid')
      return
    }
    await respondProblem(route, 401, 'invalid_credentials')
  })
}

function expectNoAuthStateInConsole(messages: string[]): void {
  expect(messages.join('\n')).not.toMatch(
    /support@example\.test|admin@example\.test|not-persisted-password|should-not-be-shared@example\.test|access_expires_at|renewable_expires_at|absolute_expires_at|access_token|refresh_token/i,
  )
}

test('direct protected navigation waits for server confirmation and redirects anonymous staff', async ({ page }) => {
  await installUnauthenticatedRoutes(page)
  await page.goto('/support')

  await expect(page.getByTestId('staff-sign-in-page')).toBeVisible()
  await expect(page.getByRole('heading', { name: 'Customer support' })).toHaveCount(0)
  await expect(page.getByLabel('Email')).toBeVisible()
  await expect(page.getByLabel('Password')).toBeVisible()
})

test('accepts only server-confirmed support agents and clears the protected view on logout', async ({ page }) => {
  let loggedIn = false
  const consoleMessages: string[] = []
  page.on('console', (message) => consoleMessages.push(message.text()))
  await page.route('**/api/v1/staff/auth/**', async (route) => {
    const request = route.request()
    const headers = request.headers()
    expect(headers['x-staff-request']).toBe('1')
    expect(headers.authorization).toBeUndefined()

    if (request.url().endsWith('/session')) {
      if (!loggedIn) await respondProblem(route, 401, 'session_invalid')
      else await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(supportAgentSession) })
      return
    }
    if (request.url().endsWith('/login')) {
      expect(request.postDataJSON()).toEqual({ email: 'support@example.test', password: 'not-persisted-password' })
      loggedIn = true
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(supportAgentSession) })
      return
    }
    if (request.url().endsWith('/logout')) {
      loggedIn = false
      await route.fulfill({ status: 204 })
      return
    }
    await respondProblem(route, 404, 'unknown_error')
  })

  await page.goto('/support')
  await page.getByLabel('Email').fill('support@example.test')
  await page.getByLabel('Password').fill('not-persisted-password')
  await page.getByRole('button', { name: 'Sign in' }).click()

  await expect(page.getByRole('heading', { name: 'Customer support' })).toBeVisible()
  await expect(page.getByText('support@example.test')).toBeVisible()
  expect(new URL(page.url()).pathname).toBe('/support')
  expect(new URL(page.url()).search).toBe('')
  expect(await page.evaluate(() => document.cookie)).toBe('')
  const sessionValues = await page.evaluate(() => Object.entries(sessionStorage))
  expect(sessionValues.every(([key, value]) => key === 'finance-ai-staff-logout-pending' && value === '1')).toBe(true)
  expect(sessionValues).toEqual([])
  expect(await page.evaluate(() => localStorage.length)).toBe(0)
  expectNoAuthStateInConsole(consoleMessages)

  await page.getByTestId('staff-sign-out-button').click()
  await expect(page.getByTestId('staff-sign-in-page')).toBeVisible()
  await expect(page.getByRole('heading', { name: 'Customer support' })).toHaveCount(0)
})

test('clears another tab’s protected view through the fixed safe broadcast message', async ({ page }) => {
  const context = page.context()
  const consoleMessages: string[] = []
  const installConsoleCheck = (target: Page) => target.on('console', (message) => consoleMessages.push(message.text()))
  installConsoleCheck(page)

  await context.route('**/api/v1/staff/auth/**', async (route) => {
    expect(route.request().headers().authorization).toBeUndefined()
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(supportAgentSession) })
  })
  const secondPage = await context.newPage()
  installConsoleCheck(secondPage)

  await Promise.all([page.goto('/support'), secondPage.goto('/support')])
  await Promise.all([
    expect(page.getByRole('heading', { name: 'Customer support' })).toBeVisible(),
    expect(secondPage.getByRole('heading', { name: 'Customer support' })).toBeVisible(),
  ])

  await page.evaluate(() => {
    const channel = new BroadcastChannel('finance-ai-staff-auth')
    channel.postMessage({ type: 'clear-protected-view', email: 'should-not-be-shared@example.test' })
    channel.close()
  })
  await expect(secondPage.getByRole('heading', { name: 'Customer support' })).toBeVisible()

  await page.evaluate(() => {
    const channel = new BroadcastChannel('finance-ai-staff-auth')
    channel.postMessage({ type: 'clear-protected-view' })
    channel.close()
  })

  await expect(secondPage.getByTestId('staff-sign-in-page')).toBeVisible()
  await expect(secondPage.getByRole('heading', { name: 'Customer support' })).toHaveCount(0)
  await expect(page.getByTestId('staff-sign-in-page')).toBeVisible()
  await expect(page.getByRole('heading', { name: 'Customer support' })).toHaveCount(0)
  expect(new URL(secondPage.url()).pathname).toBe('/login')
  expect(new URL(secondPage.url()).search).toBe('')
  expectNoAuthStateInConsole(consoleMessages)
})

test('hides protected content while visible-tab session revalidation is unresolved', async ({ page }) => {
  await page.clock.install()
  let loggedIn = false
  let sessionRequests = 0
  let finishRevalidation: (() => void) | undefined
  const pendingRevalidation = new Promise<void>((resolve) => { finishRevalidation = resolve })

  await page.route('**/api/v1/staff/auth/**', async (route) => {
    const request = route.request()
    if (request.url().endsWith('/session')) {
      sessionRequests += 1
      if (!loggedIn) {
        await respondProblem(route, 401, 'session_invalid')
        return
      }
      if (sessionRequests > 1) {
        await pendingRevalidation
        await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(supportAgentSession) })
        return
      }
    }
    if (request.url().endsWith('/login')) {
      loggedIn = true
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(supportAgentSession) })
      return
    }
    await respondProblem(route, 401, 'session_invalid')
  })

  await page.goto('/support')
  await page.getByLabel('Email').fill('support@example.test')
  await page.getByLabel('Password').fill('not-persisted-password')
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page.getByRole('heading', { name: 'Customer support' })).toBeVisible()

  await page.clock.fastForward(30_000)
  await expect.poll(() => sessionRequests).toBe(2)
  await expect(page.getByTestId('staff-auth-loading')).toBeVisible()
  await expect(page.getByRole('heading', { name: 'Customer support' })).toHaveCount(0)

  finishRevalidation?.()
  await expect(page.getByRole('heading', { name: 'Customer support' })).toBeVisible()
})

test('rejects an admin role returned by the session service', async ({ page }) => {
  await page.route('**/api/v1/staff/auth/**', async (route) => {
    if (route.request().url().endsWith('/session')) {
      await respondProblem(route, 401, 'session_invalid')
      return
    }
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        ...supportAgentSession,
        user: { ...supportAgentSession.user, role: 'admin' },
      }),
    })
  })

  await page.goto('/login')
  await page.getByLabel('Email').fill('admin@example.test')
  await page.getByLabel('Password').fill('not-persisted-password')
  await page.getByRole('button', { name: 'Sign in' }).click()

  await expect(page.getByTestId('staff-sign-in-page')).toBeVisible()
  await expect(page.getByRole('heading', { name: 'Customer support' })).toHaveCount(0)
  await expect(page.getByRole('alert')).toContainText('access is no longer available')
})

test('refreshes through C1 when the server reports an expired access session', async ({ page }) => {
  let sessionRequests = 0
  let refreshRequests = 0
  await page.route('**/api/v1/staff/auth/**', async (route) => {
    const request = route.request()
    expect(request.headers()['x-staff-request']).toBe('1')
    expect(request.headers().authorization).toBeUndefined()

    if (request.url().endsWith('/session')) {
      sessionRequests += 1
      await respondProblem(route, 401, 'access_expired')
      return
    }
    if (request.url().endsWith('/refresh')) {
      refreshRequests += 1
      expect(request.method()).toBe('POST')
      expect(request.postDataJSON()).toEqual({})
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(supportAgentSession) })
      return
    }
    await respondProblem(route, 404, 'unknown_error')
  })

  await page.goto('/support')

  await expect(page.getByRole('heading', { name: 'Customer support' })).toBeVisible()
  expect(sessionRequests).toBeGreaterThanOrEqual(1)
  expect(refreshRequests).toBe(1)
})

test('removes Support after timed revalidation receives a definitive denial', async ({ page }) => {
  await page.clock.install()
  let loggedIn = false
  let sessionRequests = 0
  await page.route('**/api/v1/staff/auth/**', async (route) => {
    const request = route.request()
    if (request.url().endsWith('/session')) {
      sessionRequests += 1
      if (!loggedIn) {
        await respondProblem(route, 401, 'session_invalid')
        return
      }
      if (sessionRequests > 1) {
        await respondProblem(route, 403, 'staff_access_denied')
        return
      }
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(supportAgentSession) })
      return
    }
    if (request.url().endsWith('/login')) {
      loggedIn = true
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(supportAgentSession) })
      return
    }
    await respondProblem(route, 404, 'unknown_error')
  })

  await page.goto('/support')
  await page.getByLabel('Email').fill('support@example.test')
  await page.getByLabel('Password').fill('not-persisted-password')
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page.getByRole('heading', { name: 'Customer support' })).toBeVisible()

  await page.clock.fastForward(30_000)

  await expect(page.getByTestId('staff-sign-in-page')).toBeVisible()
  await expect(page.getByRole('heading', { name: 'Customer support' })).toHaveCount(0)
  expect(sessionRequests).toBe(2)
})
