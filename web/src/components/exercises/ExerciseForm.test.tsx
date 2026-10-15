import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { ExerciseForm } from './ExerciseForm'

const { createExercise, updateExercise } = vi.hoisted(() => ({
  createExercise: vi.fn(async () => {}),
  updateExercise: vi.fn(async () => {}),
}))
vi.mock('@/lib/library', () => ({ createExercise, updateExercise }))

const onDone = vi.fn()
function setup(props: Partial<React.ComponentProps<typeof ExerciseForm>> = {}) {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <ExerciseForm coachId="coach-1" onDone={onDone} {...props} />
    </QueryClientProvider>,
  )
}

beforeEach(() => {
  createExercise.mockClear()
  updateExercise.mockClear()
  onDone.mockClear()
})

describe('ExerciseForm', () => {
  it('crea un esercizio con nome e muscoli', async () => {
    setup()
    await userEvent.type(screen.getByLabelText('Nome'), 'Curl al cavo')
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    await waitFor(() => expect(createExercise).toHaveBeenCalledTimes(1))
    expect(createExercise).toHaveBeenCalledWith('coach-1', {
      name: 'Curl al cavo',
      notes: null,
      muscles: [{ muscle: 'chest', weight: 1 }],
    })
    await waitFor(() => expect(onDone).toHaveBeenCalled())
  })

  it("senza nome mostra l'errore e non salva", async () => {
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    expect(await screen.findByText('Inserisci il nome.')).toBeInTheDocument()
    expect(createExercise).not.toHaveBeenCalled()
  })

  it('senza muscoli non salva', async () => {
    setup()
    await userEvent.type(screen.getByLabelText('Nome'), 'X')
    await userEvent.click(screen.getByRole('button', { name: 'Rimuovi muscolo' }))
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    expect(await screen.findByText('Aggiungi almeno un muscolo.')).toBeInTheDocument()
    expect(createExercise).not.toHaveBeenCalled()
  })

  it('un muscolo scelto non si può duplicare nelle altre righe', async () => {
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Aggiungi muscolo' }))
    const selects = screen.getAllByRole('combobox')
    const second = Array.from((selects[1] as HTMLSelectElement).options).map((o) => o.value)
    expect(second).not.toContain('chest')
    expect(selects).toHaveLength(2)
  })

  it('copia dal catalogo: precompila, aggiunge "(copia)" nel nome e crea un nuovo esercizio', async () => {
    setup({
      seed: {
        name: 'Panca piana (copia)',
        notes: null,
        muscles: [
          { muscle: 'chest', weight: 1 },
          { muscle: 'triceps', weight: 0.5 },
        ],
      },
    })
    expect(screen.getByLabelText('Nome')).toHaveValue('Panca piana (copia)')
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    await waitFor(() => expect(createExercise).toHaveBeenCalled())
    expect(updateExercise).not.toHaveBeenCalled()
  })

  it("modifica: aggiorna l'esercizio esistente", async () => {
    const exercise = {
      id: 'e1',
      owner_id: 'coach-1',
      name: 'Mio curl',
      notes: null,
      videos: [],
      muscles: [{ muscle: 'biceps' as const, weight: 1 }],
    }
    setup({ exercise })
    await userEvent.clear(screen.getByLabelText('Nome'))
    await userEvent.type(screen.getByLabelText('Nome'), 'Mio curl 2')
    await userEvent.click(screen.getByRole('button', { name: 'Salva' }))
    await waitFor(() => expect(updateExercise).toHaveBeenCalledTimes(1))
    expect(updateExercise).toHaveBeenCalledWith(
      'coach-1',
      exercise,
      expect.objectContaining({ name: 'Mio curl 2' }),
    )
  })
})
