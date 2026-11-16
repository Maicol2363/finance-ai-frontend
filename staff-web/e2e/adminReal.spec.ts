import { readFileSync } from 'node:fs'
import { createHmac } from 'node:crypto'
import {
  expect,
  request as playwrightRequest,
  test,
  type APIRequestContext,
  type Browser,
  type BrowserContext,
  type Page,
} from '@playwright/test'

/**
 * Real-stack journeys for the Administrator role. Opt-in: needs the isolated demo database
 * seeded by backend scripts/seed_admin_demo.py and the API running on 127.0.0.1:8000 with
 * the portal origin (127.0.0.1:4173, or ADMIN_PORTAL_URL) as an allowed origin. No authentication or
 * authorization is stubbed.
 *
 *   ADMIN_DEMO_CREDENTIALS=<path to admin-credentials.txt> npm run test:e2e -- adminReal
 */
const CREDENTIALS_FILE = process.env.ADMIN_DEMO_CREDENTIALS
// The portal origin: 4173 by default; set ADMIN_PORTAL_URL when that port is taken. The API must allow it in CORS.
const PORTAL = process.env.ADMIN_PORTAL_URL ?? 'http://127.0.0.1:4173'
const API = 'http://127.0.0.1:8000/api/v1'
const ADMIN_API = `${PORTAL}/api/v1/staff/admin`
const BOUNDARY = { Origin: PORTAL, 'X-Staff-Request': '1', 'Content-Type': 'application/json' }
const ADMIN1 = 'admin1@example.com'
const ADMIN2 = 'admin2@example.com'
const AGENT1 = 'agente1@example.com'
const AGENT2 = 'agente2@example.com'
const CUSTOMER1 = 'cliente1@example.com'

function demoPassword(): string {
  const text = readFileSync(CREDENTIALS_FILE!, 'utf-8')
  const match = /Contrasena de todas las cuentas: (\S+)/.exec(text)
  if (!match) throw new Error('Demo credentials file has an unexpected format')
  return match[1]
}

// --- TOTP (RFC 6238, SHA-1, 6 digits, 30 s) without any dependency -------------------------------

function base32Decode(input: string): Buffer {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
  let bits = ''
  for (const char of input.replace(/=+$/, '').toUpperCase()) bits += alphabet.indexOf(char).toString(2).padStart(5, '0')
  const bytes: number[] = []
  for (let index = 0; index + 8 <= bits.length; index += 8) bytes.push(parseInt(bits.slice(index, index + 8), 2))
  return Buffer.from(bytes)
}

function totp(secret: string, step: number): string {
  const counter = Buffer.alloc(8)
  counter.writeBigUInt64BE(BigInt(step))
  const hash = createHmac('sha1', base32Decode(secret)).update(counter).digest()
  const offset = hash[hash.length - 1] & 0xf
  const value = (((hash[offset] & 0x7f) << 24) | (hash[offset + 1] << 16) | (hash[offset + 2] << 8) | hash[offset + 3]) % 1_000_000
  return String(value).padStart(6, '0')
}

const secrets = new Map<string, string>()
const lastStep = new Map<string, number>()

/** A code the server has not accepted yet: waits for the next 30 s step when needed (replay rule). */
async function freshCode(email: string): Promise<string> {
  const secret = secrets.get(email)!
  let step = Math.floor(Date.now() / 30_000)
  if (step <= (lastStep.get(email) ?? -1)) {
    await new Promise((resolve) => setTimeout(resolve, 30_000 - (Date.now() % 30_000) + 400))
    step = Math.floor(Date.now() / 30_000)
  }
  lastStep.set(email, step)
  return totp(secret, step)
}

async function signInAsAdmin(page: Page, email: string): Promise<void> {
  await page.goto('/login')
  await page.getByLabel('Correo electrónico').fill(email)
  await page.getByLabel('Contraseña', { exact: true }).fill(demoPassword())
  await page.getByRole('button', { name: 'Iniciar sesión' }).click()
  if (!secrets.has(email)) {
    await page.getByRole('button', { name: 'Generar código QR' }).click()
    const secret = (await page.locator('code[aria-label="Clave de configuración"]').innerText()).replace(/\s/g, '')
    secrets.set(email, secret)
  }
  await page.getByLabel('Código de verificación de 6 dígitos').fill(await freshCode(email))
  await page.getByRole('button', { name: 'Verificar y entrar' }).click()
  await expect(page.getByRole('heading', { name: 'Administración' })).toBeVisible()
}

