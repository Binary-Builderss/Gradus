import type { CSSProperties } from 'react'
import type { BrandColors } from '@/lib/brand'
import { messages } from '@/lib/messages'

const m = messages.app.customize.brand

/** Mini scheda dell'atleta con i colori scelti: lo stesso stile che useranno app e PDF. */
export function BrandPreview({
  colors,
  brandName,
  logoPng,
}: {
  colors: BrandColors
  brandName: string
  logoPng: string | null
}) {
  const box: CSSProperties = {
    backgroundColor: colors.background,
    color: colors.foreground,
    borderColor: colors.border,
  }
  return (
    <div className="grid gap-2">
      <div>
        <h2 className="text-sm font-semibold">{m.preview}</h2>
        <p className="text-muted-foreground">{m.previewHint}</p>
      </div>
      <div className="grid gap-4 rounded-lg border p-4" style={box}>
        <div className="flex items-center gap-3">
          {logoPng && (
            <img
              src={`data:image/png;base64,${logoPng}`}
              alt={m.logoAlt}
              className="h-9 w-auto max-w-24 object-contain"
            />
          )}
          <p className="truncate font-semibold">{brandName}</p>
        </div>
        <div>
          <p className="text-lg font-semibold">{m.previewSession}</p>
          <p style={{ color: colors.muted_foreground }}>{m.previewWeek}</p>
        </div>
        <ul className="grid gap-2">
          {m.previewRows.map((row) => (
            <li
              key={row.name}
              className="rounded-md border px-3 py-2"
              style={{ backgroundColor: colors.surface, borderColor: colors.border }}
            >
              <p className="font-medium">{row.name}</p>
              <p className="text-xs" style={{ color: colors.muted_foreground }}>
                {row.detail}
              </p>
            </li>
          ))}
        </ul>
        <div
          className="rounded-md px-3 py-2 text-center font-medium"
          style={{ backgroundColor: colors.primary, color: colors.on_primary }}
        >
          {m.previewButton}
        </div>
      </div>
    </div>
  )
}
