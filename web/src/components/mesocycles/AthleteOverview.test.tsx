import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { AthleteOverview } from './AthleteOverview'

vi.mock('@/lib/supabase', () => ({ supabase: {} }))
vi.mock('@tanstack/react-router', () => ({
  Link: ({ children }: { children: React.ReactNode }) => <a href="#">{children}</a>,
}))
vi.mock('@/lib/athletes', () => ({
  athletesQuery: () => ({
    queryKey: ['athletes'],
    queryFn: async () => [{ id: 'a1', lastWorkoutAt: new Date().toISOString(), workoutsLast7Days: 2 }],
  }),
}))
vi.mock('@/lib/mesocycles', () => ({
  sessionsQuery: () => ({ queryKey: ['s'], queryFn: async () => [{ id: 's1' }, { id: 's2' }, { id: 's3' }] }),
}))
const done = vi.hoisted(() => ({ rows: [] as { session_id: string; week: number }[] }))
vi.mock('@/lib/summary', () => ({
  doneWorkoutsQuery: () => ({ queryKey: ['d'], queryFn: async () => done.rows }),
}))

const start = new Date(Date.now() - 10 * 86_400_000).toISOString().slice(0, 10)
const mesocycle = { id: 'm1', name: 'Blocco 1', start_date: start, weeks: 4 }

function setup() {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <AthleteOverview coachId="c1" athleteId="a1" mesocycle={mesocycle} />
    </QueryClientProvider>,
  )
}

describe('AthleteOverview', () => {
  it('dice a che punto è il mesociclo, le sedute eseguite e quando si è allenato', async () => {
    done.rows = [
      { session_id: 's1', week: 1 },
      { session_id: 's2', week: 1 },
      { session_id: 's1', week: 2 },
    ]
    setup()
    expect(screen.getByText(/settimana 2 di 4/)).toBeInTheDocument()
    expect(await screen.findByText('3 su 12')).toBeInTheDocument()
    expect(await screen.findByText('Oggi')).toBeInTheDocument()
    expect(screen.getByText('2 sedute')).toBeInTheDocument()
    expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '25')
  })

  it('senza sedute registrate spiega che compariranno dall’app', async () => {
    done.rows = []
    setup()
    expect(await screen.findByText(/compariranno quando l’atleta si allena/)).toBeInTheDocument()
  })
})
