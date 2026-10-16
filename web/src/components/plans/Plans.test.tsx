import { render, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import type { BrandingLevel, Plan, PlanLimits, PlanUsage } from '@/lib/plans'
import { Plans } from './Plans'

vi.mock('@/lib/supabase', () => ({ supabase: {} }))
afterEach(() => vi.unstubAllEnvs())

const tier = (
  athletes: number,
  mesocycleTemplates: number,
  progressionPresets: number,
  brandingLevel: BrandingLevel,
): PlanLimits => ({
  athletes,
  sessionTemplates: 0,
  mesocycleTemplates,
  progressionPresets,
  dietPlans: 0,
  dietSnapshots: 0,
  brandingLevel,
})
const limits: Record<Plan, PlanLimits> = {
  free: tier(20, 1, 20, 0),
  basic: tier(50, 5, 350, 1),
  advanced: tier(100, 10, 700, 2),
  custom: tier(500, 20, 1400, 3),
}
const usage = (plan: Plan, athletes = 12, extra: Partial<PlanUsage> = {}): PlanUsage => ({
  plan,
  athleteLimit: limits[plan].athletes,
  athletes,
  brandingLevel: limits[plan].brandingLevel,
  mesocycleTemplates: 0,
  progressionPresets: 0,
  renewsUntil: null,
  cancelAtPeriodEnd: false,
  hasSubscription: false,
  ...extra,
})
const card = (name: string) => screen.getByRole('region', { name })

describe('Plans', () => {
  it('mostra i quattro livelli con i loro tetti', () => {
    render(<Plans usage={usage('free')} limits={limits} />)
    expect(card('Free')).toHaveTextContent('Fino a 20 atleti')
    expect(card('Free')).toHaveTextContent('1 template di mesociclo')
    expect(card('Free')).toHaveTextContent('20 progressioni salvate')
    expect(card('Basic')).toHaveTextContent('Fino a 50 atleti')
    expect(card('Basic')).toHaveTextContent('5 template di mesociclo')
    expect(card('Basic')).toHaveTextContent('350 progressioni salvate')
    expect(card('Advanced')).toHaveTextContent('Fino a 100 atleti')
    expect(card('Custom')).toHaveTextContent('Fino a 500 atleti')
    expect(card('Custom')).toHaveTextContent('1400 progressioni salvate')
  })

  it('dice quanti posti usi, con la barra, e quanti template e progressioni hai salvato', () => {
    render(
      <Plans usage={usage('free', 12, { mesocycleTemplates: 1, progressionPresets: 7 })} limits={limits} />,
    )
    expect(screen.getAllByText('Hai 12 atleti su 20.').length).toBeGreaterThan(0)
    expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '12')
    expect(screen.getByText('Template: 1 su 1 · Progressioni salvate: 7 su 20')).toBeInTheDocument()
  })

  it('anche Custom ha un tetto: 500 atleti, con la barra', () => {
    render(<Plans usage={usage('custom', 340)} limits={limits} />)
    expect(screen.getAllByText('Hai 340 atleti su 500.').length).toBeGreaterThan(0)
    expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuemax', '500')
  })

  it('evidenzia il piano attuale e propone solo quelli sopra', () => {
    render(<Plans usage={usage('basic')} limits={limits} />)
    expect(card('Basic')).toHaveTextContent('Il tuo piano attuale')
    expect(within(card('Free')).queryByText(/Passa a|Presto/)).not.toBeInTheDocument()
    expect(within(card('Basic')).queryByText(/Passa a|Presto/)).not.toBeInTheDocument()
    expect(within(card('Advanced')).getByText('Presto disponibile')).toBeInTheDocument()
    expect(within(card('Custom')).getByText('Presto disponibile')).toBeInTheDocument()
  })

  it('con il link di acquisto il pulsante del piano porta lì', () => {
    vi.stubEnv('VITE_CHECKOUT_URL_ADVANCED', 'https://buy.example.com/gradus-advanced')
    render(<Plans usage={usage('free')} limits={limits} />)
    expect(within(card('Advanced')).getByRole('link', { name: 'Passa a Advanced' })).toHaveAttribute(
      'href',
      'https://buy.example.com/gradus-advanced',
    )
    expect(within(card('Basic')).getByText('Presto disponibile')).toBeInTheDocument()
  })

  it('la personalizzazione cresce con i livelli: Free niente, Basic il colore principale, Advanced la tavolozza, Custom anche il PDF senza dicitura', () => {
    render(<Plans usage={usage('free')} limits={limits} />)
    expect(card('Free')).not.toHaveTextContent('Personalizza')
    expect(card('Basic')).toHaveTextContent(
      'Personalizza: il tuo logo, il tuo nome e il tuo colore principale',
    )
    expect(card('Advanced')).toHaveTextContent('Tavolozza completa')
    expect(card('Custom')).toHaveTextContent('PDF senza la dicitura «Creato con Gradus»')
  })

  it('il piano Free non ha una sezione abbonamento', () => {
    render(<Plans usage={usage('free')} limits={limits} />)
    expect(screen.queryByRole('region', { name: 'Il tuo abbonamento' })).not.toBeInTheDocument()
  })

  it('con un abbonamento attivo dice quando si rinnova e cosa succede se disdici', () => {
    render(
      <Plans
        usage={usage('advanced', 40, { hasSubscription: true, renewsUntil: '2026-11-12T00:00:00Z' })}
        limits={limits}
      />,
    )
    const sub = screen.getByRole('region', { name: 'Il tuo abbonamento' })
    expect(sub).toHaveTextContent('Si rinnova il 12 novembre 2026')
    expect(sub).toHaveTextContent(
      'non perdi nessun dato e tieni tutti i tuoi atleti, template e progressioni, ma puoi aggiungerne solo entro i limiti del piano (atleti fino a 20)',
    )
    expect(within(sub).getByRole('button', { name: 'Disdetta presto disponibile' })).toBeDisabled()
  })

  it('con il portale configurato il pulsante porta a gestire e disdire', () => {
    vi.stubEnv('VITE_BILLING_PORTAL_URL', 'https://billing.example.com/p/abc')
    render(
      <Plans
        usage={usage('basic', 10, { hasSubscription: true, renewsUntil: '2026-11-12T00:00:00Z' })}
        limits={limits}
      />,
    )
    expect(screen.getByRole('link', { name: 'Gestisci o disdici l’abbonamento' })).toHaveAttribute(
      'href',
      'https://billing.example.com/p/abc',
    )
  })

  it('disdetto: resta attivo fino alla data e poi torna al piano Free', () => {
    render(
      <Plans
        usage={usage('advanced', 40, {
          hasSubscription: true,
          cancelAtPeriodEnd: true,
          renewsUntil: '2026-11-12T00:00:00Z',
        })}
        limits={limits}
      />,
    )
    expect(screen.getByRole('region', { name: 'Il tuo abbonamento' })).toHaveTextContent(
      'Disdetto: il piano resta attivo fino al 12 novembre 2026, poi torni al piano Free',
    )
  })

  it('piano assegnato a mano: nessun addebito e nessun pulsante di disdetta', () => {
    render(<Plans usage={usage('advanced')} limits={limits} />)
    const sub = screen.getByRole('region', { name: 'Il tuo abbonamento' })
    expect(sub).toHaveTextContent('senza scadenza e senza addebiti')
    expect(within(sub).queryByRole('button')).not.toBeInTheDocument()
  })
})
