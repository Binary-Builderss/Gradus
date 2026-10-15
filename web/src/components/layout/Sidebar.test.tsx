import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { TooltipProvider } from '@/components/ui/tooltip'
import { useSidebarCollapsed } from '@/lib/useSidebarCollapsed'
import { Sidebar } from './Sidebar'

vi.mock('@/lib/supabase', () => ({ supabase: {} }))
vi.mock('@tanstack/react-router', () => ({
  Link: ({ to, children, className }: { to: string; children: unknown; className?: string }) => (
    <a href={to} className={className}>
      {typeof children === 'function' ? children({ isActive: to === '/' }) : (children as React.ReactNode)}
    </a>
  ),
}))

function Harness({ onSignOut = () => {}, onStartTour = () => {} }) {
  const [collapsed, toggle] = useSidebarCollapsed()
  return (
    <TooltipProvider>
      <Sidebar
        collapsed={collapsed}
        onToggle={toggle}
        name="Marco Bianchi"
        email="marco@test.dev"
        onStartTour={onStartTour}
        onSignOut={onSignOut}
      />
    </TooltipProvider>
  )
}

beforeEach(() => localStorage.clear())

describe('Sidebar', () => {
  it('esteso: sezioni di lavoro, guida, impostazioni, nome ed email', () => {
    render(<Harness />)
    const nav = screen.getByRole('navigation', { name: 'Menu principale' })
    expect(nav).toHaveTextContent('Atleti')
    expect(nav).toHaveTextContent('Esercizi')
    expect(screen.getByRole('link', { name: 'Impostazioni' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Guida' })).toBeInTheDocument()
    expect(screen.getByText('Marco Bianchi')).toBeInTheDocument()
    expect(screen.getByText('marco@test.dev')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Comprimi il menu' })).toHaveAttribute('aria-expanded', 'true')
  })

  it('compresso: restano le voci con il nome accessibile e il pulsante per riaprire', async () => {
    render(<Harness />)
    await userEvent.click(screen.getByRole('button', { name: 'Comprimi il menu' }))
    expect(screen.getByRole('link', { name: 'Atleti' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Impostazioni' })).toBeInTheDocument()
    expect(screen.queryByText('marco@test.dev')).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Espandi il menu' })).toHaveAttribute('aria-expanded', 'false')
  })

  it('ricorda la scelta tra una visita e l’altra', async () => {
    const { unmount } = render(<Harness />)
    await userEvent.click(screen.getByRole('button', { name: 'Comprimi il menu' }))
    unmount()
    render(<Harness />)
    expect(screen.getByRole('button', { name: 'Espandi il menu' })).toBeInTheDocument()
  })

  it('funziona anche se il browser non permette di salvare', async () => {
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new Error('bloccato')
    })
    render(<Harness />)
    await userEvent.click(screen.getByRole('button', { name: 'Comprimi il menu' }))
    expect(screen.getByRole('button', { name: 'Espandi il menu' })).toBeInTheDocument()
    vi.restoreAllMocks()
  })

  it('guida ed esci chiamano le azioni, anche da compresso', async () => {
    const onSignOut = vi.fn()
    const onStartTour = vi.fn()
    render(<Harness onSignOut={onSignOut} onStartTour={onStartTour} />)
    await userEvent.click(screen.getByRole('button', { name: 'Comprimi il menu' }))
    await userEvent.click(screen.getByRole('button', { name: 'Guida' }))
    await userEvent.click(screen.getByRole('button', { name: 'Esci' }))
    expect(onStartTour).toHaveBeenCalled()
    expect(onSignOut).toHaveBeenCalled()
  })
})
