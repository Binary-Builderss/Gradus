import type { BrandColors } from './brand'
import { messages } from './messages'
import type { PdfModel } from './pdfModel'

const m = messages.app.pdf

export type PdfStyle = {
  colors: BrandColors
  logoPng: string | null
  /** Logo grande e sbiadito dietro la tabella (dal piano Basic). */
  watermark: boolean
  /** Il PDF porta il marchio del coach (non lo stile Gradus). */
  branded: boolean
  /** Piè di pagina con «Creato con Gradus»: da solo se non c'è il marchio, dopo il nome se c'è. Il piano Custom lo toglie. */
  madeWithGradus: boolean
}

/** Il piè di pagina: senza marchio «Creato con Gradus»; col marchio il suo nome, e la dicitura Gradus dopo se non è tolta. */
export function footerText(brandName: string, style: Pick<PdfStyle, 'branded' | 'madeWithGradus'>): string {
  if (!style.branded) return m.madeWith
  return style.madeWithGradus ? `${brandName} · ${m.madeWith}` : brandName
}

const MARGIN = 36
const TOP = 74 // sotto l'intestazione
const BOTTOM = 44 // sopra il piè di pagina
const NAME_WIDTH = 172
const TOTAL_PAGES = '{total}'
// Lo scarico resta ambra qualunque sia il marchio: è un significato, non un colore di stile.
const DELOAD_HEAD = '#F6E7BE'
const DELOAD_BODY = '#FBF3DC'
const DELOAD_TEXT = '#8A5A00'

type Rgb = [number, number, number]
const rgb = (hex: string): Rgb => {
  const n = Number.parseInt(hex.slice(1), 16)
  return [n >> 16, (n >> 8) & 255, n & 255]
}

