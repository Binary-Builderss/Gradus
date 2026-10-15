import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { TourBanner } from './TourBanner'

describe('TourBanner', () => {
  beforeEach(() => localStorage.clear())

  it('starts the tour and stays hidden afterwards', async () => {
    const onStart = vi.fn()
    const { unmount } = render(<TourBanner onStart={onStart} />)
    await userEvent.click(screen.getByRole('button', { name: 'Avvia la guida' }))
    expect(onStart).toHaveBeenCalledOnce()
    expect(screen.queryByText('Prima volta su Gradus?')).not.toBeInTheDocument()

    unmount()
    render(<TourBanner onStart={onStart} />)
    expect(screen.queryByText('Prima volta su Gradus?')).not.toBeInTheDocument()
  })

  it('remembers that it was dismissed', async () => {
    render(<TourBanner onStart={vi.fn()} />)
    await userEvent.click(screen.getByRole('button', { name: 'Non ora' }))
    expect(localStorage.getItem('gradus.tour.dismissed')).toBe('1')
  })
})
