import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { ExerciseVideos } from './ExerciseVideos'

const { addExerciseVideo, removeExerciseVideo } = vi.hoisted(() => ({
  addExerciseVideo: vi.fn(async () => {}),
  removeExerciseVideo: vi.fn(async () => {}),
}))
vi.mock('@/lib/library', () => ({ addExerciseVideo, removeExerciseVideo }))

const videos = [
  { id: 'v1', url: 'https://youtu.be/abc', title: 'Esecuzione' },
  { id: 'v2', url: 'https://example.com/clip', title: null },
]

function setup(list = videos) {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <ExerciseVideos coachId="c1" exerciseId="e1" videos={list} />
    </QueryClientProvider>,
  )
}
beforeEach(() => {
  addExerciseVideo.mockClear()
  removeExerciseVideo.mockClear()
})

describe('ExerciseVideos', () => {
  it('mostra i link con la piattaforma e il titolo, e si aprono in una nuova scheda', () => {
    setup()
    expect(screen.getByText('Video (2)')).toBeInTheDocument()
    const link = screen.getByRole('link', { name: 'Apri il video su YouTube: Esecuzione' })
    expect(link).toHaveAttribute('href', 'https://youtu.be/abc')
    expect(link).toHaveAttribute('target', '_blank')
    expect(link).toHaveAttribute('rel', expect.stringContaining('noopener'))
    expect(screen.getByRole('link', { name: 'Apri il video su Altro sito' })).toBeInTheDocument()
  })

  it('senza video spiega cosa fare', () => {
    setup([])
    expect(screen.getByText('Video')).toBeInTheDocument()
    expect(screen.getByText(/Nessun video/)).toBeInTheDocument()
  })

  it('aggiunge un link (anche senza https://) con titolo facoltativo', async () => {
    setup()
    await userEvent.type(screen.getByLabelText(/^Link del video/), 'vimeo.com/123')
    await userEvent.type(screen.getByLabelText('Titolo (facoltativo)'), 'Variante')
    await userEvent.click(screen.getByRole('button', { name: 'Aggiungi video' }))
    await waitFor(() => expect(addExerciseVideo).toHaveBeenCalledTimes(1))
    expect(addExerciseVideo).toHaveBeenCalledWith('c1', 'e1', {
      url: 'https://vimeo.com/123',
      title: 'Variante',
    })
  })

  it('rifiuta un link non https, vuoto o già presente', async () => {
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Aggiungi video' }))
    expect(await screen.findByText('Incolla il link del video.')).toBeInTheDocument()
    await userEvent.type(screen.getByLabelText(/^Link del video/), 'http://example.com/x')
    await userEvent.click(screen.getByRole('button', { name: 'Aggiungi video' }))
    expect(await screen.findByText('Il link deve iniziare con https://.')).toBeInTheDocument()
    await userEvent.clear(screen.getByLabelText(/^Link del video/))
    await userEvent.type(screen.getByLabelText(/^Link del video/), 'https://youtu.be/abc')
    await userEvent.click(screen.getByRole('button', { name: 'Aggiungi video' }))
    expect(await screen.findByText('Questo video c’è già.')).toBeInTheDocument()
    expect(addExerciseVideo).not.toHaveBeenCalled()
  })

  it('toglie un video', async () => {
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Togli il video: Esecuzione' }))
    await waitFor(() => expect(removeExerciseVideo).toHaveBeenCalledWith('c1', 'v1'))
  })

  it('errore del server: messaggio chiaro', async () => {
    addExerciseVideo.mockRejectedValueOnce(new Error('x'))
    setup()
    await userEvent.type(screen.getByLabelText(/^Link del video/), 'https://vimeo.com/1')
    await userEvent.click(screen.getByRole('button', { name: 'Aggiungi video' }))
    expect(await screen.findByText(/Non sono riuscito a salvare il video/)).toBeInTheDocument()
  })
})
