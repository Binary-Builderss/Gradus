import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { ProfileForm } from './ProfileForm'

const { saveProfileName } = vi.hoisted(() => ({ saveProfileName: vi.fn(async () => {}) }))
vi.mock('@/lib/profile', () => ({ saveProfileName }))

function setup(fullName: string | null) {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <ProfileForm userId="u1" profile={{ fullName, email: 'coach@test.dev', disabledAt: null }} />
    </QueryClientProvider>,
  )
}

describe('ProfileForm', () => {
  it('mostra il nome attuale e l’email, che non si cambia', () => {
    setup('Marco Bianchi')
    expect(screen.getByLabelText('Nome e cognome')).toHaveValue('Marco Bianchi')
    expect(screen.getByText('coach@test.dev')).toBeInTheDocument()
  })

  it('salva il nome scritto', async () => {
    setup(null)
    await userEvent.type(screen.getByLabelText('Nome e cognome'), 'Marco Bianchi')
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    await waitFor(() => expect(saveProfileName).toHaveBeenCalledWith('u1', 'Marco Bianchi'))
    expect(await screen.findByText('Salvato')).toBeInTheDocument()
  })
})
