import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { NewMesocycleForm } from './NewMesocycleForm'

const { createMesocycle, createFromTemplate, navigate, templates } = vi.hoisted(() => ({
  createMesocycle: vi.fn(async () => 'm1'),
  createFromTemplate: vi.fn(async () => 'm2'),
  navigate: vi.fn(async () => {}),
  templates: { list: [] as { id: string; name: string; weeks: number }[] },
}))
vi.mock('@/lib/mesocycles', () => ({ createMesocycle }))
vi.mock('@/lib/templates', () => ({
  createFromTemplate,
  templatesQuery: () => ({ queryKey: ['templates', 'c1'], queryFn: async () => templates.list }),
}))
vi.mock('@tanstack/react-router', () => ({ useNavigate: () => navigate }))

const setup = () =>
  render(
    <QueryClientProvider client={new QueryClient()}>
      <NewMesocycleForm coachId="c1" athleteId="a1" onCancel={vi.fn()} />
    </QueryClientProvider>,
  )
beforeEach(() => {
  vi.clearAllMocks()
  templates.list = []
})

describe('NewMesocycleForm', () => {
  it('senza template non offre la scelta e crea da zero', async () => {
    setup()
    await waitFor(() => expect(screen.queryByLabelText('Parti da')).not.toBeInTheDocument())
    await userEvent.type(screen.getByLabelText('Nome'), 'Blocco 1')
    fireEvent.change(screen.getByLabelText('Inizio'), { target: { value: '2026-11-02' } })
    await userEvent.click(screen.getByRole('button', { name: 'Crea bozza' }))
    await waitFor(() =>
      expect(createMesocycle).toHaveBeenCalledWith('a1', {
        name: 'Blocco 1',
        start_date: '2026-11-02',
        weeks: 8,
      }),
    )
    await waitFor(() =>
      expect(navigate).toHaveBeenCalledWith({ to: '/mesocicli/$mesocycleId', params: { mesocycleId: 'm1' } }),
    )
  })

  it('con un template: la durata è quella del template e il nome è facoltativo', async () => {
    templates.list = [{ id: 't1', name: 'Spinta 6 settimane', weeks: 6 }]
    setup()
    await userEvent.selectOptions(await screen.findByLabelText('Parti da'), 't1')
    expect(screen.queryByLabelText('Settimane')).not.toBeInTheDocument()
    expect(screen.getByPlaceholderText('Spinta 6 settimane')).toBeInTheDocument()
    fireEvent.change(screen.getByLabelText('Inizio'), { target: { value: '2026-11-02' } })
    await userEvent.click(screen.getByRole('button', { name: 'Crea bozza' }))
    await waitFor(() =>
      expect(createFromTemplate).toHaveBeenCalledWith('t1', 'a1', { start_date: '2026-11-02', name: '' }),
    )
    expect(createMesocycle).not.toHaveBeenCalled()
    await waitFor(() =>
      expect(navigate).toHaveBeenCalledWith({ to: '/mesocicli/$mesocycleId', params: { mesocycleId: 'm2' } }),
    )
  })

  it('dal template con un nome scelto, e senza data non parte', async () => {
    templates.list = [{ id: 't1', name: 'Spinta', weeks: 4 }]
    setup()
    await userEvent.selectOptions(await screen.findByLabelText('Parti da'), 't1')
    await userEvent.type(screen.getByLabelText('Nome'), 'Per Marco')
    await userEvent.click(screen.getByRole('button', { name: 'Crea bozza' }))
    expect(await screen.findByText('Scegli la data di inizio.')).toBeInTheDocument()
    expect(createFromTemplate).not.toHaveBeenCalled()
    fireEvent.change(screen.getByLabelText('Inizio'), { target: { value: '2026-11-02' } })
    await userEvent.click(screen.getByRole('button', { name: 'Crea bozza' }))
    await waitFor(() =>
      expect(createFromTemplate).toHaveBeenCalledWith('t1', 'a1', {
        start_date: '2026-11-02',
        name: 'Per Marco',
      }),
    )
  })

  it('tornando a «Da zero» ricompare la durata', async () => {
    templates.list = [{ id: 't1', name: 'Spinta', weeks: 4 }]
    setup()
    const select = await screen.findByLabelText('Parti da')
    await userEvent.selectOptions(select, 't1')
    await userEvent.selectOptions(select, '')
    expect(screen.getByLabelText('Settimane')).toHaveValue(8)
  })
})
