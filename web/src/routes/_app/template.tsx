import { createFileRoute } from '@tanstack/react-router'
import { TemplateList } from '@/components/templates/TemplateList'
import { usePageTitle } from '@/lib/pageTitle'
import { messages } from '@/lib/messages'

export const Route = createFileRoute('/_app/template')({
  component: TemplatesPage,
})

function TemplatesPage() {
  usePageTitle(messages.app.templates.title)
  const { user } = Route.useRouteContext()
  return <TemplateList coachId={user.id} />
}
