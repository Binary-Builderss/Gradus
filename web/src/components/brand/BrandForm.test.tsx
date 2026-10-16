import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { BrandingLevel } from '@/lib/plans'
import { BrandForm } from './BrandForm'

const { saveBranding } = vi.hoisted(() => ({
  saveBranding: vi.fn(async (_coachId: string, _branding: unknown) => {}),
}))
vi.mock('@/lib/branding', () => ({ saveBranding }))

function setup(level: BrandingLevel, initial = null as Parameters<typeof BrandForm>[0]['initial']) {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <BrandForm coachId="c1" fallbackName="coach@test.dev" initial={initial} level={level} />
    </QueryClientProvider>,
  )
}

beforeEach(() => saveBranding.mockClear())

describe('BrandForm', () => {
  it('senza un piano con Personalizza è bloccato e lo dice', () => {
    setup(0)
    expect(screen.getByText(/parte dal piano Basic/)).toBeInTheDocument()
    expect(screen.getByLabelText('Nome del marchio')).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Salva' })).toBeDisabled()
  })

  it('parte dai colori standard e salva solo quelli cambiati', async () => {
    setup(3)
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
      hideGradusCredit: false,
    })
    expect(await screen.findByText('Salvato')).toBeInTheDocument()
  })

  it('il selettore colore aggiorna l’anteprima e il ripristino torna allo standard', async () => {
    setup(3)
    fireEvent.change(screen.getByLabelText('Colore principale, selettore'), { target: { value: '#ff0000' } })
    expect(screen.getByLabelText('Colore principale, codice colore')).toHaveValue('#FF0000')
    await userEvent.click(screen.getByRole('button', { name: 'Ripristina colore principale' }))
    expect(screen.getByLabelText('Colore principale, codice colore')).toHaveValue('#0D54F3')
  })

  it('la forma corta del codice vale solo a fine scrittura', async () => {
    setup(3)
    const hex = screen.getByLabelText('Sfondo, codice colore')
    await userEvent.clear(hex)
    await userEvent.type(hex, '#fa0')
    expect(hex).toHaveValue('#fa0')
    await userEvent.tab()
    expect(hex).toHaveValue('#FFAA00')
  })

  it('avvisa quando il testo si legge male, senza bloccare', () => {
    setup(3, { brandName: null, logoPng: null, colors: { foreground: '#EEEEEE' }, hideGradusCredit: false })
    expect(screen.getByText(/Il testo sullo sfondo si legge male/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Salva' })).toBeEnabled()
  })

  it('livello 1 (Basic): solo il colore principale; palette e dicitura Gradus restano bloccate', async () => {
    setup(1, { brandName: null, logoPng: null, colors: {}, hideGradusCredit: false })
    expect(screen.getByLabelText('Colore principale, codice colore')).toBeEnabled()
    expect(screen.getByLabelText('Sfondo, codice colore')).toBeDisabled()
    expect(screen.getByLabelText('Testo, codice colore')).toBeDisabled()
    expect(screen.getByText(/La tavolozza completa è del piano Advanced/)).toBeInTheDocument()
    expect(screen.getByRole('checkbox', { name: /Creato con Gradus/ })).toBeDisabled()
    const hex = screen.getByLabelText('Colore principale, codice colore')
    await userEvent.clear(hex)
    await userEvent.type(hex, '#0a7d4b')
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    await waitFor(() => expect(saveBranding).toHaveBeenCalledTimes(1))
    expect(saveBranding).toHaveBeenCalledWith('c1', {
      brandName: '',
      logoPng: null,
      colors: { primary: '#0A7D4B' },
      hideGradusCredit: false,
    })
  })

  it('livello 2 (Advanced): tavolozza completa, ma la dicitura Gradus resta', () => {
    setup(2, { brandName: null, logoPng: null, colors: {}, hideGradusCredit: false })
    expect(screen.getByLabelText('Sfondo, codice colore')).toBeEnabled()
    expect(screen.getByRole('checkbox', { name: /Creato con Gradus/ })).toBeDisabled()
    expect(screen.getByText(/Dal piano Custom puoi togliere la dicitura/)).toBeInTheDocument()
  })

  it('livello 3 (Custom): si toglie la dicitura Gradus dal PDF e si salva', async () => {
    setup(3)
    const credit = screen.getByRole('checkbox', { name: /Creato con Gradus/ })
    expect(credit).toBeEnabled()
    await userEvent.click(credit)
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    await waitFor(() => expect(saveBranding).toHaveBeenCalledTimes(1))
    expect(saveBranding.mock.calls[0]?.[1]).toMatchObject({ hideGradusCredit: true })
  })

  it('mostra il nome del profilo nell’anteprima se il nome del marchio è vuoto', () => {
    setup(3)
    expect(screen.getByText('coach@test.dev')).toBeInTheDocument()
  })
})
