import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { NutritionPlan, OverviewDay } from '@/lib/nutrition'
import { MacroSection } from './MacroSection'

const state = vi.hoisted(() => ({
  plans: [] as unknown[],
  days: [] as unknown[],
  fail: false,
  save: vi.fn<(coachId: string, athleteId: string, values: unknown) => Promise<void>>(async () => {}),
}))

vi.mock('@/lib/supabase', () => ({ supabase: {} }))
vi.mock('@/lib/nutrition', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/lib/nutrition')>()),
  nutritionPlansQuery: () => ({
    queryKey: ['nutrition-plans', 'a1'],
    retry: false,
    queryFn: async () => {
      if (state.fail) throw new Error('x')
      return state.plans
    },
  }),
  nutritionOverviewQuery: () => ({
    queryKey: ['nutrition-overview', 'a1', 'x', 'y'],
    queryFn: async () => state.days,
  }),
  saveNutritionPlan: (coachId: string, athleteId: string, values: unknown) =>
    state.save(coachId, athleteId, values),
}))

const today = new Date()
const iso = (offset: number) => {
  const d = new Date(today)
  d.setDate(d.getDate() + offset)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

const plan = (validFrom: string, kcal = 2500): NutritionPlan => ({
  id: `p-${validFrom}`,
  validFrom,
  tolerancePct: 10,
  declaredAt: '2026-10-01T10:00:00Z',
  targets: { kcal, protein_g: 180, carbs_g: 280, fat_g: 70, fiber_g: 30 },
})
const day = (
  offset: number,
  status: OverviewDay['status'],
  extra: Partial<OverviewDay> = {},
): OverviewDay => ({
  day: iso(offset),
  status,
  source: status ? 'confirm' : null,
  intake: { kcal: null, protein_g: null, carbs_g: null, fat_g: null },
  target: { kcal: 2500, protein_g: 180, carbs_g: 280, fat_g: 70 },
  tolerancePct: 10,
  ...extra,
})

const setup = () =>
  render(
    <QueryClientProvider client={new QueryClient()}>
      <MacroSection coachId="c1" athleteId="a1" />
    </QueryClientProvider>,
  )

beforeEach(() => {
  state.plans = []
  state.days = []
  state.fail = false
  state.save.mockClear()
})

describe('MacroSection: obiettivi', () => {
  it('senza obiettivi lo dice e propone di impostarli', async () => {
    setup()
    expect(await screen.findByText('Nessun obiettivo per questo atleta.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Imposta i macro' })).toBeInTheDocument()
  })

  it('mostra gli obiettivi in vigore con la tolleranza', async () => {
    state.plans = [plan(iso(-5))]
    setup()
    expect(await screen.findByText('Calorie')).toBeInTheDocument()
    expect(screen.getByText('2500')).toBeInTheDocument()
    expect(screen.getByText(/In vigore dal/)).toBeInTheDocument()
    expect(screen.getByText(/Tolleranza ±10%/)).toBeInTheDocument()
  })

  it('un piano che inizia più avanti non è ancora in vigore, ma si annuncia', async () => {
    state.plans = [plan(iso(10), 3000), plan(iso(-5), 2500)]
    setup()
    expect(await screen.findByText('2500')).toBeInTheDocument()
    expect(screen.getByText(/cambiano/)).toBeInTheDocument()
  })

  it('un errore di caricamento si dice', async () => {
    state.fail = true
    setup()
    expect(await screen.findByRole('alert')).toHaveTextContent('Non riesco a caricare i macro')
  })
})

