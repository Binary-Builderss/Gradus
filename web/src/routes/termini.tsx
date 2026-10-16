import { createFileRoute } from '@tanstack/react-router'
import { LegalPage } from '@/components/legal/LegalPage'
import { messages } from '@/lib/messages'
import { usePageTitle } from '@/lib/pageTitle'

export const Route = createFileRoute('/termini')({ component: TermsPage })

function TermsPage() {
  usePageTitle(messages.legal.termsTitle)
  return <LegalPage title={messages.legal.termsTitle} sections={messages.legal.terms} />
}
