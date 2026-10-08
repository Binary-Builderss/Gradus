import { fireEvent, render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { messages } from '@/lib/messages'
import { LoginForm } from './forms'

const m = messages.auth

function fill(label: string, value: string) {
  fireEvent.change(screen.getByLabelText(label), { target: { value } })
}

describe('LoginForm', () => {
  it('valida i campi senza chiamare il server', async () => {
    const onSubmit = vi.fn()
    render(<LoginForm onSubmit={onSubmit} />)
    fireEvent.click(screen.getByRole('button', { name: m.login.submit }))
    expect(await screen.findByText(m.errors.emailInvalid)).toBeInTheDocument()
    expect(screen.getByText(m.errors.passwordRequired)).toBeInTheDocument()
    expect(onSubmit).not.toHaveBeenCalled()
  })

  it("mostra l'errore restituito dal server", async () => {
    const onSubmit = vi.fn().mockResolvedValue(m.errors.invalidCredentials)
    render(<LoginForm onSubmit={onSubmit} />)
    fill(m.email, 'coach@gradus.app')
    fill(m.password, 'sbagliata')
    fireEvent.click(screen.getByRole('button', { name: m.login.submit }))
    expect(await screen.findByRole('alert')).toHaveTextContent(m.errors.invalidCredentials)
    expect(onSubmit).toHaveBeenCalledWith({ email: 'coach@gradus.app', password: 'sbagliata' })
  })

  it('mostra e nasconde la password', () => {
    render(<LoginForm onSubmit={vi.fn()} />)
    const input = screen.getByLabelText(m.password)
    expect(input).toHaveAttribute('type', 'password')
    fireEvent.click(screen.getByRole('button', { name: m.showPassword }))
    expect(input).toHaveAttribute('type', 'text')
  })
})
