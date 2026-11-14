import { expect, test } from '@playwright/test'

test.afterEach(async ({ page }) => {
  if (!process.env.SUPPORT_DEMO_PASSWORD) return
  await page.request.post('http://127.0.0.1:4173/api/v1/staff/auth/logout', { headers: { 'X-Staff-Request': '1', Origin: 'http://127.0.0.1:4173' }, data: {} })
})

// Opt-in against compose.support-demo.yaml only. No authentication stubs.
test('real customer-agent conversation, resolution, escalation and denial', async ({ page, request }) => {
  test.skip(!process.env.SUPPORT_DEMO_PASSWORD, 'Requires the isolated support demo')
  const password = process.env.SUPPORT_DEMO_PASSWORD!
  const api = 'http://127.0.0.1:8001/api/v1'
  const login = await request.post(`${api}/auth/login`, { data: { email: 'cliente@example.test', password, platform: 'android' } })
  expect(login.status()).toBe(200)
  const credentials = await login.json() as { access_credential: string }
  const customerHeaders = { Authorization: `Bearer ${credentials.access_credential}` }
  const subject = `E2E soporte ${Date.now()}`
  const created = await request.post(`${api}/support/tickets`, { headers: customerHeaders, data: { subject, category: 'general', description: 'Descripción sintética' } })
  expect(created.status()).toBe(201)
  const ticket = await created.json() as { id: number }
  await page.goto('/login')
  await page.getByLabel(/Correo/i).fill('agente@example.test')
  await page.getByLabel(/Contraseña/i, { exact: true }).fill(password)
  await page.getByRole('button', { name: /Iniciar sesión/i }).click()
  await expect(page.getByRole('heading', { name: 'Atención al cliente' })).toBeVisible()
  const card = page.getByRole('listitem').filter({ has: page.getByRole('heading', { name: subject, exact: true }) })
  await card.getByRole('button', { name: 'Reclamar ticket' }).click()
  await expect(page.getByText('Identificador de cuenta', { exact: true })).toBeVisible()
  const response = await request.post(`${api}/support/tickets/${ticket.id}/messages`, { headers: customerHeaders, data: { body: 'Mensaje real del cliente <script>literal</script>' } })
  expect(response.status()).toBe(204)
  await page.getByRole('button', { name: 'Actualizar conversación' }).click()
  await expect(page.getByText('Mensaje real del cliente <script>literal</script>', { exact: true })).toBeVisible()
  await page.getByLabel('Mensaje al cliente').fill('Respuesta real del agente')
  await page.getByRole('button', { name: 'Enviar mensaje' }).click()
  await expect(page.getByText('Respuesta real del agente', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Enviar mensaje' })).toBeEnabled()
  await page.getByLabel('Resumen de resolución o motivo interno de escalamiento').fill('Resolución real de prueba')
  await expect(page.getByLabel('Resumen de resolución o motivo interno de escalamiento')).toHaveValue('Resolución real de prueba')
  await page.getByRole('button', { name: 'Resolver ticket' }).click()
  await expect(page.getByText('Resolución real de prueba', { exact: true })).toBeVisible()
  const customerView = await request.get(`${api}/support/tickets/${ticket.id}`, { headers: customerHeaders })
  const view = await customerView.json()
  expect(view.ticket.status).toBe('resolved')
  expect(view.ticket.resolution_summary).toBe('Resolución real de prueba')
  expect(view.messages).toHaveLength(2)
  expect((await request.post(`${api}/support/tickets/${ticket.id}/messages`, { headers: customerHeaders, data: { body: 'Respuesta tardía' } })).status()).toBe(409)
  expect((await request.get(`${api}/support/tickets/${ticket.id}`)).status()).toBe(401)

  await page.getByText('Crear ticket para un cliente', { exact: true }).click()
  await page.getByLabel('Correo exacto o identificador de cuenta').fill('cliente@example.test')
  await page.getByRole('button', { name: 'Verificar cliente' }).click()
  const escalatedSubject = `E2E escalamiento ${Date.now()}`
  await page.getByLabel('Asunto', { exact: true }).fill(escalatedSubject)
  await page.getByLabel('Descripción', { exact: true }).fill('Caso creado por agente')
  await page.getByRole('button', { name: 'Crear ticket', exact: true }).click()
  const nextCard = page.getByRole('listitem').filter({ has: page.getByRole('heading', { name: escalatedSubject, exact: true }) })
  await nextCard.getByRole('button', { name: 'Reclamar ticket' }).click()
  await page.getByLabel('Resumen de resolución o motivo interno de escalamiento').fill('Motivo interno E2E')
  await page.getByRole('button', { name: 'Escalar ticket' }).click()
  await expect(page.getByText('Este ticket está en modo de solo lectura.')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Enviar mensaje' })).toHaveCount(0)
  await page.getByRole('button', { name: /Cerrar sesión/i }).click()
})
