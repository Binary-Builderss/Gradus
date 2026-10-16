import { FilePdfIcon } from '@phosphor-icons/react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Button } from '@/components/ui/button'
import { resolveColors, STANDARD_COLORS } from '@/lib/brand'
import { brandingQuery } from '@/lib/branding'
import { canCustomize, planUsageQuery } from '@/lib/plans'
import type { BlockData, WeekData } from '@/lib/gridModel'
import { athleteQuery } from '@/lib/mesocycles'
import { messages } from '@/lib/messages'
import { buildPdfModel, pdfFileName } from '@/lib/pdfModel'
import { displayName, profileQuery } from '@/lib/profile'
import type { GroupRow, SlotRow } from '@/lib/slots'

const m = messages.app.pdf
const dateFormat = new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'long', year: 'numeric' })

type Program = {
  mesocycle: { name: string; start_date: string; weeks: number; deload_weeks: number[]; athlete_id: string }
  sessions: readonly { id: string; name: string }[]
  groups: readonly GroupRow[]
  slots: readonly SlotRow[]
  blocks: readonly BlockData[]
  weeks: readonly WeekData[]
}

/** Scarica la programmazione in PDF: stile Gradus, o marchio del coach dal piano Basic in su. */
export function DownloadPdfButton({ coachId, program }: { coachId: string; program: Program }) {
  const queryClient = useQueryClient()
  const generate = useMutation({
    mutationFn: async () => {
      const { mesocycle } = program
      // Dati freschi al momento del clic: il piano e il marchio possono essere cambiati da poco.
      const [usage, branding, coachProfile, athlete] = await Promise.all([
        queryClient.fetchQuery({ ...planUsageQuery(coachId), staleTime: 0 }),
        queryClient.fetchQuery({ ...brandingQuery(coachId), staleTime: 0 }),
        queryClient.fetchQuery(profileQuery(coachId)),
        queryClient.fetchQuery(athleteQuery(coachId, mesocycle.athlete_id)),
      ])
      const athleteName = athlete?.athlete?.full_name?.trim() || athlete?.athlete?.email || ''
      const branded = canCustomize(usage) && branding !== null
      const model = buildPdfModel({
        brandName: branded ? branding.brandName?.trim() || displayName(coachProfile) : 'Gradus',
        athleteName,
        ...program,
        formatDate: (iso) => dateFormat.format(new Date(iso)),
      })
      // Caricato solo al clic: le librerie del PDF pesano e servono di rado.
      const { renderProgramPdf, downloadBlob } = await import('@/lib/programPdf')
      const blob = await renderProgramPdf(model, {
        colors: branded ? resolveColors(branding.colors) : STANDARD_COLORS,
        logoPng: branded ? branding.logoPng : null,
        watermark: branded && branding.logoPng !== null,
        branded,
        madeWithGradus: !branded || branding?.hideGradusCredit !== true,
      })
      downloadBlob(blob, pdfFileName(mesocycle.name, athleteName))
    },
  })

  return (
    <div className="flex items-center gap-2" data-tour="pdf-button">
      {generate.isError && (
        <span role="alert" className="text-sm text-destructive">
          {m.error}
        </span>
      )}
      <Button
        variant="outline"
        title={m.hint}
        disabled={generate.isPending || program.sessions.length === 0}
        onClick={() => generate.mutate()}
      >
        <FilePdfIcon data-icon="inline-start" />
        {generate.isPending ? m.working : m.button}
      </Button>
    </div>
  )
}
