import { expect, test } from '@playwright/test'

const session = {
  user: { id: 73, email: 'support@example.test', role: 'support_agent' },
  access_expires_at: '2026-11-11T16:00:00Z',
  renewable_expires_at: '2026-11-12T16:00:00Z',
  absolute_expires_at: '2026-11-18T16:00:00Z',
}

const queueTicket = {
  id: 501,
  subject: 'No puedo actualizar mi perfil',
  status: 'open',
  created_at: '2026-11-12T12:00:00Z',
  assigned_staff_user_id: null,
}

test('claims a ticket and reveals its details only after the server grants assignment', async ({ page }) => {
  let assigned = false
  await page.route('**/api/v1/staff/auth/session', async (route) => {
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(session) })
  })
  await page.route('**/api/v1/staff/support/tickets**', async (route) => {
    const request = route.request()
    expect(request.headers()['x-staff-request']).toBe('1')
    expect(request.headers().authorization).toBeUndefined()
    if (request.method() === 'GET' && request.url().endsWith('/tickets')) {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([queueTicket]) })
      return
    }
    if (request.method() === 'POST' && request.url().endsWith('/501/claim')) {
      assigned = true
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ ...queueTicket, status: 'in_progress', assigned_staff_user_id: 73 }) })
      return
    }
    if (request.method() === 'GET' && request.url().endsWith('/501')) {
      if (!assigned) {
        await route.fulfill({ status: 404, contentType: 'application/problem+json', body: JSON.stringify({ code: 'support_ticket_not_found' }) })
        return
      }
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ ...queueTicket, status: 'in_progress', assigned_staff_user_id: 73, category: 'general', description: 'Contexto privado disponible tras la asignación.' }) })
      return
    }
    await route.fulfill({ status: 404, contentType: 'application/problem+json', body: JSON.stringify({ code: 'unknown_error' }) })
  })

  await page.goto('/support')
  await expect(page.getByRole('heading', { name: 'No puedo actualizar mi perfil' })).toBeVisible()
  await expect(page.getByText('Contexto privado disponible tras la asignación.')).toHaveCount(0)
  await page.getByRole('button', { name: 'Reclamar ticket' }).click()
  await expect(page.getByText('Contexto privado disponible tras la asignación.')).toBeVisible()
  await expect(page.getByText('En atención').first()).toBeVisible()
})

test('explains a concurrent claim conflict and reloads server assignment', async ({ page }) => {
  await page.route('**/api/v1/staff/auth/session', async (route) => {
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(session) })
  })
  await page.route('**/api/v1/staff/support/tickets**', async (route) => {
    if (route.request().method() === 'POST') {
      await route.fulfill({ status: 409, contentType: 'application/problem+json', body: JSON.stringify({ code: 'support_ticket_claim_conflict' }) })
      return
    }
    const ticket = { ...queueTicket, assigned_staff_user_id: route.request().url().includes('refresh=1') ? 88 : null }
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([ticket]) })
  })

  await page.goto('/support')
  await page.getByRole('button', { name: 'Reclamar ticket' }).click()
  await expect(page.getByText(/Otro agente reclamó este ticket primero/)).toBeVisible()
})
