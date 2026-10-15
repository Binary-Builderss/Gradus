import { CompassIcon } from '@phosphor-icons/react'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { messages } from '@/lib/messages'

const m = messages.app.tour.banner
const KEY = 'gradus.tour.dismissed'

// Il browser può negare l'accesso allo storage: in quel caso il suggerimento si ripresenta, niente di più.
const wasDismissed = () => {
  try {
    return localStorage.getItem(KEY) === '1'
  } catch {
    return false
  }
}

/** Invito a fare il giro guidato, finché non lo si chiude o lo si avvia. */
export function TourBanner({ onStart }: { onStart: () => void }) {
  const [hidden, setHidden] = useState(wasDismissed)
  if (hidden) return null

  function dismiss() {
    setHidden(true)
    try {
      localStorage.setItem(KEY, '1')
    } catch {
      /* ignora */
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-x-4 gap-y-3 rounded-lg border bg-accent/40 px-4 py-3">
      <CompassIcon size={20} className="shrink-0 text-primary" />
      <div className="min-w-0 flex-1 basis-64">
        <p className="text-sm font-semibold">{m.title}</p>
        <p className="text-muted-foreground">{m.body}</p>
      </div>
      <div className="flex gap-2">
        <Button
          onClick={() => {
            dismiss()
            onStart()
          }}
        >
          {m.start}
        </Button>
        <Button variant="ghost" onClick={dismiss}>
          {m.dismiss}
        </Button>
      </div>
    </div>
  )
}
