import { useEffect } from 'react'
import { messages } from './messages'

/** Titolo della scheda del browser: «Esercizi · Gradus». Senza titolo (dati in arrivo) resta quello di prima. */
export function usePageTitle(title: string | undefined) {
  useEffect(() => {
    if (!title) return
    const previous = document.title
    document.title = `${title} · ${messages.brand.name}`
    return () => {
      document.title = previous
    }
  }, [title])
}
