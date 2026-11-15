import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { SupportCreateForm } from './SupportCreateForm'
import { SupportCasePanel } from './SupportCasePanel'
import { safeSupportDiagnostic, supportTicketsApi, SupportTicketsApiError } from './supportTicketsApi'

const ticket = { id: 7, subject: 'Consulta', category: 'general', description: 'Descripción', status: 'in_progress', created_at: '2026-11-12T10:00:00Z', assigned_staff_user_id: 42, resolution_summary: null }
const conversation = { ticket, customer: { id: 9, email: 'customer@example.test', is_active: true }, messages: [{ id: 1, body: '<script>window.injected=true</script>', author_user_id: 9, created_at: '2026-11-12T10:01:00Z' }], history: [{ id: 1, event_type: 'ticket_claimed', actor_user_id: 42, created_at: '2026-11-12T10:02:00Z', previous_status: 'open', new_status: 'in_progress', new_assignee_user_id: 42 }] }
function json(value: unknown, status = 200) { return new Response(JSON.stringify(value), { status, headers: { 'Content-Type': 'application/json' } }) }
afterEach(() => { vi.restoreAllMocks() })

describe('support workflow', () => {
  it('verifies exact identity before creating and clears verification when the identifier changes', async () => {
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(json(conversation.customer)).mockResolvedValueOnce(json(ticket, 201))
    const onCreated = vi.fn()
    render(<SupportCreateForm onCreated={onCreated} />)
    const user = userEvent.setup()
    await user.click(screen.getByText('Crear ticket para un cliente'))
    await user.type(screen.getByLabelText('Correo exacto o identificador de cuenta'), 'customer@example.test')
    await user.click(screen.getByRole('button', { name: 'Verificar cliente' }))
    await user.type(await screen.findByLabelText('Asunto'), 'Consulta de prueba')
    await user.type(screen.getByLabelText('Descripción'), 'Descripción de prueba')
    await user.click(screen.getByRole('button', { name: 'Crear ticket' }))
    expect(await screen.findByText('Ticket #7 creado sin asignar.')).toBeInTheDocument()
    expect(onCreated).toHaveBeenCalledOnce()
    expect(JSON.parse(fetchMock.mock.calls[1]?.[1]?.body as string)).toEqual({ customer_identifier: 'customer@example.test', subject: 'Consulta de prueba', category: 'general', description: 'Descripción de prueba' })
    expect(screen.queryByLabelText('Asunto')).not.toBeInTheDocument()
  })
  it('renders messages as literal text, sends a session-owned message, and refreshes the server result', async () => {
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(json(conversation)).mockResolvedValueOnce(new Response(null, { status: 204 })).mockResolvedValueOnce(json(conversation))
    const onChange = vi.fn()
    render(<SupportCasePanel id={7} onChange={onChange} />)
    expect(await screen.findByText('<script>window.injected=true</script>')).toBeInTheDocument()
    expect(document.querySelector('.support-case script')).toBeNull()
    const user = userEvent.setup()
    await user.type(screen.getByLabelText('Mensaje al cliente'), 'Respuesta')
    await user.click(screen.getByRole('button', { name: 'Enviar mensaje' }))
    await waitFor(() => expect(onChange).toHaveBeenCalledWith(ticket))
    expect(JSON.parse(fetchMock.mock.calls[1]?.[1]?.body as string)).toEqual({ body: 'Respuesta' })
    expect(await screen.findByText('Cambio guardado.')).toBeInTheDocument()
  })
  it.each(['resolved', 'escalated'])('makes %s cases read-only and preserves the visible conversation', async (status) => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(json({ ...conversation, ticket: { ...ticket, status, resolution_summary: status === 'resolved' ? 'Solucionado' : null } }))
    render(<SupportCasePanel id={7} onChange={vi.fn()} />)
    expect(await screen.findByText('Este ticket está en modo de solo lectura.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Enviar mensaje' })).not.toBeInTheDocument()
    expect(screen.getByText('<script>window.injected=true</script>')).toBeInTheDocument()
    if (status === 'resolved') expect(screen.getByText('Solucionado')).toBeInTheDocument()
  })
  it.each(['Resolver ticket', 'Escalar ticket'])('requires a summary and submits %s', async (label) => {
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(json(conversation)).mockResolvedValueOnce(new Response(null, { status: 204 })).mockResolvedValueOnce(json({ ...conversation, ticket: { ...ticket, status: 'resolved', resolution_summary: 'Resultado' } }))
    render(<SupportCasePanel id={7} onChange={vi.fn()} />)
    const field = await screen.findByLabelText('Resumen de resolución o motivo interno de escalamiento')
    fireEvent.change(field, { target: { value: 'Resultado' } })
    await userEvent.click(screen.getByRole('button', { name: label }))
    expect(await screen.findByText('Resultado')).toBeInTheDocument()
    expect(fetchMock.mock.calls[1]?.[0]).toContain(label === 'Resolver ticket' ? '/resolve' : '/escalate')
    expect(JSON.parse(fetchMock.mock.calls[1]?.[1]?.body as string)).toEqual({ summary: 'Resultado' })
  })
  it('preserves safe conflict diagnostics after refreshing a changed case', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(json(conversation)).mockResolvedValueOnce(json({ code: 'support_ticket_state_conflict', detail: 'private-input secret' }, 409)).mockResolvedValueOnce(json({ ...conversation, ticket: { ...ticket, status: 'escalated' } }))
    render(<SupportCasePanel id={7} onChange={vi.fn()} />)
    await screen.findByLabelText('Mensaje al cliente')
    fireEvent.change(screen.getByLabelText('Mensaje al cliente'), { target: { value: 'Respuesta' } })
    await userEvent.click(screen.getByRole('button', { name: 'Enviar mensaje' }))
    expect(await screen.findByRole('alert')).not.toHaveTextContent('private-input')
    expect(screen.getByText('Este ticket está en modo de solo lectura.')).toBeInTheDocument()
  })
  it.each(['lookup', 'create', 'conversation', 'message', 'escalate', 'resolve'] as const)('sanitizes %s failures', (operation) => {
    const diagnostic = safeSupportDiagnostic(new SupportTicketsApiError(403, 'staff_access_denied', 'corr-123', operation), operation)
    expect(JSON.stringify(diagnostic)).not.toMatch(/customer@example|private-input|secret/)
    expect(diagnostic.apiLocation).not.toContain('/7')
    expect(diagnostic.correlationId).toBe('corr-123')
  })
  it('does not include lookup input or server details in failures', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(json({ code: 'support_ticket_not_found', detail: 'sensitive@example.test secret' }, 404))
    const error = await supportTicketsApi.lookup('sensitive@example.test').catch((error: unknown) => error)
    expect(error).toBeInstanceOf(SupportTicketsApiError)
    expect(JSON.stringify(safeSupportDiagnostic(error, 'lookup'))).not.toMatch(/sensitive@example|secret/)
  })
})
