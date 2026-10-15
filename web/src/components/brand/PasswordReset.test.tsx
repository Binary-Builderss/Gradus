import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { PasswordReset } from './PasswordReset'

const { sendPasswordReset } = vi.hoisted(() => ({ sendPasswordReset: vi.fn(async () => {}) }))
vi.mock('@/lib/account', () => ({ sendPasswordReset }))

function setup() {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <PasswordReset email="coach@test.dev" />
    </QueryClientProvider>,
  )
}

beforeEach(() => sendPasswordReset.mockReset().mockResolvedValue(undefined))

describe('PasswordReset', () => {
  it('manda l’email e dice di controllare la posta, senza permettere un secondo invio', async () => {
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Cambia password' }))
    await waitFor(() => expect(sendPasswordReset).toHaveBeenCalledWith('coach@test.dev'))
    expect(await screen.findByText(/Email inviata/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Cambia password' })).toBeDisabled()
  })

  it('se l’invio fallisce lo dice e si può riprovare', async () => {
    sendPasswordReset.mockRejectedValueOnce(new Error('rete'))
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Cambia password' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Non riesco a inviare l’email')
    expect(screen.getByRole('button', { name: 'Cambia password' })).toBeEnabled()
  })
})
