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
  const file = { name: 'evidencia.pdf', mimeType: 'application/pdf', buffer: Buffer.from('%PDF-1.7\nQA') }
  const image = {
    name: 'tmp_legacy.png',
    content: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGMQqo0BAAGQAOzY5F2BAAAAAElFTkSuQmCC',
  }
  const created = await request.post(`${api}/support/tickets`, { headers: customerHeaders, data: { subject, category: 'general', description: 'Descripción sintética', attachment: image } })
  expect(created.status()).toBe(201)
  const ticket = await created.json() as { id: number }
  await page.goto('/login')
  await page.getByLabel(/Correo/i).fill(process.env.SUPPORT_DEMO_AGENT || 'agente@example.test')
  await page.getByLabel(/Contraseña/i, { exact: true }).fill(password)
  await page.getByRole('button', { name: /Iniciar sesión/i }).click()
  await expect(page.getByRole('heading', { name: 'Atención al cliente' })).toBeVisible()
  const card = page.getByRole('listitem').filter({ has: page.getByRole('heading', { name: subject, exact: true }) })
  await card.getByRole('button', { name: 'Reclamar ticket' }).click()
  const context = page.getByRole('dialog', { name: 'Contexto del ticket' })
  await expect(context).toBeVisible()
  await context.getByText('Cliente e historial', { exact: true }).click()
  await expect(context.getByText('Identificador de cuenta', { exact: true })).toBeVisible()
  await context.getByText('Cliente e historial', { exact: true }).click()
  await page.keyboard.press('Escape')
  await expect(context).toBeVisible()
  await expect(page).toHaveURL(new RegExp(`ticket=${ticket.id}$`))
  await page.reload()
  await expect(context.getByRole('heading', { name: subject, exact: true })).toBeVisible()
  const preview = context.getByRole('img', { name: image.name })
  await expect(preview).toBeVisible()
  await expect.poll(() => preview.evaluate((element: HTMLImageElement) => element.naturalWidth)).toBe(1)
  await context.getByRole('button', { name: `Abrir imagen ${image.name}` }).click()
  const viewer = page.getByRole('dialog', { name: `Imagen ${image.name}`, exact: true })
  await expect(viewer).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(viewer).not.toBeVisible()
  await expect(context.getByRole('button', { name: `Abrir imagen ${image.name}` })).toBeFocused()
  const download = page.waitForEvent('download')
  await context.getByRole('button', { name: `Descargar ${image.name}` }).click()
  const saved = await download
  expect(saved.suggestedFilename()).toBe(image.name)
  const stream = await saved.createReadStream()
  const chunks: Buffer[] = []
  for await (const chunk of stream!) chunks.push(Buffer.from(chunk))
  expect(Buffer.concat(chunks)).toEqual(Buffer.from(image.content, 'base64'))
  const response = await request.post(`${api}/support/tickets/${ticket.id}/messages`, { headers: customerHeaders, data: { body: 'Mensaje real del cliente <script>literal</script>', attachment: { ...image, name: 'mensaje.png' } } })
  expect(response.status()).toBe(204)
  await expect(context.getByText('Mensaje real del cliente <script>literal</script>', { exact: true })).toBeVisible({ timeout: 12000 })
  const messageImage = context.getByRole('img', { name: 'mensaje.png', exact: true })
  await expect.poll(() => messageImage.evaluate((element: HTMLImageElement) => element.naturalWidth)).toBe(1)
  await context.getByRole('button', { name: 'Abrir imagen mensaje.png' }).click()
  await page.getByRole('dialog', { name: 'Imagen mensaje.png', exact: true }).getByRole('button', { name: 'Cerrar imagen' }).click()
  await expect(context).toBeVisible()
  await page.getByLabel('Mensaje al cliente').fill('Respuesta real del agente')
  const recheck = page.waitForResponse(response => response.url().endsWith('/staff/auth/session'))
  await page.evaluate(() => document.dispatchEvent(new Event('visibilitychange')))
  expect((await recheck).status()).toBe(200)
  await expect(context).toBeVisible()
  await expect(context.getByLabel('Mensaje al cliente')).toHaveValue('Respuesta real del agente')
  await context.locator('.support-case input[type=file]').setInputFiles({ ...file, name: 'respuesta.pdf' })
  await page.getByRole('button', { name: 'Enviar mensaje' }).click()
  await expect(page.getByText('Respuesta real del agente', { exact: true })).toBeVisible()
  await context.getByText('Gestionar ticket', { exact: true }).click()
  await page.getByLabel('Resumen de resolución').fill('Resolución real de prueba')
  await expect(page.getByLabel('Resumen de resolución')).toHaveValue('Resolución real de prueba')
  const resolution = page.waitForResponse((response) =>
    response.url().endsWith(`/staff/support/tickets/${ticket.id}/resolve`) &&
    response.request().method() === 'POST')
  await page.getByRole('button', { name: 'Resolver ticket' }).click()
  expect((await resolution).status()).toBe(204)
  await expect(page.getByText('Resolución real de prueba', { exact: true })).toBeVisible()
  const customerView = await request.get(`${api}/support/tickets/${ticket.id}`, { headers: customerHeaders })
  const view = await customerView.json()
  expect(view.ticket.status).toBe('resolved')
  expect(view.ticket.resolution_summary).toBe('Resolución real de prueba')
  expect(view.messages).toHaveLength(2)
  expect(view.attachments.map((attachment: { name: string }) => attachment.name)).toEqual([image.name, 'mensaje.png', 'respuesta.pdf'])
  expect((await request.post(`${api}/support/tickets/${ticket.id}/messages`, { headers: customerHeaders, data: { body: 'Respuesta tardía' } })).status()).toBe(409)
  expect((await request.get(`${api}/support/tickets/${ticket.id}`)).status()).toBe(401)

  await page.getByRole('button', { name: 'Cerrar contexto' }).click()
  await expect(context).toHaveCount(0)
  await expect(page).not.toHaveURL(/ticket=/)
  await page.getByText('Crear ticket para un cliente', { exact: true }).click()
  await page.getByLabel('Correo exacto o identificador de cuenta').fill('cliente@example.test')
  await page.getByRole('button', { name: 'Verificar cliente' }).click()
  const escalatedSubject = `E2E escalamiento ${Date.now()}`
  await page.getByLabel('Asunto', { exact: true }).fill(escalatedSubject)
  await page.getByLabel('Descripción', { exact: true }).fill('Caso creado por agente')
  await page.locator('details input[type=file]').setInputFiles({ ...file, name: 'creado-por-agente.pdf' })
  await page.getByRole('button', { name: 'Crear ticket', exact: true }).click()
  const nextCard = page.getByRole('listitem').filter({ has: page.getByRole('heading', { name: escalatedSubject, exact: true }) })
  await nextCard.getByRole('button', { name: 'Reclamar ticket' }).click()
  await expect(context.getByRole('button', { name: 'Descargar creado-por-agente.pdf' })).toBeVisible()
  await context.getByText('Gestionar ticket', { exact: true }).click()
  await context.getByLabel('Acción').selectOption('escalate')
  await page.getByLabel('Motivo interno de escalamiento').fill('Motivo interno E2E')
  await page.getByRole('button', { name: 'Escalar ticket' }).click()
  await expect(page.getByText('Este ticket está en modo de solo lectura.')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Enviar mensaje' })).toHaveCount(0)
  await page.getByRole('button', { name: 'Cerrar contexto' }).click()
  await page.getByRole('button', { name: /Cerrar sesión/i }).click()
})
