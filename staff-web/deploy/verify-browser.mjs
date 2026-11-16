import assert from 'node:assert/strict'
import process from 'node:process'
import { URL } from 'node:url'
import { chromium, expect } from '@playwright/test'

const origin = new URL(process.argv[2]).origin
assert.match(origin, /^https:\/\/[a-z0-9.-]+\.run\.app$/)

const browser = await chromium.launch()
try {
  for (const path of ['/', '/support', '/audit/events']) {
    const page = await browser.newPage()
    const errors = []
    const assets = new Set()
    page.on('pageerror', (error) => errors.push(error.message))
    page.on('console', (message) => {
      if (/content security policy|refused to load/i.test(message.text())) errors.push(message.text())
    })
    page.on('requestfailed', (request) => errors.push(new URL(request.url()).pathname))
    page.on('response', (response) => {
      const url = new URL(response.url())
      if (url.origin !== origin) errors.push('Unexpected external request')
      if (url.pathname.startsWith('/assets/') && response.ok()) assets.add(url.pathname)
    })
    for (const navigate of [() => page.goto(origin + path), () => page.reload()]) {
      const session = page.waitForResponse((res) => res.url() === origin + '/api/v1/staff/auth/session')
      const document = await navigate()
      assert.equal(document?.status(), 200)
      assert.equal((await session).status(), 401)
      await expect(page.getByTestId('staff-sign-in-page')).toBeVisible()
      const logo = page.getByTestId('staff-brand-logo')
      await expect.poll(() => logo.evaluate((image) => image.complete && image.naturalWidth > 0)).toBe(true)
      await expect(page).toHaveURL(origin + '/login')
      await expect(page.getByRole('navigation', { name: 'Navegación del personal' })).toHaveCount(0)
    }
    assert.ok([...assets].some((path) => path.endsWith('.js')))
    assert.ok([...assets].some((path) => path.endsWith('.css')))
    assert.deepEqual(errors, [])
    await page.close()
    process.stdout.write(`Browser smoke test passed for ${path}\n`)
  }
} finally {
  await browser.close()
}
