// Colori del marchio del coach: helper puri, nessuna dipendenza da Supabase.
export const BRAND_KEYS = [
  'primary',
  'on_primary',
  'background',
  'foreground',
  'surface',
  'muted_foreground',
  'border',
] as const
export type BrandKey = (typeof BRAND_KEYS)[number]
export type BrandColors = Record<BrandKey, string>
export type BrandOverrides = Partial<BrandColors>

/** Colori standard di Gradus (tema chiaro, equivalenti hex dei token in index.css). */
export const STANDARD_COLORS: BrandColors = {
  primary: '#1961D4',
  on_primary: '#F9FAFB',
  background: '#FBFCFD',
  foreground: '#16181D',
  surface: '#FEFEFF',
  muted_foreground: '#60636A',
  border: '#E1E3E6',
}

/** «#abc», «abc», «#AABBCC» → «#AABBCC»; altro → null. */
export function normalizeHex(text: string): string | null {
  const t = text.trim().replace(/^#/, '')
  const full = /^[0-9a-f]{3}$/i.test(t) ? [...t].map((c) => c + c).join('') : t
  return /^[0-9a-f]{6}$/i.test(full) ? `#${full.toUpperCase()}` : null
}

/** Colori in uso: quelli scelti dal coach sopra lo standard. Valori non validi tornano standard. */
export function resolveColors(overrides: BrandOverrides | null | undefined): BrandColors {
  const out = { ...STANDARD_COLORS }
  for (const key of BRAND_KEYS) {
    const hex = normalizeHex(overrides?.[key] ?? '')
    if (hex) out[key] = hex
  }
  return out
}

/** Solo i colori diversi dallo standard: sono gli unici che si salvano. */
export function overridesFrom(colors: BrandColors): BrandOverrides {
  const out: BrandOverrides = {}
  for (const key of BRAND_KEYS) if (colors[key].toUpperCase() !== STANDARD_COLORS[key]) out[key] = colors[key]
  return out
}

const channel = (v: number) => {
  const s = v / 255
  return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4
}
const luminance = (hex: string) => {
  const n = Number.parseInt(hex.slice(1), 16)
  return 0.2126 * channel(n >> 16) + 0.7152 * channel((n >> 8) & 255) + 0.0722 * channel(n & 255)
}

/** Rapporto di contrasto WCAG tra due colori (da 1 a 21). */
export function contrastRatio(a: string, b: string): number {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x)
  return (hi! + 0.05) / (lo! + 0.05)
}

/** Coppie di colori che si leggono male: non blocca il salvataggio, avvisa soltanto. */
export function contrastProblems(colors: BrandColors): ('text' | 'button')[] {
  const problems: ('text' | 'button')[] = []
  if (contrastRatio(colors.foreground, colors.background) < 4.5) problems.push('text')
  if (contrastRatio(colors.on_primary, colors.primary) < 4.5) problems.push('button')
  return problems
}
