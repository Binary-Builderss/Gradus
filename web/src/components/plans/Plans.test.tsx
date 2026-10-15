import { render, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import type { Plan, PlanUsage } from '@/lib/plans'
import { Plans } from './Plans'

vi.mock('@/lib/supabase', () => ({ supabase: {} }))
afterEach(() => vi.unstubAllEnvs())

const limits: Record<Plan, number | null> = { free: 20, mid: 60, pro: 100, unlimited: null }
const usage = (plan: Plan, athletes = 12, extra: Partial<PlanUsage> = {}): PlanUsage => ({
  plan,
  athleteLimit: limits[plan],
  athletes,
  canCustomize: plan === 'pro' || plan === 'unlimited',
  renewsUntil: null,
  cancelAtPeriodEnd: false,
  hasSubscription: false,
  ...extra,
})
const card = (name: string) => screen.getByRole('region', { name })

describe('Plans', () => {
  it('mostra i quattro livelli con il loro tetto di atleti', () => {
    render(<Plans usage={usage('free')} limits={limits} />)
    expect(card('Gratuito')).toHaveTextContent('Fino a 20 atleti')
    expect(card('Mid')).toHaveTextContent('Fino a 60 atleti')
    expect(card('Pro')).toHaveTextContent('Fino a 100 atleti')
    expect(card('Unlimited')).toHaveTextContent('Atleti senza limite')
  })

  it('dice quanti posti usi, con la barra', () => {
    render(<Plans usage={usage('free', 12)} limits={limits} />)
    expect(screen.getAllByText('Hai 12 atleti su 20.').length).toBeGreaterThan(0)
    expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '12')
  })

  it('Unlimited non ha barra né tetto', () => {
    render(<Plans usage={usage('unlimited', 340)} limits={limits} />)
    expect(screen.getByText(/Hai 340 atleti: il tuo piano non ha un tetto/)).toBeInTheDocument()
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
  })

  it('evidenzia il piano attuale e propone solo quelli sopra', () => {
    render(<Plans usage={usage('mid')} limits={limits} />)
    expect(card('Mid')).toHaveTextContent('Il tuo piano attuale')
    expect(within(card('Gratuito')).queryByText(/Passa a|Presto/)).not.toBeInTheDocument()
    expect(within(card('Mid')).queryByText(/Passa a|Presto/)).not.toBeInTheDocument()
    expect(within(card('Pro')).getByText('Presto disponibile')).toBeInTheDocument()
    expect(within(card('Unlimited')).getByText('Presto disponibile')).toBeInTheDocument()
  })

  it('con il link di acquisto il pulsante del piano porta lì', () => {
    vi.stubEnv('VITE_CHECKOUT_URL_PRO', 'https://buy.example.com/gradus-pro')
    render(<Plans usage={usage('free')} limits={limits} />)
    expect(within(card('Pro')).getByRole('link', { name: 'Passa a Pro' })).toHaveAttribute(
      'href',
      'https://buy.example.com/gradus-pro',
    )
    expect(within(card('Mid')).getByText('Presto disponibile')).toBeInTheDocument()
  })

  it('Personalizza compare nel Pro, non nel Mid', () => {
    render(<Plans usage={usage('free')} limits={limits} />)
    expect(card('Pro')).toHaveTextContent('Personalizza')
    expect(card('Mid')).not.toHaveTextContent('Personalizza')
  })

  it('il Gratuito non ha una sezione abbonamento', () => {
    render(<Plans usage={usage('free')} limits={limits} />)
    expect(screen.queryByRole('region', { name: 'Il tuo abbonamento' })).not.toBeInTheDocument()
  })

  it('con un abbonamento attivo dice quando si rinnova e cosa succede se disdici', () => {
    render(
      <Plans
        usage={usage('pro', 40, { hasSubscription: true, renewsUntil: '2026-11-12T00:00:00Z' })}
        limits={limits}
      />,
    )
    const sub = screen.getByRole('region', { name: 'Il tuo abbonamento' })
    expect(sub).toHaveTextContent('Si rinnova il 12 novembre 2026')
    expect(sub).toHaveTextContent(
      'non perdi nessun dato e tieni tutti i tuoi atleti, ma ne puoi aggiungere solo fino a 20',
    )
    expect(within(sub).getByRole('button', { name: 'Disdetta presto disponibile' })).toBeDisabled()
  })

  it('con il portale configurato il pulsante porta a gestire e disdire', () => {
    vi.stubEnv('VITE_BILLING_PORTAL_URL', 'https://billing.example.com/p/abc')
    render(
      <Plans
        usage={usage('mid', 10, { hasSubscription: true, renewsUntil: '2026-11-12T00:00:00Z' })}
        limits={limits}
      />,
    )
    expect(screen.getByRole('link', { name: 'Gestisci o disdici l’abbonamento' })).toHaveAttribute(
      'href',
      'https://billing.example.com/p/abc',
    )
  })

  it('disdetto: resta attivo fino alla data e poi torna Gratuito', () => {
    render(
      <Plans
        usage={usage('pro', 40, {
          hasSubscription: true,
          cancelAtPeriodEnd: true,
          renewsUntil: '2026-11-12T00:00:00Z',
        })}
        limits={limits}
      />,
    )
    expect(screen.getByRole('region', { name: 'Il tuo abbonamento' })).toHaveTextContent(
      'Disdetto: il piano resta attivo fino al 12 novembre 2026, poi torni al Gratuito',
    )
  })

  it('piano assegnato a mano: nessun addebito e nessun pulsante di disdetta', () => {
    render(<Plans usage={usage('pro')} limits={limits} />)
    const sub = screen.getByRole('region', { name: 'Il tuo abbonamento' })
    expect(sub).toHaveTextContent('senza scadenza e senza addebiti')
    expect(within(sub).queryByRole('button')).not.toBeInTheDocument()
  })
})
