import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { TooltipProvider } from '@/components/ui/tooltip'
import { useSidebarCollapsed } from '@/lib/useSidebarCollapsed'
import { Sidebar } from './Sidebar'

vi.mock('@/lib/supabase', () => ({ supabase: {} }))
vi.mock('@tanstack/react-router', () => ({
  Link: ({
    to,
    children,
    ...props
  }: { to: string; children: React.ReactNode | ((state: { isActive: boolean }) => React.ReactNode) } & Omit<
    React.ComponentProps<'a'>,
    'children'
  >) => (
    <a href={to} {...props}>
      {typeof children === 'function' ? children({ isActive: to === '/' }) : children}
    </a>
  ),
}))

function Harness({ onSignOut = () => {}, onStartTour = () => {}, pro = true as boolean | undefined }) {
  const [collapsed, toggle] = useSidebarCollapsed()
  return (
    <TooltipProvider>
      <Sidebar
        collapsed={collapsed}
        onToggle={toggle}
        name="Marco Bianchi"
        email="marco@test.dev"
        pro={pro}
        onStartTour={onStartTour}
        onSignOut={onSignOut}
      />
    </TooltipProvider>
  )
}

beforeEach(() => {
  localStorage.clear()
  // jsdom non ha queste funzioni, che il menu di Radix usa.
  Element.prototype.hasPointerCapture ??= () => false
  Element.prototype.releasePointerCapture ??= () => {}
  Element.prototype.scrollIntoView ??= () => {}
})

describe('Sidebar', () => {
  it('esteso: sezioni di lavoro, guida e la riga dell’account con nome ed email', () => {
    render(<Harness />)
    const nav = screen.getByRole('navigation', { name: 'Menu principale' })
    expect(nav).toHaveTextContent('Atleti')
    expect(nav).toHaveTextContent('Esercizi')
    expect(screen.getByRole('button', { name: 'Guida' })).toBeInTheDocument()
    expect(screen.getByText('Marco Bianchi')).toBeInTheDocument()
    expect(screen.getByText('marco@test.dev')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Comprimi il menu' })).toHaveAttribute('aria-expanded', 'true')
  })

  it('profilo, personalizza, piano ed esci stanno nel menu dell’account, non nella barra', async () => {
    const onSignOut = vi.fn()
    render(<Harness onSignOut={onSignOut} />)
    expect(screen.queryByRole('link', { name: 'Personalizza' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Esci' })).not.toBeInTheDocument()
    await userEvent.click(screen.getByText('Marco Bianchi'))
    expect(await screen.findByRole('menuitem', { name: 'Profilo' })).toBeInTheDocument()
    expect(screen.getByRole('menuitem', { name: 'Personalizza' })).toBeInTheDocument()
    expect(screen.getByRole('menuitem', { name: 'Piano e abbonamento' })).toBeInTheDocument()
    expect(screen.getByText('Piano Pro')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('menuitem', { name: 'Esci' }))
    expect(onSignOut).toHaveBeenCalled()
  })

  it('compresso: restano le voci con il nome accessibile e il pulsante per riaprire', async () => {
    render(<Harness />)
    await userEvent.click(screen.getByRole('button', { name: 'Comprimi il menu' }))
    expect(screen.getByRole('link', { name: 'Atleti' })).toBeInTheDocument()
    expect(screen.queryByText('marco@test.dev')).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Menu dell’account: Marco Bianchi' })).toBeInTheDocument()
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

  it('senza piano Pro sotto la guida c’è il link per passarci, con il Pro no', () => {
    const { unmount } = render(<Harness pro={false} />)
    expect(screen.getByRole('link', { name: /Passa a Pro/ })).toHaveAttribute('href', '/piani')
    unmount()
    render(<Harness pro={true} />)
    expect(screen.queryByRole('link', { name: /Passa a Pro/ })).not.toBeInTheDocument()
  })

  it('finché non si sa il piano non mostra inviti', () => {
    render(<Harness pro={undefined} />)
    expect(screen.queryByRole('link', { name: /Passa a Pro/ })).not.toBeInTheDocument()
  })

  it('la guida parte anche da compresso', async () => {
    const onStartTour = vi.fn()
    render(<Harness onStartTour={onStartTour} />)
    await userEvent.click(screen.getByRole('button', { name: 'Comprimi il menu' }))
    await userEvent.click(screen.getByRole('button', { name: 'Guida' }))
    expect(onStartTour).toHaveBeenCalled()
  })
})
