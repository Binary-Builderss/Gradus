import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { ProgressionForm } from './ProgressionForm'

const { applyProgression } = vi.hoisted(() => ({ applyProgression: vi.fn(async (): Promise<number> => 4) }))
vi.mock('@/lib/blocks', () => ({ applyProgression }))

function setup() {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <ProgressionForm mesocycleId="m1" blockId="b1" />
    </QueryClientProvider>,
  )
}
beforeEach(() => applyProgression.mockClear())

describe('ProgressionForm', () => {
  it('senza le serie della prima settimana non applica', async () => {
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Applica' }))
    expect(await screen.findByText('Indica le serie della prima settimana.')).toBeInTheDocument()
    expect(applyProgression).not.toHaveBeenCalled()
  })

  it('manda la regola alla funzione e mostra le settimane scritte', async () => {
    setup()
    await userEvent.type(screen.getByLabelText('Serie, prima settimana'), '3')
    await userEvent.type(screen.getByLabelText('Serie, variazione a settimana'), '1')
    await userEvent.selectOptions(screen.getByLabelText('Metodo'), 'BUF')
    await userEvent.type(screen.getByLabelText('Valore, prima settimana'), '3')
    await userEvent.type(screen.getByLabelText('Valore, variazione a settimana'), '-1')
    await userEvent.click(screen.getByRole('button', { name: 'Applica' }))
    await waitFor(() => expect(applyProgression).toHaveBeenCalledTimes(1))
    expect(applyProgression).toHaveBeenCalledWith('b1', {
      sets: { start: 3, step: 1 },
      method: 'BUF',
      intensity: { start: 3, step: -1 },
    })
    expect(await screen.findByText('Scritte 4 settimane.')).toBeInTheDocument()
  })

  it('metodo senza valore: errore, nessuna chiamata', async () => {
    setup()
    await userEvent.type(screen.getByLabelText('Serie, prima settimana'), '3')
    await userEvent.selectOptions(screen.getByLabelText('Metodo'), 'RPE')
    await userEvent.click(screen.getByRole('button', { name: 'Applica' }))
    expect(await screen.findByText('Metodo e valore vanno insieme.')).toBeInTheDocument()
    expect(applyProgression).not.toHaveBeenCalled()
  })

  it('errore del server: messaggio chiaro', async () => {
    applyProgression.mockRejectedValueOnce(new Error('22023'))
    setup()
    await userEvent.type(screen.getByLabelText('Serie, prima settimana'), '3')
    await userEvent.click(screen.getByRole('button', { name: 'Applica' }))
    expect(await screen.findByText(/Non sono riuscito ad applicare/)).toBeInTheDocument()
  })
})
