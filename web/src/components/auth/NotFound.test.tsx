import { render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { NotFound } from './NotFound'

vi.mock('@tanstack/react-router', () => ({
  Link: ({ to, children, className }: { to: string; children: React.ReactNode; className?: string }) => (
    <a href={to} className={className}>
      {children}
    </a>
  ),
}))

describe('NotFound', () => {
  it('dice che la pagina non c’è e porta all’accesso', () => {
    render(<NotFound />)
    expect(screen.getByRole('heading', { name: 'Pagina non trovata' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Vai all’accesso' })).toHaveAttribute('href', '/login')
  })
})