/** Disegna il programma: una pagina A4 orizzontale per seduta (più pagine se serve). */
export async function renderProgramPdf(model: PdfModel, style: PdfStyle): Promise<Blob> {
  const [{ jsPDF, GState }, { default: autoTable }] = await Promise.all([
    import('jspdf'),
    import('jspdf-autotable'),
  ])
  const doc = new jsPDF({ orientation: 'landscape', unit: 'pt', format: 'a4' })
  doc.setProperties({ title: `${model.mesocycleName} - ${model.athleteName}`, author: model.brandName })
  const width = doc.internal.pageSize.getWidth()
  const height = doc.internal.pageSize.getHeight()
  const c = style.colors
  const logoUrl = style.logoPng ? `data:image/png;base64,${style.logoPng}` : null
  const logo = logoUrl ? doc.getImageProperties(logoUrl) : null
  const decorated = new Set<number>()

  const text = (
    value: string,
    x: number,
    y: number,
    size: number,
    color: string,
    bold = false,
    align?: 'right' | 'center',
  ) => {
    doc.setFont('helvetica', bold ? 'bold' : 'normal')
    doc.setFontSize(size)
    doc.setTextColor(...rgb(color))
    doc.text(value, x, y, align ? { align } : undefined)
  }

  /** Fondo, intestazione e piè di pagina: una sola volta per pagina. */
  function decorate() {
    const page = doc.getCurrentPageInfo().pageNumber
    if (decorated.has(page)) return
    decorated.add(page)
    doc.setFillColor(...rgb(c.background))
    doc.rect(0, 0, width, height, 'F')

    let x = MARGIN
    if (logoUrl && logo) {
      const scale = Math.min(26 / logo.height, 90 / logo.width)
      const w = logo.width * scale
      const h = logo.height * scale
      doc.addImage(logoUrl, 'PNG', x, 26 + (26 - h) / 2, w, h)
      x += w + 10
    }
    text(model.brandName, x, 45, 14, c.foreground, true)
    text(model.athleteName, width - MARGIN, 40, 10, c.foreground, true, 'right')
    text(model.mesocycleName, width - MARGIN, 52, 8.5, c.muted_foreground, false, 'right')
    doc.setDrawColor(...rgb(c.border))
    doc.setLineWidth(0.6)
    doc.line(MARGIN, 60, width - MARGIN, 60)

    doc.line(MARGIN, height - 32, width - MARGIN, height - 32)
    text(footerText(model.brandName, style), MARGIN, height - 18, 8, c.muted_foreground)
    text(
      m.page(String(page), TOTAL_PAGES),
      width - MARGIN,
      height - 18,
      8,
      c.muted_foreground,
      false,
      'right',
    )
  }

  model.sessions.forEach((session, index) => {
    if (index > 0) doc.addPage()
    decorate()
    let y = TOP + 6
    if (index === 0) {
      model.meta.forEach((item, i) => {
        const x = MARGIN + i * 150
        text(item.label, x, y, 7.5, c.muted_foreground)
        text(item.value, x, y + 11, 10, c.foreground, true)
      })
      y += 34
    }
    text(session.name, MARGIN, y + 10, 16, c.foreground, true)
    y += 22
    if (session.rows.length === 0) {
      text(m.emptySession, MARGIN, y + 12, 10, c.muted_foreground)
      return
    }

    const weekNumbers = Array.from({ length: model.weeks }, (_, i) => i + 1)
    const nameLines = session.rows.map((r) => {
      doc.setFont('helvetica', 'bold')
      doc.setFontSize(9)
      return r.name ? (doc.splitTextToSize(r.name, NAME_WIDTH - 26) as string[]) : []
    })
    const weekWidth = (width - MARGIN * 2 - NAME_WIDTH) / model.weeks

    autoTable(doc, {
      startY: y,
      margin: { top: TOP, bottom: BOTTOM, left: MARGIN, right: MARGIN },
      theme: 'grid',
      head: [
        [
          m.exercise,
          ...weekNumbers.map((w) =>
            model.deloadWeeks.includes(w) ? `${m.weekHead(w)}\n${m.deload}` : m.weekHead(w),
          ),
        ],
      ],
      body: session.rows.map(() => ['', ...weekNumbers.map(() => '')]),
      styles: {
        fontSize: 8,
        cellPadding: 4,
        lineColor: rgb(c.border),
        lineWidth: 0.5,
        fillColor: rgb(c.surface),
        textColor: rgb(c.foreground),
        minCellHeight: 30,
      },
      headStyles: {
        fillColor: rgb(c.border),
        textColor: rgb(c.foreground),
        fontStyle: 'bold',
        halign: 'center',
        fontSize: 8,
      },
      columnStyles: {
        0: { cellWidth: NAME_WIDTH, halign: 'left' },
        ...Object.fromEntries(weekNumbers.map((w) => [w, { cellWidth: weekWidth }])),
      },
      willDrawPage: decorate,
      didParseCell(data) {
        const week = data.column.index
        const deload = week > 0 && model.deloadWeeks.includes(week)
        if (data.section === 'head' && week === 0) data.cell.styles.halign = 'left'
        if (data.section === 'head' && deload) {
          data.cell.styles.fillColor = rgb(DELOAD_HEAD)
          data.cell.styles.textColor = rgb(DELOAD_TEXT)
        }
        if (data.section !== 'body') return
        const row = session.rows[data.row.index]!
        if (deload) data.cell.styles.fillColor = rgb(DELOAD_BODY)
        // Si disegna a mano per avere due stili nella stessa cella: qui si riserva solo l'altezza.
        const lines = week === 0 ? Math.max(1, nameLines[data.row.index]!.length) + row.notes.length : 2
        data.cell.text = Array.from({ length: lines }, () => '')
      },
      didDrawCell(data) {
        if (data.section !== 'body') return
        const row = session.rows[data.row.index]!
        const { x, y: top, width: w, height: h } = data.cell
        if (data.column.index === 0) {
          let baseline = top + 12
          if (row.number) text(row.number, x + 5, baseline, 9, c.primary, true)
          for (const line of nameLines[data.row.index]!) {
            text(line, x + 24, baseline, 9, c.foreground, true)
            baseline += 10
          }
          for (const note of row.notes) {
            text(note, x + 24, baseline, 7.5, c.muted_foreground)
            baseline += 9
          }
          return
        }
        const cell = row.cells[data.column.index - 1]!
        if (!cell.main) return
        const mid = top + h / 2
        text(cell.main, x + w / 2, cell.sub ? mid - 1 : mid + 3, 9, c.foreground, true, 'center')
        if (cell.sub) text(cell.sub, x + w / 2, mid + 9, 7.5, c.muted_foreground, false, 'center')
      },
    })
  })

  // Filigrana in ultimo, sopra la tabella ma molto chiara: dietro, le celle piene la coprirebbero.
  if (style.watermark && logoUrl && logo) {
    const scale = Math.min(340 / logo.width, 340 / logo.height)
    const w = logo.width * scale
    const h = logo.height * scale
    for (let page = 1; page <= doc.getNumberOfPages(); page++) {
      doc.setPage(page)
      doc.saveGraphicsState()
      doc.setGState(new GState({ opacity: 0.07 }))
      doc.addImage(logoUrl, 'PNG', (width - w) / 2, (height - h) / 2, w, h)
      doc.restoreGraphicsState()
    }
  }

  doc.putTotalPages(TOTAL_PAGES)
  return doc.output('blob')
}

/** Fa scaricare il file dal browser. */
export function downloadBlob(blob: Blob, fileName: string) {
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = fileName
  link.click()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}
