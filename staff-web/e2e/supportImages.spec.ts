import { readFileSync } from 'node:fs'
import { expect, test } from '@playwright/test'

const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGMQqo0BAAGQAOzY5F2BAAAAAElFTkSuQmCC'
const csp = readFileSync(new URL('../deploy/nginx.conf.template', import.meta.url), 'utf8').match(/Content-Security-Policy "([^"]+)"/)![1]

for (const mobile of [false, true]) {
  test.describe(mobile ? 'touch' : 'desktop', () => {
    test.use({ viewport: mobile ? { width: 390, height: 844 } : { width: 1280, height: 900 }, hasTouch: mobile })

    test('ticket #2 initial legacy PNG and message image under production CSP', async ({ page }) => {
      // Exercise the actual deployed policy: Vite's development server has no CSP.
      await page.route('**/support?ticket=2', async route => {
        const response = await route.fetch()
        await route.fulfill({ response, headers: { ...response.headers(), 'content-security-policy': csp } })
      })
      await page.route('**/api/v1/staff/auth/session', route => route.fulfill({ json: { user: { id: 73, email: 'support@example.test', role: 'support_agent' }, access_expires_at: '2026-11-18T00:00:00Z', renewable_expires_at: '2026-11-19T00:00:00Z', absolute_expires_at: '2026-11-20T00:00:00Z' } }))
      const ticket = { id: 2, subject: 'No me sirve la AI', status: 'in_progress', assigned_staff_user_id: 73, category: 'technical', description: 'Solicitud con imagen', created_at: '2026-11-17T00:00:00Z' }
      let denied = false
      await page.route('**/api/v1/staff/support/tickets**', async route => {
        expect(route.request().headers()['x-staff-request']).toBe('1')
        const path = new URL(route.request().url()).pathname
        if (path.includes('/attachments/')) {
          await route.fulfill(denied ? { status: 404, json: { code: 'support_ticket_not_found' } } : { json: { content: png } })
        } else if (path.endsWith('/conversation')) {
          await route.fulfill({ json: { ticket, customer: { id: 42, is_active: true }, history: [], messages: [{ id: 8, author_user_id: 42, body: 'Respuesta con imagen', created_at: ticket.created_at }], attachments: [
            { id: 1, message_id: null, name: 'tmp_123.png', size: 69 },
            { id: 2, message_id: 8, name: 'nueva.JPG', size: 69 },
            { id: 3, message_id: null, name: 'documento.pdf', size: 69 },
          ] } })
        } else await route.fulfill({ json: path.endsWith('/2') ? ticket : [ticket] })
      })
      await page.goto('/support?ticket=2')
      const context = page.getByRole('dialog', { name: 'Contexto del ticket' })
      await expect(context).toBeVisible()
      for (const name of ['tmp_123.png', 'nueva.JPG']) {
        const trigger = context.getByRole('button', { name: `Abrir imagen ${name}`, exact: true })
        await expect.poll(() => trigger.locator('img').evaluate((img: HTMLImageElement) => img.naturalWidth)).toBe(1)
        if (mobile) await trigger.tap()
        else { await trigger.focus(); await page.keyboard.press('Enter') }
        const viewer = page.getByRole('dialog', { name: `Imagen ${name}`, exact: true })
        await expect(viewer).toBeVisible()
        if (mobile) await viewer.getByRole('button', { name: 'Cerrar imagen' }).tap()
        else await page.keyboard.press('Escape')
        await expect(viewer).not.toBeVisible()
        await expect(trigger).toBeFocused()
        await expect(context).toBeVisible()
        if (!mobile) {
          await trigger.click()
          await viewer.getByRole('button', { name: 'Cerrar imagen' }).click()
          await expect(trigger).toBeFocused()
        }
      }
      const download = page.waitForEvent('download')
      await context.getByRole('button', { name: 'Descargar tmp_123.png' }).click()
      expect((await download).suggestedFilename()).toBe('tmp_123.png')
      await expect(context.getByRole('button', { name: 'Descargar documento.pdf' })).toBeVisible()
      await expect(context.getByRole('button', { name: 'Abrir imagen documento.pdf' })).toHaveCount(0)
      denied = true
      await page.reload()
      await expect(context.getByRole('alert').first()).toContainText('No se pudo mostrar la vista previa')
      await expect(context.getByRole('button', { name: /Abrir imagen/ })).toHaveCount(0)
      await expect(context.getByRole('button', { name: 'Descargar tmp_123.png' })).toBeEnabled()
    })
  })
}
