import { describe, expect, it } from 'vitest'
import { STANDARD_COLORS } from './brand'
import type { PdfModel } from './pdfModel'
import { renderProgramPdf } from './programPdf'

// PNG 1x1 trasparente
const LOGO =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='

const row = (name: string) => ({
  number: '1',
  name,
  notes: ['Top set'],
  cells: [
    { main: '4 × 6-8', sub: '2 in riserva' },
    { main: '', sub: '' },
  ],
})
const model: PdfModel = {
  brandName: 'Gradus',
  athleteName: 'Giulia Rossi',
  mesocycleName: 'Blocco 1',
  meta: [{ label: 'Atleta', value: 'Giulia Rossi' }],
  weeks: 2,
  deloadWeeks: [2],
  sessions: [
    { name: 'Spinta', rows: [row('Panca piana')] },
    { name: 'Gambe', rows: [] },
  ],
}
const style = { colors: STANDARD_COLORS, logoPng: null, watermark: false, madeWithGradus: true }

const text = (blob: Blob) =>
  new Promise<string>((resolve) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result))
    reader.readAsText(blob, 'latin1')
  })

describe('renderProgramPdf', () => {
  it('produce un PDF vero, una pagina per seduta', async () => {
    const blob = await renderProgramPdf(model, style)
    const content = await text(blob)
    expect(content.startsWith('%PDF-')).toBe(true)
    expect(content.match(/\/Type \/Page\b/g)).toHaveLength(2)
  })

  it('con marchio e filigrana mette il logo nel file', async () => {
    const plain = await renderProgramPdf(model, style)
    const branded = await renderProgramPdf(model, {
      ...style,
      logoPng: LOGO,
      watermark: true,
      madeWithGradus: false,
    })
    expect(await text(branded)).toContain('/Subtype /Image')
    expect(await text(plain)).not.toContain('/Subtype /Image')
  })
})
