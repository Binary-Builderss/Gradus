import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { BrandForm } from './BrandForm'

const { saveBranding } = vi.hoisted(() => ({ saveBranding: vi.fn(async () => {}) }))
vi.mock('@/lib/branding', () => ({ saveBranding }))

function setup(pro: boolean, initial = null as Parameters<typeof BrandForm>[0]['initial']) {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <BrandForm coachId="c1" fallbackName="coach@test.dev" initial={initial} pro={pro} />
    </QueryClientProvider>,
  )
}

beforeEach(() => saveBranding.mockClear())

describe('BrandForm', () => {
  it('senza piano pro è bloccato e lo dice', () => {
    setup(false)
    expect(screen.getByText(/funzione del piano Pro/)).toBeInTheDocument()
    expect(screen.getByLabelText('Nome del marchio')).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Salva' })).toBeDisabled()
  })

  it('parte dai colori standard e salva solo quelli cambiati', async () => {
    setup(true)
    expect(screen.getByLabelText('Colore principale, codice colore')).toHaveValue('#0D54F3')
    await userEvent.type(screen.getByLabelText('Nome del marchio'), 'Studio Verde')
    const hex = screen.getByLabelText('Colore principale, codice colore')
    await userEvent.clear(hex)
    await userEvent.type(hex, '#0a7d4b')
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    await waitFor(() => expect(saveBranding).toHaveBeenCalledTimes(1))
    expect(saveBranding).toHaveBeenCalledWith('c1', {
      brandName: 'Studio Verde',
      logoPng: null,
      colors: { primary: '#0A7D4B' },
    })
    expect(await screen.findByText('Salvato')).toBeInTheDocument()
  })

  it('il selettore colore aggiorna l’anteprima e il ripristino torna allo standard', async () => {
    setup(true)
    fireEvent.change(screen.getByLabelText('Colore principale, selettore'), { target: { value: '#ff0000' } })
    expect(screen.getByLabelText('Colore principale, codice colore')).toHaveValue('#FF0000')
    await userEvent.click(screen.getByRole('button', { name: 'Ripristina colore principale' }))
    expect(screen.getByLabelText('Colore principale, codice colore')).toHaveValue('#0D54F3')
  })

  it('la forma corta del codice vale solo a fine scrittura', async () => {
    setup(true)
    const hex = screen.getByLabelText('Sfondo, codice colore')
    await userEvent.clear(hex)
    await userEvent.type(hex, '#fa0')
    expect(hex).toHaveValue('#fa0')
    await userEvent.tab()
    expect(hex).toHaveValue('#FFAA00')
  })

  it('avvisa quando il testo si legge male, senza bloccare', () => {
    setup(true, { brandName: null, logoPng: null, colors: { foreground: '#EEEEEE' } })
    expect(screen.getByText(/Il testo sullo sfondo si legge male/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Salva' })).toBeEnabled()
  })

  it('mostra il nome del profilo nell’anteprima se il nome del marchio è vuoto', () => {
    setup(true)
    expect(screen.getByText('coach@test.dev')).toBeInTheDocument()
  })
})
