import { useCallback, useState } from 'react'

const KEY = 'gradus.sidebar.collapsed'

// localStorage può mancare o lanciare (finestra privata, dati bloccati): il menu funziona comunque.
const read = () => {
  try {
    return localStorage.getItem(KEY) === '1'
  } catch {
    return false
  }
}

/** Menu laterale compresso o esteso, ricordato tra una visita e l'altra. */
export function useSidebarCollapsed() {
  const [collapsed, setCollapsed] = useState(read)
  const toggle = useCallback(() => {
    setCollapsed((current) => {
      try {
        localStorage.setItem(KEY, current ? '0' : '1')
      } catch {
        // niente: resta valido per questa visita
      }
      return !current
    })
  }, [])
  return [collapsed, toggle] as const
}
