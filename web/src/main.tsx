import { QueryClientProvider } from '@tanstack/react-query'
import { createRouter, RouterProvider } from '@tanstack/react-router'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import { queryClient } from './lib/queryClient'
import { supabase } from './lib/supabase'
import { NotFound } from './components/auth/NotFound'
import { routeTree } from './routeTree.gen'

const router = createRouter({ routeTree, context: {}, defaultNotFoundComponent: NotFound })

// Pagine aperte a tutti: una sessione scaduta (SIGNED_OUT all'avvio) non deve portare via da qui.
const publicPaths = new Set([
  '/login',
  '/registrati',
  '/recupero-password',
  '/nuova-password',
  '/termini',
  '/privacy',
  '/assistenza',
])

// setTimeout: dentro il callback non si chiamano metodi di supabase.auth (rischio di stallo).
supabase.auth.onAuthStateChange((event) => {
  if (event === 'SIGNED_OUT') {
    queryClient.clear()
    if (!publicPaths.has(window.location.pathname)) setTimeout(() => void router.navigate({ to: '/login' }))
  }
  if (event === 'PASSWORD_RECOVERY') setTimeout(() => void router.navigate({ to: '/nuova-password' }))
})

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router
  }
}

const rootElement = document.getElementById('root')
if (!rootElement) throw new Error('Elemento #root mancante in index.html')

createRoot(rootElement).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  </StrictMode>,
)
