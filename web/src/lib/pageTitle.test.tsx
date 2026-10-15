import { render } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { usePageTitle } from './pageTitle'

function Page({ title }: { title: string | undefined }) {
  usePageTitle(title)
  return null
}

describe('usePageTitle', () => {
  it('scrive «Titolo · Gradus» e al cambio pagina rimette il titolo di prima', () => {
    document.title = 'Gradus | Programmazione per l’ipertrofia'
    const { rerender, unmount } = render(<Page title="Esercizi" />)
    expect(document.title).toBe('Esercizi · Gradus')
    rerender(<Page title="Mario Rossi" />)
    expect(document.title).toBe('Mario Rossi · Gradus')
    unmount()
    expect(document.title).toBe('Gradus | Programmazione per l’ipertrofia')
  })
  it('senza titolo (dati in arrivo) non tocca nulla', () => {
    document.title = 'Prima'
    const { unmount } = render(<Page title={undefined} />)
    expect(document.title).toBe('Prima')
    unmount()
  })
})
