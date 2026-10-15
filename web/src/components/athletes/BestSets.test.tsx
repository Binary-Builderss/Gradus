import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { BestSet, TopSetPoint } from '@/lib/topSets'
import { BestSets } from './BestSets'

const { sets, history } = vi.hoisted(() => ({
  sets: { list: [] as BestSet[], fail: false },
  history: { list: [] as TopSetPoint[] },
}))
vi.mock('@/lib/topSets', () => ({
  bestSetsQuery: () => ({
    queryKey: ['best-sets', 'c1', 'a1'],
    retry: false,
    queryFn: async () => {
      if (sets.fail) throw new Error('x')
      return sets.list
    },
  }),
  topSetHistoryQuery: (_: string, exerciseId: string) => ({
    queryKey: ['top-set-history', 'a1', exerciseId],
    queryFn: async () => history.list,
  }),
}))

const panca: BestSet = {
  exercise_id: 'e1',
  exercise_name: 'Panca piana',
  best_load_kg: 105,
  best_reps: 5,
  best_e1rm: 122.5,
  best_on: '2026-10-12',
  workouts: 2,
  last_on: '2026-10-12',
}
const setup = () =>
  render(
    <QueryClientProvider client={new QueryClient()}>
      <BestSets coachId="c1" athleteId="a1" />
    </QueryClientProvider>,
  )
beforeEach(() => {
  sets.list = []
  sets.fail = false
  history.list = []
})

describe('BestSets', () => {
  it('senza serie registrate spiega quando compariranno', async () => {
    setup()
    expect(await screen.findByText(/Ancora nessuna serie registrata/)).toBeInTheDocument()
  })

  it('errore: messaggio chiaro', async () => {
    sets.fail = true
    setup()
    expect(await screen.findByText('Non riesco a caricare le serie migliori.')).toBeInTheDocument()
  })

  it('una riga per esercizio con miglior serie, massimale stimato e sedute', async () => {
    sets.list = [panca]
    setup()
    expect(await screen.findByText('Panca piana')).toBeInTheDocument()
    expect(screen.getByText('105 kg × 5')).toBeInTheDocument()
    expect(screen.getByText('122,5 kg')).toBeInTheDocument()
    expect(screen.getByText(/2 sedute/)).toBeInTheDocument()
  })

  it('apre lo storico di un esercizio, seduta per seduta, e lo richiude', async () => {
    sets.list = [panca]
    history.list = [
      {
        workout_id: 'w1',
        mesocycle_name: 'Blocco 1',
        week: 1,
        performed_on: '2026-10-05',
        load_kg: 100,
        reps: 5,
        e1rm: 116.7,
      },
      {
        workout_id: 'w2',
        mesocycle_name: 'Blocco 1',
        week: 2,
        performed_on: '2026-10-12',
        load_kg: 105,
        reps: 5,
        e1rm: 122.5,
      },
    ]
    setup()
    const toggle = await screen.findByRole('button', { name: 'Mostra lo storico di Panca piana' })
    expect(toggle).toHaveAttribute('aria-expanded', 'false')
    await userEvent.click(toggle)
    const region = await screen.findByRole('region', { name: 'Storico di Panca piana' })
    expect(await screen.findByText('100 kg × 5')).toBeInTheDocument()
    expect(region).toHaveTextContent('116,7 kg')
    expect(region).toHaveTextContent('sett. 2')
    await userEvent.click(screen.getByRole('button', { name: 'Nascondi lo storico di Panca piana' }))
    expect(screen.queryByRole('region')).not.toBeInTheDocument()
  })
})
