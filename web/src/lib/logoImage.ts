const MAX_SIDE = 512
const MAX_BASE64_CHARS = 300_000 // sotto il limite di 400.000 del database

/** Dimensioni ridotte per stare in un quadrato `max`, senza mai ingrandire. */
export function fitWithin(width: number, height: number, max: number): { width: number; height: number } {
  const scale = Math.min(1, max / Math.max(width, height))
  return { width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)) }
}

/** «data:image/png;base64,AAAA» → «AAAA». */
export const stripDataUrl = (dataUrl: string) => dataUrl.slice(dataUrl.indexOf(',') + 1)

export class LogoError extends Error {
  reason: 'unreadable' | 'too-big'
  constructor(reason: 'unreadable' | 'too-big') {
    super(reason)
    this.reason = reason
  }
}

const load = (file: File) =>
  new Promise<HTMLImageElement>((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const img = new Image()
    img.onload = () => (URL.revokeObjectURL(url), resolve(img))
    img.onerror = () => (URL.revokeObjectURL(url), reject(new LogoError('unreadable')))
    img.src = url
  })

/** Legge un'immagine scelta dal coach e la restituisce come PNG base64 ridimensionato, con la trasparenza. */
export async function fileToLogoPng(file: File): Promise<string> {
  const img = await load(file)
  for (const side of [MAX_SIDE, 256, 128]) {
    const { width, height } = fitWithin(img.naturalWidth || side, img.naturalHeight || side, side)
    const canvas = document.createElement('canvas')
    canvas.width = width
    canvas.height = height
    canvas.getContext('2d')?.drawImage(img, 0, 0, width, height)
    const base64 = stripDataUrl(canvas.toDataURL('image/png'))
    if (base64.length <= MAX_BASE64_CHARS) return base64
  }
  throw new LogoError('too-big')
}
