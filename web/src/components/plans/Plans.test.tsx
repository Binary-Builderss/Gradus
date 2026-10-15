import { render, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import type { Plan, PlanUsage } from '@/lib/plans'
import { Plans } from './Plans'

vi.mock('@/lib/supabase', () => ({ supabase: {} }))
afterEach(() => vi.unstubAllEnvs())

const limits: Record<Plan, number | null> = { free: 20, mid: 60, pro: 100, unlimited: null }
const usage = (plan: Plan, athletes = 12): PlanUsage => ({
  plan,
  athleteLimit: limits[plan],
  athletes,
  canCustomize: plan === 'pro' || plan === 'unlimited',
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
})
