import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { TemplateList } from './TemplateList'

const { renameTemplate, deleteTemplate, data } = vi.hoisted(() => ({
  renameTemplate: vi.fn(async () => {}),
  deleteTemplate: vi.fn(async () => {}),
  data: {
    list: [] as {
      id: string
      name: string
      description: string | null
      weeks: number
      sessions: number
      created_at: string
    }[],
  },
}))
vi.mock('@/lib/templates', () => ({
  renameTemplate,
  deleteTemplate,
  templatesQuery: () => ({ queryKey: ['templates', 'c1'], queryFn: async () => data.list }),
}))

const t1 = {
  id: 't1',
  name: 'Spinta 4 settimane',
  description: 'Per ipertrofia',
  weeks: 4,
  sessions: 1,
  created_at: '2026-10-15T10:00:00Z',
}
const setup = () =>
  render(
    <QueryClientProvider client={new QueryClient()}>
      <TemplateList coachId="c1" />
    </QueryClientProvider>,
  )
beforeEach(() => {
  vi.clearAllMocks()
  data.list = []
  Element.prototype.hasPointerCapture ??= () => false
  Element.prototype.releasePointerCapture ??= () => {}
})

describe('TemplateList', () => {
  it('senza template spiega come crearne uno', async () => {
    setup()
    expect(await screen.findByText(/Nessun template/)).toBeInTheDocument()
    expect(screen.getByText(/Salva come template/)).toBeInTheDocument()
  })

  it('mostra nome, durata, sedute e descrizione', async () => {
    data.list = [t1]
    setup()
    expect(await screen.findByText('Spinta 4 settimane')).toBeInTheDocument()
    expect(screen.getByText('4 settimane · 1 seduta')).toBeInTheDocument()
    expect(screen.getByText('Per ipertrofia')).toBeInTheDocument()
  })

  it('rinomina', async () => {
    data.list = [t1]
    setup()
    await userEvent.click(await screen.findByRole('button', { name: 'Rinomina: Spinta 4 settimane' }))
    const input = screen.getByLabelText('Nuovo nome')
    await userEvent.clear(input)
    await userEvent.type(input, '  Spinta 6  ')
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    await waitFor(() => expect(renameTemplate).toHaveBeenCalledWith('c1', 't1', 'Spinta 6'))
  })

  it('un nome vuoto o già usato non passa', async () => {
    data.list = [t1]
    renameTemplate.mockRejectedValueOnce({ code: '23505' })
    setup()
    await userEvent.click(await screen.findByRole('button', { name: 'Rinomina: Spinta 4 settimane' }))
    const input = screen.getByLabelText('Nuovo nome')
    await userEvent.clear(input)
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    expect(await screen.findByText('Dai un nome al template.')).toBeInTheDocument()
    await userEvent.type(input, 'Altro')
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    expect(await screen.findByText('Hai già un template con questo nome.')).toBeInTheDocument()
  })

  it('elimina solo dopo conferma, che dice cosa non cancella', async () => {
    data.list = [t1]
    setup()
    await userEvent.click(await screen.findByRole('button', { name: 'Elimina: Spinta 4 settimane' }))
    expect(await screen.findByText('Eliminare il template «Spinta 4 settimane»?')).toBeInTheDocument()
    expect(screen.getByText(/Non cancella i mesocicli già creati/)).toBeInTheDocument()
    expect(deleteTemplate).not.toHaveBeenCalled()
    await userEvent.click(screen.getByRole('button', { name: 'Elimina template' }))
    await waitFor(() => expect(deleteTemplate).toHaveBeenCalledWith('c1', 't1'))
  })
})
