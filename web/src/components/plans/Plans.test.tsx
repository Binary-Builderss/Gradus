import { render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { Plans } from './Plans'

afterEach(() => vi.unstubAllEnvs())

describe('Plans', () => {
  it('senza link di acquisto il Pro è «Presto disponibile» e non cliccabile', () => {
    vi.stubEnv('VITE_PRO_CHECKOUT_URL', '')
    render(<Plans pro={false} />)
    expect(screen.getByRole('button', { name: 'Presto disponibile' })).toBeDisabled()
    expect(screen.queryByRole('link', { name: 'Passa a Pro' })).not.toBeInTheDocument()
  })

  it('con il link di acquisto il pulsante porta lì', () => {
    vi.stubEnv('VITE_PRO_CHECKOUT_URL', 'https://buy.example.com/gradus-pro')
    render(<Plans pro={false} />)
    expect(screen.getByRole('link', { name: 'Passa a Pro' })).toHaveAttribute(
      'href',
      'https://buy.example.com/gradus-pro',
    )
  })

  it('evidenzia il piano attuale: gratuito senza Pro', () => {
    render(<Plans pro={false} />)
    const free = screen.getByRole('region', { name: 'Gratuito' })
    expect(free).toHaveTextContent('Il tuo piano attuale')
    expect(screen.getByRole('region', { name: 'Pro' })).not.toHaveTextContent('Il tuo piano attuale')
  })

  it('con il Pro attivo niente acquisto e conferma delle funzioni', () => {
    render(<Plans pro />)
    expect(screen.getByRole('region', { name: 'Pro' })).toHaveTextContent('Il tuo piano attuale')
    expect(screen.queryByRole('link', { name: 'Passa a Pro' })).not.toBeInTheDocument()
    expect(screen.getByText(/Hai tutte le funzioni/)).toBeInTheDocument()
  })

  it('elenca le funzioni reali di ogni piano', () => {
    render(<Plans pro={false} />)
    expect(screen.getByText(/PDF della scheda in stile Gradus/)).toBeInTheDocument()
    expect(screen.getByText(/il tuo logo, il tuo nome e i tuoi colori/)).toBeInTheDocument()
  })
})
