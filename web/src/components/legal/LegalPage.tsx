import { ArrowLeftIcon } from '@phosphor-icons/react'
import { Link } from '@tanstack/react-router'
import { Wordmark } from '@/components/brand'
import { legal, type LegalSection } from '@/lib/legal'
import { messages } from '@/lib/messages'

const m = messages.legal

const fill = (text: string) =>
  text.replaceAll('{controller}', legal.controller).replaceAll('{contact}', legal.contactEmail)

/** Pagina pubblica di sola lettura (termini, privacy, assistenza): una colonna di testo, nessun menu. */
export function LegalPage({
  title,
  sections,
  dated = true,
}: {
  title: string
  sections: readonly LegalSection[]
  /** I testi legali mostrano la versione; l'assistenza no. */
  dated?: boolean
}) {
  return (
    <main className="mx-auto min-h-dvh max-w-2xl px-4 py-10">
      <Wordmark className="h-12" />
      <Link
        to="/login"
        className="mt-8 inline-flex items-center gap-1.5 text-sm text-muted-foreground underline-offset-4 hover:text-foreground hover:underline"
      >
        <ArrowLeftIcon size={14} />
        {messages.auth.backToLogin}
      </Link>
      <h1 className="mt-4 text-2xl font-semibold tracking-tight">{title}</h1>
      {dated && <p className="mt-1 text-sm text-muted-foreground">{m.updated}</p>}
      <div className="mt-8 space-y-8">
        {sections.map((section) => (
          <section key={section.title} className="space-y-2">
            <h2 className="text-base font-semibold">{section.title}</h2>
            {section.paragraphs.map((paragraph) => (
              <p key={paragraph} className="text-sm leading-relaxed text-muted-foreground">
                {fill(paragraph)}
              </p>
            ))}
          </section>
        ))}
      </div>
    </main>
  )
}
