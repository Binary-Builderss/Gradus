import { createFileRoute } from '@tanstack/react-router'
import { LegalPage } from '@/components/legal/LegalPage'
import { messages } from '@/lib/messages'
import { usePageTitle } from '@/lib/pageTitle'

export const Route = createFileRoute('/assistenza')({ component: SupportPage })

/** Pagina pubblica di assistenza: è l'URL di supporto della scheda di Gradus Atleta su App Store. */
function SupportPage() {
  usePageTitle(messages.legal.supportTitle)
  return <LegalPage title={messages.legal.supportTitle} sections={messages.legal.support} dated={false} />
}