async function signOut(page: Page): Promise<void> {
  await page.getByTestId('staff-sign-out-button').click()
  await expect(page.getByRole('heading', { name: 'Iniciar sesión en el portal del personal' })).toBeVisible()
}

async function lookup(page: Page, email: string): Promise<void> {
  await page.goto('/admin/accounts')
  await page.getByRole('radio', { name: 'Correo electrónico' }).check()
  await page.getByRole('textbox').fill(email)
  await page.getByRole('button', { name: 'Buscar cuenta' }).click()
  await expect(page.getByTestId('admin-account-result')).toContainText(email)
}

async function customerToken(request: APIRequestContext, email = CUSTOMER1): Promise<string | null> {
  const response = await request.post(`${API}/auth/login`, { data: { email, password: demoPassword(), platform: 'android' } })
  if (response.status() !== 200) return null
  return ((await response.json()) as { access_credential: string }).access_credential
}

async function newAdminPage(browser: Browser, email: string): Promise<{ context: BrowserContext; page: Page }> {
  const context = await browser.newContext({ baseURL: PORTAL })
  const page = await context.newPage()
  await signInAsAdmin(page, email)
  return { context, page }
}

test.describe.configure({ mode: 'serial' })

test.describe('Administrator workspace against the real API', () => {
  test.skip(!CREDENTIALS_FILE, 'Requires the isolated admin demo (ADMIN_DEMO_CREDENTIALS)')

  let adminOne: { context: BrowserContext; page: Page }
  let adminTwo: { context: BrowserContext; page: Page }

  test.beforeAll(async ({ browser }) => {
    adminOne = await newAdminPage(browser, ADMIN1)
    adminTwo = await newAdminPage(browser, ADMIN2)
  })

  test.afterAll(async () => {
    for (const admin of [adminOne, adminTwo]) await admin?.context.close()
  })

  test('first sign-in enrolled an authenticator; a replayed code is rejected, a new one is accepted', async ({ browser }) => {
    const { page } = adminOne
    await signOut(page)
    await page.getByLabel('Correo electrónico').fill(ADMIN1)
    await page.getByLabel('Contraseña', { exact: true }).fill(demoPassword())
    await page.getByRole('button', { name: 'Iniciar sesión' }).click()
    await expect(page.getByRole('heading', { name: 'Ingresa tu código de verificación' })).toBeVisible()

    // The code accepted during enrollment cannot be used again for the same time step.
    const replayed = totp(secrets.get(ADMIN1)!, lastStep.get(ADMIN1)!)
    await page.getByLabel('Código de verificación de 6 dígitos').fill(replayed)
    await page.getByRole('button', { name: 'Verificar y entrar' }).click()
    await expect(page.getByTestId('staff-mfa-message')).toContainText('no es válido o ya se usó')

    await page.getByLabel('Código de verificación de 6 dígitos').fill(await freshCode(ADMIN1))
    await page.getByRole('button', { name: 'Verificar y entrar' }).click()
    await expect(page.getByRole('heading', { name: 'Administración' })).toBeVisible()

    // A second browser cannot hold a parallel staff session for the same account.
    const other = await browser.newContext({ baseURL: PORTAL })
    const otherPage = await other.newPage()
    await otherPage.goto('/login')
    await otherPage.getByLabel('Correo electrónico').fill(ADMIN1)
    await otherPage.getByLabel('Contraseña', { exact: true }).fill(demoPassword())
    await otherPage.getByRole('button', { name: 'Iniciar sesión' }).click()
    await expect(otherPage.getByTestId('staff-auth-message')).toContainText('sesión del personal activa')
    await other.close()
  })

  test('account lookup validates input, shows only login-account data and survives a reload', async () => {
    const { page } = adminOne
    await page.goto('/admin/accounts')
    await page.getByRole('button', { name: 'Buscar cuenta' }).click()
    await expect(page.getByRole('alert')).toContainText('correo electrónico completo')
    await page.getByRole('textbox').fill('sin-arroba')
    await page.getByRole('button', { name: 'Buscar cuenta' }).click()
    await expect(page.getByRole('alert')).toContainText('correo electrónico completo')

    await page.getByRole('textbox').fill('nadie@example.com')
    await page.getByRole('button', { name: 'Buscar cuenta' }).click()
    await expect(page.getByTestId('admin-error')).toContainText('No hay ninguna cuenta de acceso con ese dato.')

    await page.getByRole('textbox').fill(CUSTOMER1)
    await page.getByRole('button', { name: 'Buscar cuenta' }).click()
    const result = page.getByTestId('admin-account-result')
    await expect(result).toContainText('no una cuenta financiera')
    await expect(result).toContainText('Cliente')
    await expect(result).toContainText('Activa')
    expect(await result.innerText()).not.toMatch(/saldo|balance|contraseña|hash|token/i)

    await page.getByRole('radio', { name: 'ID de cuenta' }).check()
    await page.getByRole('textbox').fill('0')
    await page.getByRole('button', { name: 'Buscar cuenta' }).click()
    await expect(page.getByRole('alert')).toContainText('ID de cuenta numérico válido')

    // The admin's own account: no suspension offered.
    await lookup(page, ADMIN1)
    await expect(page.getByTestId('admin-own-account')).toBeVisible()
    await expect(page.getByRole('button', { name: 'Suspender cuenta' })).toHaveCount(0)

    // Cookie-backed session survives a full page reload.
    await page.reload()
    await expect(page.getByRole('heading', { name: 'Administración' })).toBeVisible()
  })

  test('suspending a customer locks them out and reactivation does not restore the old session', async ({ request }) => {
    const { page } = adminOne
    const token = await customerToken(request)
    expect(token).not.toBeNull()
    const own = () => request.get(`${API}/support/tickets`, { headers: { Authorization: `Bearer ${token}` } })
    expect((await own()).status()).toBe(200)

    await lookup(page, CUSTOMER1)
    await page.getByRole('button', { name: 'Suspender cuenta' }).click()
    const confirm = page.getByRole('button', { name: 'Confirmar suspensión' })
    await expect(confirm).toBeDisabled()
    await page.getByLabel(/Motivo de la suspensión/).fill('Revisión de seguridad E2E')
    await expect(confirm).toBeDisabled()
    await page.getByRole('checkbox').check()
    await confirm.click()
    await expect(page.getByTestId('admin-suspension-detail')).toContainText('Revisión de seguridad E2E')

    expect((await own()).status()).toBe(401)
    expect(await customerToken(request)).toBeNull()

    await page.getByRole('button', { name: 'Reactivar cuenta' }).click()
    await page.getByRole('checkbox').check()
    await page.getByRole('button', { name: 'Confirmar reactivación' }).click()
    await expect(page.getByTestId('admin-accounts-notice')).toContainText('sesiones anteriores no se restauran')
    expect((await own()).status()).toBe(401)
    expect(await customerToken(request)).not.toBeNull()
  })

  test('invitation: one-time link, token leaves the address bar, replay fails, role change ends the session', async ({ browser }) => {
    const { page } = adminOne
    await page.goto('/admin/staff')
    const invite = page.getByRole('region', { name: 'Invitar a una persona del personal' })
    await invite.getByLabel('Correo electrónico').fill(AGENT1)
    await invite.getByRole('button', { name: 'Crear invitación' }).click()
    await expect(page.getByTestId('admin-error')).toContainText('Ya existe una cuenta o una invitación vigente')

    const stamp = Date.now()
    const newcomer = `nuevo${stamp}@example.com`
    await invite.getByLabel('Correo electrónico').fill(newcomer)
    await invite.getByLabel('Rol inicial').selectOption('support_agent')
    await invite.getByRole('button', { name: 'Crear invitación' }).click()
    const link = await page.getByLabel(/Enlace de activación/).inputValue()
    expect(link).toMatch(/\/activate#token=[A-Za-z0-9_-]{43}$/)

    // The administrator keeps working for longer than the old 30 s unmount window.
    await page.waitForTimeout(35_000)
    await expect(page.getByTestId('admin-invitation-created')).toBeVisible()

    const invited = await browser.newContext({ baseURL: PORTAL })
    const invitedPage = await invited.newPage()
    await invitedPage.goto(link)
    await expect(invitedPage.getByRole('heading', { name: 'Elige tu contraseña' })).toBeVisible()
    expect(invitedPage.url()).not.toContain('token=')
    await invitedPage.getByLabel('Contraseña nueva').fill('Nuevo-agente-passphrase-2026')
    await invitedPage.getByLabel('Confirma la contraseña').fill('Nuevo-agente-passphrase-2026')
    await invitedPage.getByRole('button', { name: 'Activar cuenta' }).click()
    await expect(invitedPage.getByTestId('staff-activate-success')).toBeVisible()

    // The same link can never be used again.
    await invitedPage.goto(link)
    await invitedPage.getByLabel('Contraseña nueva').fill('Otra-passphrase-distinta-2026')
    await invitedPage.getByLabel('Confirma la contraseña').fill('Otra-passphrase-distinta-2026')
    await invitedPage.getByRole('button', { name: 'Activar cuenta' }).click()
    await expect(invitedPage.getByTestId('staff-activate-invalid')).toContainText('no es válido, venció o ya se usó')
    await invited.close()

    // The new agent signs in (no MFA for support agents) and works until the admin switches the role.
    const agentApi = await playwrightRequest.newContext({ baseURL: PORTAL, extraHTTPHeaders: BOUNDARY })
    const agentLogin = await agentApi.post('/api/v1/staff/auth/login', { data: { email: newcomer, password: 'Nuevo-agente-passphrase-2026' } })
    expect(agentLogin.status()).toBe(200)
    expect((await agentApi.get('/api/v1/staff/support/tickets', { headers: BOUNDARY })).status()).toBe(200)

    await lookup(page, newcomer)
    const staffId = (await page.getByTestId('admin-account-result').locator('dd').first().innerText()).trim()
    await page.goto('/admin/staff')
    const roles = page.getByRole('region', { name: 'Cambiar el rol de una persona del personal' })
    await roles.getByLabel('ID de la cuenta del personal').fill(staffId)
    await roles.getByRole('button', { name: 'Consultar rol' }).click()
    await expect(page.getByTestId('admin-staff-result')).toContainText('Agente de soporte')
    await page.getByTestId('admin-staff-result').getByRole('checkbox').check()
    await page.getByRole('button', { name: 'Confirmar cambio de rol' }).click()
    await expect(page.getByTestId('admin-role-notice')).toContainText('Rol actualizado a «Auditor de seguridad»')

    // The agent's existing session stops working immediately.
    const afterSwitch = await agentApi.get('/api/v1/staff/support/tickets', { headers: BOUNDARY })
    expect([401, 403]).toContain(afterSwitch.status())

    // An administrator cannot be changed from the portal, nor can the own role.
    for (const [email, expected] of [[ADMIN2, 'no se cambia desde el portal'], [ADMIN1, 'No puedes cambiar tu propio rol.']] as const) {
      const id = ((await (await page.request.post(`${ADMIN_API}/accounts/lookup`, { headers: BOUNDARY, data: { email } })).json()) as { id: number }).id
      await page.goto('/admin/staff')
      await roles.getByLabel('ID de la cuenta del personal').fill(String(id))
      await roles.getByRole('button', { name: 'Consultar rol' }).click()
      await expect(page.getByTestId('admin-staff-result')).toContainText(expected)
      await expect(page.getByRole('button', { name: 'Confirmar cambio de rol' })).toHaveCount(0)
    }
    await agentApi.dispose()
  })

  test('two real administrators racing for one escalated case: exactly one owns it', async () => {
    const queue = await adminOne.page.request.get(`${ADMIN_API}/tickets/escalated?scope=unclaimed&limit=100`, { headers: BOUNDARY })
    expect(queue.status()).toBe(200)
    const tickets = (await queue.json()) as Array<{ id: number; subject: string }>
    expect(tickets.length).toBeGreaterThanOrEqual(3)
    const target = tickets.find((ticket) => ticket.subject === 'No puedo recuperar mi acceso')!

    // Both administrators have the case on screen; the buttons are pressed as simultaneously as the UI allows.
    await Promise.all([adminOne.page.goto('/admin/tickets'), adminTwo.page.goto('/admin/tickets')])
    const claimFor = (page: Page) =>
      page.getByRole('listitem').filter({ has: page.getByRole('heading', { name: target.subject }) }).getByRole('button', { name: 'Reclamar caso' })
    await expect(claimFor(adminOne.page)).toBeVisible()
    await expect(claimFor(adminTwo.page)).toBeVisible()
    await Promise.all([claimFor(adminOne.page).click(), claimFor(adminTwo.page).click()])

    const outcomes = await Promise.all(
      [adminOne.page, adminTwo.page].map(async (page) => {
        const claimed = page.getByTestId('admin-escalations-notice').filter({ hasText: 'Caso reclamado' })
        const conflict = page.getByTestId('admin-error').filter({ hasText: 'Otro administrador tomó este caso primero' })
        await expect(claimed.or(conflict)).toBeVisible()
        return (await claimed.count()) > 0 ? 'owner' : 'conflict'
      }),
    )
    expect(outcomes.sort()).toEqual(['conflict', 'owner'])
  })

  test('owner replies, the customer sees the reply but never the staff-only reasons, then resolves', async ({ request }) => {
    const ownerPage = (await adminOne.page.getByRole('button', { name: 'Responder al cliente' }).count()) ? adminOne.page : adminTwo.page
    await ownerPage.goto('/admin/tickets')
    const card = ownerPage.getByRole('listitem').filter({ has: ownerPage.getByRole('heading', { name: 'No puedo recuperar mi acceso' }) })
    await card.getByRole('button', { name: 'Ver caso' }).click()
    await expect(ownerPage.getByTestId('admin-escalation-reason')).toContainText('verificacion administrativa')
    await expect(ownerPage.getByText('Solo personal').first()).toBeVisible()

    await ownerPage.getByRole('button', { name: 'Responder al cliente' }).click()
    await ownerPage.getByLabel('Mensaje para el cliente').fill('Hola, estamos validando tu identidad (E2E).')
    await ownerPage.getByRole('button', { name: 'Enviar respuesta' }).click()
    await expect(ownerPage.getByTestId('admin-messages')).toContainText('validando tu identidad')

    await ownerPage.getByRole('button', { name: 'Resolver caso' }).click()
    await ownerPage.getByLabel('Resumen de resolución (obligatorio)').fill('Identidad verificada y acceso restablecido (E2E).')
    await ownerPage.getByRole('checkbox').check()
    await ownerPage.getByRole('form', { name: 'Resolver' }).getByRole('button', { name: 'Resolver caso' }).click()
    await expect(ownerPage.getByTestId('admin-escalations-notice')).toContainText('Caso resuelto')

    const token = await customerToken(request)
    const list = (await (await request.get(`${API}/support/tickets`, { headers: { Authorization: `Bearer ${token}` } })).json()) as {
      tickets: Array<{ id: number; subject: string; status: string }>
    }
    const mine = list.tickets.find((ticket) => ticket.subject === 'No puedo recuperar mi acceso' && ticket.status === 'resolved')!
    const view = await request.get(`${API}/support/tickets/${mine.id}`, { headers: { Authorization: `Bearer ${token}` } })
    const text = JSON.stringify(await view.json())
    expect(text).toContain('Identidad verificada y acceso restablecido (E2E).')
    expect(text).toContain('validando tu identidad')
    expect(text).not.toContain('verificacion administrativa')
    expect(text).not.toContain('internal_reason')
  })

  test('returning a case: to the active agent in progress, and unassigned when the agent is suspended', async () => {
    const page = adminOne.page
    // Eligible origin: the agent is active, so the case goes back to them.
    await page.goto('/admin/tickets')
    const first = page.getByRole('listitem').filter({ has: page.getByRole('heading', { name: 'Cobro duplicado en mi cuenta' }) })
    await first.getByRole('button', { name: 'Reclamar caso' }).click()
    await page.getByRole('button', { name: 'Devolver a soporte' }).click()
    await expect(page.getByTestId('admin-origin-note')).toContainText('volverá a él en atención')
    const form = page.getByRole('form', { name: 'Devolver' })
    await form.getByLabel('Motivo de devolución (obligatorio)').fill('Identidad verificada; continúa soporte (E2E)')
    await expect(form.getByRole('button', { name: 'Devolver caso' })).toBeDisabled()
    await form.getByRole('checkbox').check()
    await form.getByRole('button', { name: 'Devolver caso' }).click()
    await expect(page.getByTestId('admin-escalations-notice')).toContainText('continúa atendiéndolo')

    // Ineligible origin: suspend the agent, then return the next case.
    await lookup(page, AGENT1)
    await page.getByRole('button', { name: 'Suspender cuenta' }).click()
    await page.getByLabel(/Motivo de la suspensión/).fill('Rotación de personal E2E')
    await page.getByRole('checkbox').check()
    await page.getByRole('button', { name: 'Confirmar suspensión' }).click()
    await expect(page.getByTestId('admin-suspension-detail')).toBeVisible()

    await page.goto('/admin/tickets')
    const second = page.getByRole('listitem').filter({ has: page.getByRole('heading', { name: 'Solicitud de cierre de cuenta' }) })
    await second.getByRole('button', { name: 'Reclamar caso' }).click()
    await page.getByRole('button', { name: 'Devolver a soporte' }).click()
    await expect(page.getByTestId('admin-origin-note')).toContainText('volverá a la cola sin asignar')
    const form2 = page.getByRole('form', { name: 'Devolver' })
    await form2.getByLabel('Motivo de devolución (obligatorio)').fill('Agente de origen no disponible (E2E)')
    await form2.getByRole('checkbox').check()
    await form2.getByRole('button', { name: 'Devolver caso' }).click()
    await expect(page.getByTestId('admin-escalations-notice')).toContainText('volvió a la cola de soporte sin asignar')

    // A second agent can claim it from the open queue (status open, no assignee).
    const agentApi = await playwrightRequest.newContext({ baseURL: PORTAL, extraHTTPHeaders: BOUNDARY })
    expect((await agentApi.post('/api/v1/staff/auth/login', { data: { email: AGENT2, password: demoPassword() } })).status()).toBe(200)
    const open = (await (await agentApi.get('/api/v1/staff/support/tickets?status=open', { headers: BOUNDARY })).json()) as Array<{
      subject: string
      assigned_staff_user_id: number | null
    }>
    const returned = open.find((ticket) => ticket.subject === 'Solicitud de cierre de cuenta')
    expect(returned?.assigned_staff_user_id).toBeNull()
    await agentApi.post('/api/v1/staff/auth/logout', { data: {} })
    await agentApi.dispose()
  })

  test('recovery codes, lost-device recovery and replacement by the current authenticator', async () => {
    const page = adminOne.page
    await page.goto('/admin/security')
    await page.getByLabel('Confirma tu contraseña').fill('contraseña-incorrecta')
    await page.getByRole('button', { name: /Generar códigos/ }).click()
    await expect(page.getByRole('alert')).toContainText('La contraseña no es correcta.')
    await page.getByLabel('Confirma tu contraseña').fill(demoPassword())
    await page.getByRole('button', { name: /Generar códigos/ }).click()
    const codeCells = page.locator('[data-testid="admin-recovery-codes"] code')
    await expect(codeCells).toHaveCount(10)
    const codes = await codeCells.allInnerTexts()

    const enrollAgain = async (): Promise<void> => {
      await page.getByRole('button', { name: 'Generar código QR' }).click()
      secrets.set(ADMIN1, (await page.locator('code[aria-label="Clave de configuración"]').innerText()).replace(/\s/g, ''))
      lastStep.delete(ADMIN1)
      await page.getByLabel('Código de verificación de 6 dígitos').fill(await freshCode(ADMIN1))
      await page.getByRole('button', { name: 'Verificar y entrar' }).click()
      await expect(page.getByRole('heading', { name: 'Administración' })).toBeVisible()
    }
    const openRecovery = async (): Promise<void> => {
      await signOut(page)
      await page.getByTestId('staff-recover-link').click()
      await page.getByLabel('Correo electrónico').fill(ADMIN1)
      await page.getByLabel('Contraseña', { exact: true }).fill(demoPassword())
    }

    // Lost device: a recovery code (any letter case) opens a new enrollment.
    await openRecovery()
    await page.getByRole('textbox', { name: 'Código de recuperación' }).fill(codes[0].toLowerCase())
    await page.getByRole('button', { name: 'Verificar y continuar' }).click()
    await expect(page.getByRole('heading', { name: 'Configura tu autenticador' })).toBeVisible()
    await enrollAgain()

    // The same recovery code cannot be used twice, and the failure is generic.
    await openRecovery()
    await page.getByRole('textbox', { name: 'Código de recuperación' }).fill(codes[0])
    await page.getByRole('button', { name: 'Verificar y continuar' }).click()
    await expect(page.getByTestId('staff-recover-message')).toContainText('No se pudo verificar la recuperación')

    // Replacement with the current authenticator code (no recovery code needed).
    await page.getByRole('radio', { name: 'Código de mi autenticador actual' }).check()
    await page.getByLabel('Contraseña', { exact: true }).fill(demoPassword())
    await page.getByRole('textbox', { name: 'Código de 6 dígitos' }).fill(await freshCode(ADMIN1))
    await page.getByRole('button', { name: 'Verificar y continuar' }).click()
    await expect(page.getByRole('heading', { name: 'Configura tu autenticador' })).toBeVisible()
    await enrollAgain()
  })

  test('permissions: agents, customers and anonymous callers are refused by the admin API', async ({ request }) => {
    const agentApi = await playwrightRequest.newContext({ baseURL: PORTAL, extraHTTPHeaders: BOUNDARY })
    expect((await agentApi.post('/api/v1/staff/auth/login', { data: { email: AGENT2, password: demoPassword() } })).status()).toBe(200)
    for (const [method, path, body] of [
      ['post', '/accounts/lookup', { id: 1 }],
      ['get', '/accounts/1', undefined],
      ['post', '/accounts/3/suspend', { reason: 'x', confirm: true }],
      ['post', '/staff/invitations', { email: 'x@example.com', role: 'support_agent' }],
      ['get', '/tickets/escalated', undefined],
    ] as const) {
      const response = method === 'get'
        ? await agentApi.get(`/api/v1/staff/admin${path}`)
        : await agentApi.post(`/api/v1/staff/admin${path}`, { data: body })
      expect(response.status(), `${method} ${path}`).toBe(403)
    }
    await agentApi.post('/api/v1/staff/auth/logout', { data: {} })
    await agentApi.dispose()

    const token = await customerToken(request, 'cliente2@example.com')
    expect((await request.get(`${ADMIN_API}/accounts/1`, { headers: { Authorization: `Bearer ${token}`, ...BOUNDARY } })).status()).toBe(403)
    const anonymous = await playwrightRequest.newContext()
    expect((await anonymous.get(`${ADMIN_API}/accounts/1`, { headers: BOUNDARY })).status()).toBe(401)
    expect((await anonymous.post(`${ADMIN_API}/accounts/lookup`, { headers: BOUNDARY, data: { id: 1 } })).status()).toBe(401)
    // Forged privileged fields are rejected before any service runs.
    const forged = await adminOne.page.request.post(`${ADMIN_API}/staff/invitations`, { headers: BOUNDARY, data: { email: 'forged@example.com', role: 'admin' } })
    expect(forged.status()).toBe(422)
    await anonymous.dispose()
  })

  test('mutual suspension race between two real administrators leaves exactly one active', async () => {
    const idOf = async (page: Page, email: string): Promise<number> => {
      const response = await page.request.post(`${ADMIN_API}/accounts/lookup`, { headers: BOUNDARY, data: { email } })
      return ((await response.json()) as { id: number }).id
    }
    const [idOne, idTwo] = [await idOf(adminOne.page, ADMIN1), await idOf(adminOne.page, ADMIN2)]
    const suspend = (page: Page, id: number) =>
      page.request.post(`${ADMIN_API}/accounts/${id}/suspend`, { headers: BOUNDARY, data: { reason: 'Carrera mutua E2E', confirm: true } })

    const [first, second] = await Promise.all([suspend(adminOne.page, idTwo), suspend(adminTwo.page, idOne)])
    const statuses = [first.status(), second.status()].sort()
    // One suspension succeeds. The other is refused: the guard (409) or the session already revoked (401/403).
    expect(statuses[0]).toBe(200)
    expect([401, 403, 409]).toContain(statuses[1])

    const survivor = first.status() === 200 ? adminOne : adminTwo
    const other = first.status() === 200 ? idTwo : idOne
    const check = await survivor.page.request.get(`${ADMIN_API}/accounts/${first.status() === 200 ? idOne : idTwo}`, { headers: BOUNDARY })
    expect(check.status()).toBe(200)
    expect((await check.json()).status).toBe('active')

    // The suspended administrator's session is dead at once.
    const loser = first.status() === 200 ? adminTwo : adminOne
    expect([401, 403]).toContain((await loser.page.request.get(`${ADMIN_API}/accounts/${other}`, { headers: BOUNDARY })).status())

    // Restore: the survivor reactivates the other administrator.
    const reactivated = await survivor.page.request.post(`${ADMIN_API}/accounts/${other}/reactivate`, { headers: BOUNDARY, data: { confirm: true } })
    expect(reactivated.status()).toBe(200)
  })
})
