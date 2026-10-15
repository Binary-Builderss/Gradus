import { describe, expect, it } from 'vitest'
import { buildTourPlan } from './lib/tourPlan'

// Tutto il codice dell'interfaccia (esclusi test e file generati), per cercare gli attributi data-tour.
const sources = import.meta.glob(['/src/**/*.{ts,tsx}', '!/src/**/*.test.*', '!/src/routeTree.gen.ts'], {
  query: '?raw',
  import: 'default',
  eager: true,
}) as Record<string, string>

/** Elementi che la guida può evidenziare: `data-tour="x"`, `data-tour={cond ? 'x' : undefined}` o la prop `tour="x"`. */
function tourAttributes(): Set<string> {
  const found = new Set<string>()
  for (const [file, text] of Object.entries(sources)) {
    if (file.endsWith('/lib/tourPlan.ts')) continue
    for (const m of text.matchAll(/data-tour=(?:"([^"]+)"|\{([^}]*)\})/g)) {
      if (m[1] && /^[a-z][a-z-]+$/.test(m[1])) found.add(m[1])
      for (const token of (m[2] ?? '').matchAll(/['"]([a-z][a-z-]+)['"]/g)) found.add(token[1]!)
    }
    for (const m of text.matchAll(/(?<![\w-])tour="([^"$]+)"/g)) found.add(m[1]!)
  }
  return found
}

// Elementi con un attributo ma senza un passo proprio: sono spiegati da un altro passo.
const explainedElsewhere = new Set([
  'upgrade', // il blocco «Passa a Pro» sotto la Guida: lo spiega il passo del piano
])

const allSteps = buildTourPlan({
  athleteId: 'a',
  mesocycleId: 'm',
  hasActiveMesocycle: true,
  canFollowSelf: true,
  hasSubscription: true,
  sidebar: true,
})
const stepTargets = new Set(allSteps.flatMap((s) => (s.target ? [s.target] : [])))

describe('la guida copre tutto il sito', () => {
  it('ogni passo evidenzia un elemento che esiste davvero', () => {
    const attributes = tourAttributes()
    for (const target of stepTargets) expect(attributes, `manca data-tour="${target}"`).toContain(target)
  })

  it('ogni elemento della guida ha un passo (nuove funzioni = nuovo passo in tourPlan.ts)', () => {
    for (const attribute of tourAttributes())
      if (!explainedElsewhere.has(attribute))
        expect(stepTargets, `nessun passo per data-tour="${attribute}"`).toContain(attribute)
  })

  it('ogni pagina dell’area riservata è nel percorso', () => {
    const pages = Object.keys(sources)
      .filter((f) => f.startsWith('/src/routes/_app/'))
      .map((f) => f.replace('/src/routes/_app/', '').replace('.tsx', ''))
    const visited = new Set(allSteps.map((s) => s.route.to.split('/')[1] || 'index'))
    // atleti.$athleteId → atleti, mesocicli.$mesocycleId → mesocicli
    for (const page of pages) expect(visited, `la guida non passa da ${page}`).toContain(page.split('.')[0])
  })
})