describe('MacroSection: modulo', () => {
  async function open() {
    setup()
    await userEvent.click(await screen.findByRole('button', { name: 'Imposta i macro' }))
  }
  const fill = async (kcal = '2500', p = '180', c = '280', f = '70') => {
    await userEvent.type(screen.getByLabelText('Calorie (kcal)'), kcal)
    await userEvent.type(screen.getByLabelText('Proteine (g)'), p)
    await userEvent.type(screen.getByLabelText('Carboidrati (g)'), c)
    await userEvent.type(screen.getByLabelText('Grassi (g)'), f)
  }

  it('senza la dichiarazione non salva e lo dice', async () => {
    await open()
    await fill()
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    expect(await screen.findByText('Per salvare serve la dichiarazione.')).toBeInTheDocument()
    expect(state.save).not.toHaveBeenCalled()
  })

  it('con la dichiarazione salva i valori letti dal modulo', async () => {
    await open()
    await fill()
    await userEvent.click(screen.getByRole('checkbox', { name: /professionista abilitato/ }))
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    await waitFor(() => expect(state.save).toHaveBeenCalledTimes(1))
    expect(state.save.mock.calls[0]?.slice(0, 2)).toEqual(['c1', 'a1'])
    expect(state.save.mock.calls[0]?.[2]).toMatchObject({
      kcal: 2500,
      protein_g: 180,
      carbs_g: 280,
      fat_g: 70,
      fiber_g: null,
      tolerance_pct: 10,
      declaration: 'on',
    })
  })

  it('numeri mancanti o fuori misura: un errore per campo e nulla parte', async () => {
    await open()
    await userEvent.type(screen.getByLabelText('Calorie (kcal)'), '100')
    await userEvent.click(screen.getByRole('checkbox', { name: /professionista abilitato/ }))
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    expect(await screen.findByText('Inserisci le calorie (da 500 a 15000).')).toBeInTheDocument()
    expect(screen.getByText('Inserisci le proteine in grammi (numero intero).')).toBeInTheDocument()
    expect(state.save).not.toHaveBeenCalled()
  })

  it('avvisa se le calorie non tornano con i macro, senza bloccare', async () => {
    await open()
    await fill('4000', '180', '280', '70')
    expect(screen.getByRole('status')).toHaveTextContent('circa 2470 kcal')
  })

  it('un errore del server si dice', async () => {
    state.save.mockRejectedValueOnce(new Error('rete'))
    await open()
    await fill()
    await userEvent.click(screen.getByRole('checkbox', { name: /professionista abilitato/ }))
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    expect(await screen.findByText(/Non sono riuscito a salvare/)).toBeInTheDocument()
  })

  it('«Modifica» parte dagli obiettivi attuali', async () => {
    state.plans = [plan(iso(-5))]
    setup()
    await userEvent.click(await screen.findByRole('button', { name: 'Modifica' }))
    expect(screen.getByLabelText('Calorie (kcal)')).toHaveValue('2500')
    expect(screen.getByLabelText('Fibre (g, facoltative)')).toHaveValue('30')
  })
})

describe('MacroSection: come li sta seguendo', () => {
  it('giorni verdi, rossi e grigi: i non registrati non contano come non rispettati', async () => {
    state.plans = [plan(iso(-20))]
    state.days = [day(-3, 'respected'), day(-2, 'not_respected'), day(-1, 'respected'), day(0, null)]
    setup()
    const group = await screen.findByRole('group', { name: 'Come li sta seguendo' })
    expect(await within(group).findByText('2 giorni rispettati su 3 registrati')).toBeInTheDocument()
    expect(within(group).getAllByRole('listitem', { name: /Rispettato/ })).toHaveLength(2)
    expect(within(group).getAllByRole('listitem', { name: /Non rispettato/ })).toHaveLength(1)
    expect(within(group).getAllByRole('listitem', { name: /Non registrato/ })).toHaveLength(1)
  })

  it('con i numeri mostra lo scarto rispetto all’obiettivo e la fonte', async () => {
    state.plans = [plan(iso(-20))]
    state.days = [
      day(-1, 'not_respected', {
        source: 'healthkit',
        intake: { kcal: 2900, protein_g: 150, carbs_g: 350, fat_g: 90 },
      }),
    ]
    setup()
    expect(await screen.findByText(/2900 su 2500 \(\+16%\)/)).toBeInTheDocument()
    expect(screen.getByText('Apple Salute')).toBeInTheDocument()
  })

  it('senza giorni registrati spiega quando compariranno', async () => {
    state.plans = [plan(iso(-20))]
    state.days = [day(-1, null), day(0, null)]
    setup()
    expect(await screen.findByText(/Nessun giorno registrato/)).toBeInTheDocument()
  })

  it('senza obiettivi non mostra l’aderenza', async () => {
    setup()
    await screen.findByText('Nessun obiettivo per questo atleta.')
    expect(screen.queryByRole('group', { name: 'Come li sta seguendo' })).not.toBeInTheDocument()
  })
})
