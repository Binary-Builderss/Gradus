import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { DangerZone } from './DangerZone'

const { setAccountDisabled, deleteAccount, signOut, navigate, AccountError } = vi.hoisted(() => ({
  AccountError: class extends Error {
    code: string | undefined
    constructor(code: string | undefined) {
      super(code)
      this.code = code
    }
  },
  setAccountDisabled: vi.fn(async () => {}),
  deleteAccount: vi.fn(async () => {}),
  signOut: vi.fn(async () => {}),
  navigate: vi.fn(async () => {}),
}))
vi.mock('@/lib/account', () => ({ setAccountDisabled, deleteAccount, AccountError }))
vi.mock('@/lib/supabase', () => ({ supabase: { auth: { signOut } } }))
vi.mock('@tanstack/react-router', () => ({
  useNavigate: () => navigate,
  Link: ({ to, children }: { to: string; children: React.ReactNode }) => <a href={to}>{children}</a>,
}))

beforeEach(() => {
  vi.clearAllMocks()
  Element.prototype.hasPointerCapture ??= () => false
  Element.prototype.releasePointerCapture ??= () => {}
  Element.prototype.scrollIntoView ??= () => {}
})

function setup() {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <DangerZone userId="u1" email="Coach@Test.dev" />
    </QueryClientProvider>,
  )
}

describe('DangerZone', () => {
  it('disattivare chiede conferma, poi disattiva ed esce', async () => {
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Disattiva' }))
    expect(await screen.findByText('Disattivare l’account?')).toBeInTheDocument()
    expect(setAccountDisabled).not.toHaveBeenCalled()
    await userEvent.click(screen.getByRole('button', { name: 'Disattiva l’account' }))
    await waitFor(() => expect(setAccountDisabled).toHaveBeenCalledWith('u1', true))
    await waitFor(() => expect(signOut).toHaveBeenCalled())
  })

  it('eliminare elenca le conseguenze e resta bloccato finché non scrivi l’email', async () => {
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Elimina…' }))
    expect(await screen.findByText(/restano ai tuoi atleti/)).toBeInTheDocument()
    const confirm = screen.getByRole('button', { name: 'Elimina per sempre' })
    expect(confirm).toBeDisabled()
    await userEvent.type(screen.getByLabelText('Email di conferma'), 'altra@test.dev')
    expect(confirm).toBeDisabled()
  })

  it('con l’email giusta (senza badare a maiuscole e spazi) cancella, esce e torna all’accesso', async () => {
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Elimina…' }))
    await userEvent.type(await screen.findByLabelText('Email di conferma'), '  coach@test.dev ')
    await userEvent.click(screen.getByRole('button', { name: 'Elimina per sempre' }))
    await waitFor(() => expect(deleteAccount).toHaveBeenCalledWith('  coach@test.dev '))
    await waitFor(() => expect(navigate).toHaveBeenCalledWith({ to: '/login' }))
    expect(signOut).toHaveBeenCalled()
  })

  it('con un abbonamento che si rinnova spiega di disdire prima e rimanda ai piani', async () => {
    deleteAccount.mockRejectedValueOnce(new AccountError('subscription_active'))
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Elimina…' }))
    await userEvent.type(await screen.findByLabelText('Email di conferma'), 'coach@test.dev')
    await userEvent.click(screen.getByRole('button', { name: 'Elimina per sempre' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('abbonamento che si rinnova ancora')
    expect(screen.getByRole('link', { name: 'Vai a Piano e abbonamento' })).toHaveAttribute('href', '/piani')
    expect(signOut).not.toHaveBeenCalled()
  })

  it('l’avviso sull’abbonamento sta già nell’elenco delle conseguenze e nella disattivazione', async () => {
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Elimina…' }))
    expect(await screen.findByText(/disdicilo prima: l’eliminazione non lo ferma/)).toBeInTheDocument()
  })

  it('se la cancellazione fallisce lo dice e non esce', async () => {
    deleteAccount.mockRejectedValueOnce(new Error('boom'))
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Elimina…' }))
    await userEvent.type(await screen.findByLabelText('Email di conferma'), 'coach@test.dev')
    await userEvent.click(screen.getByRole('button', { name: 'Elimina per sempre' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Non è andata a buon fine')
    expect(signOut).not.toHaveBeenCalled()
    expect(navigate).not.toHaveBeenCalled()
  })
})
