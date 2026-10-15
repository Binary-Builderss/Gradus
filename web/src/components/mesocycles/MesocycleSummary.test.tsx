import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, within } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { MesocycleSummary } from './MesocycleSummary'

vi.mock('@/lib/supabase', () => ({ supabase: {} }))
vi.mock('@/lib/summary', async (original) => ({
  ...(await original<typeof import('@/lib/summary')>()),
  weeklyVolumeQuery: () => ({
    queryKey: ['v'],
    queryFn: async () => [
      { week: 1, muscle: 'chest', prescribed: 5, executed: 2 },
      { week: 2, muscle: 'chest', prescribed: 4, executed: 0 },
      { week: 1, muscle: 'triceps', prescribed: 1.5, executed: 0 },
    ],
  }),
  exerciseProgressQuery: () => ({
    queryKey: ['p'],
    queryFn: async () => [
      {
        exerciseId: 'e1',
        exerciseName: 'Panca',
        week: 1,
        setsPrescribed: 3,
        setsDone: 3,
        topLoadKg: 90,
        topReps: 5,
        e1rm: 105,
      },
      {
        exerciseId: 'e1',
        exerciseName: 'Panca',
        week: 2,
        setsPrescribed: 3,
        setsDone: 3,
        topLoadKg: 92.5,
        topReps: 5,
        e1rm: 108,
      },
    ],
  }),
  doneWorkoutsQuery: () => ({ queryKey: ['d'], queryFn: async () => [{ session_id: 's1', week: 1 }] }),
}))

const block = {
  id: 'b1',
  slot_id: 'sl1',
  position: 0,
  role: 'working' as const,
  technique: 'none' as const,
  tut_eccentric_s: null,
  tut_bottom_pause_s: null,
  tut_concentric_s: null,
  tut_top_pause_s: null,
  rest_s: null,
  prep_s: null,
  ref_block_id: null,
}
const cell = (week: number, sets: number) => ({
  block_id: 'b1',
  week,
  sets,
  repsMin: 8,
  repsMax: 8,
  method: null,
  value: null,
  refPct: null,
})

function setup(sessions = [{ id: 's1', name: 'Spinta' }]) {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <MesocycleSummary
        mesocycleId="m1"
        totalWeeks={3}
        deloadWeeks={[3]}
        sessions={sessions}
        groups={[
          {
            id: 'g1',
            session_id: 's1',
            position: 0,
            kind: 'single',
            rest_between_s: 0,
            rest_after_round_s: 0,
          },
        ]}
        slots={[{ id: 'sl1', group_id: 'g1', position: 0, exercise_id: 'e1', exercise_name: 'Panca' }]}
        blocks={[block]}
        weeks={[cell(1, 3), cell(2, 4)]}
      />
    </QueryClientProvider>,
  )
}

describe('MesocycleSummary', () => {
  it('mostra le serie di ogni seduta per settimana e segna quelle eseguite', async () => {
    setup()
    const row = screen.getByRole('row', { name: /Spinta/ })
    expect(row).toHaveTextContent('3')
    expect(row).toHaveTextContent('4')
    expect(await within(row).findByText('Eseguita')).toBeInTheDocument()
  })

  it('senza sedute spiega cosa fare', () => {
    setup([])
    expect(screen.getByText(/Aggiungi una seduta/)).toBeInTheDocument()
  })

  it('mostra il volume per muscolo, dal più allenato, con le serie già fatte', async () => {
    setup()
    const chest = await screen.findByRole('row', { name: /Petto/ })
    expect(chest).toHaveTextContent('5')
    expect(chest).toHaveTextContent('fatte 2')
    expect(chest).toHaveTextContent('9') // totale
    const rows = screen.getAllByRole('row').map((r) => r.textContent)
    expect(rows.findIndex((t) => t?.startsWith('Petto'))).toBeLessThan(
      rows.findIndex((t) => t?.startsWith('Tricipiti')),
    )
  })

  it('mostra la miglior serie di ogni settimana e il massimale stimato con la variazione', async () => {
    setup()
    const row = await screen.findByRole('row', { name: /Panca/ })
    expect(row).toHaveTextContent('90 × 5')
    expect(row).toHaveTextContent('92,5 × 5')
    expect(row).toHaveTextContent('3/3 serie')
    expect(row).toHaveTextContent('108 kg')
    expect(row).toHaveTextContent('+3 kg')
  })
})
