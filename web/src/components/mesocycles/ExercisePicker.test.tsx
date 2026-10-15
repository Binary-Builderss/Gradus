import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { ExercisePicker } from './ExercisePicker'

vi.mock('@/lib/supabase', () => ({ supabase: {} }))
vi.mock('@tanstack/react-router', () => ({
  Link: ({ children }: { children: React.ReactNode }) => <a href="#">{children}</a>,
}))
vi.mock('@/lib/slots', () => ({
  exercisesQuery: () => ({
    queryKey: ['ex'],
    queryFn: async () => [
      {
        id: 'e1',
        name: 'Panca piana',
        owner_id: null,
        muscles: [
          { muscle: 'chest', weight: 1 },
          { muscle: 'triceps', weight: 0.5 },
        ],
      },
      { id: 'e2', name: 'Rematore', owner_id: null, muscles: [{ muscle: 'lats', weight: 1 }] },
      { id: 'e3', name: 'Squat a corpo libero', owner_id: 'c1', muscles: [{ muscle: 'quads', weight: 1 }] },
    ],
  }),
}))

function setup() {
  const onPick = vi.fn()
  const onClose = vi.fn()
  render(
    <QueryClientProvider client={new QueryClient()}>
      <ExercisePicker coachId="c1" onPick={onPick} onClose={onClose} />
    </QueryClientProvider>,
  )
  return { onPick, onClose }
}

describe('ExercisePicker', () => {
  it('elenca gli esercizi con i muscoli principali e segna i propri', async () => {
    setup()
    expect(await screen.findByText('Panca piana')).toBeInTheDocument()
    expect(screen.getByText('Petto, Tricipiti')).toBeInTheDocument()
    expect(screen.getByText('Mio')).toBeInTheDocument()
    expect(screen.getByText('3 esercizi')).toBeInTheDocument()
  })

  it('cerca senza badare ad accenti e maiuscole', async () => {
    setup()
    await screen.findByText('Panca piana')
    await userEvent.type(screen.getByRole('combobox'), 'RÉMATORE')
    expect(screen.getAllByRole('option')).toHaveLength(1)
    expect(screen.getByText('Rematore')).toBeInTheDocument()
  })

  it('filtra per gruppo muscolare', async () => {
    setup()
    await screen.findByText('Panca piana')
    await userEvent.click(screen.getByRole('button', { name: 'Gambe' }))
    expect(screen.getAllByRole('option').map((o) => o.textContent)).toEqual([
      expect.stringContaining('Squat'),
    ])
  })

  it('frecce e Invio scelgono senza il mouse, Esc chiude', async () => {
    const { onPick, onClose } = setup()
    await screen.findByText('Panca piana')
    await userEvent.type(screen.getByRole('combobox'), '{ArrowDown}{Enter}')
    expect(onPick).toHaveBeenCalledWith('e2')
    await userEvent.keyboard('{Escape}')
    expect(onClose).toHaveBeenCalled()
  })

  it('senza risultati spiega cosa fare e rimanda alla libreria', async () => {
    setup()
    await screen.findByText('Panca piana')
    await userEvent.type(screen.getByRole('combobox'), 'zzz')
    expect(screen.getByText('Nessun esercizio trovato.')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Apri la libreria esercizi' })).toBeInTheDocument()
  })
})
