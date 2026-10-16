import { createFileRoute } from '@tanstack/react-router'
import { LegalPage } from '@/components/legal/LegalPage'
import { messages } from '@/lib/messages'
import { usePageTitle } from '@/lib/pageTitle'

export const Route = createFileRoute('/privacy')({ component: PrivacyPage })

function PrivacyPage() {
  usePageTitle(messages.legal.privacyTitle)
  return <LegalPage title={messages.legal.privacyTitle} sections={messages.legal.privacy} />
}
