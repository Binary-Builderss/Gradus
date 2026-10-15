import { describe, expect, it } from 'vitest'
import html from '../index.html?raw'

const publicFiles = Object.keys(import.meta.glob('../public/*', { query: '?url' }))
const meta = (attr: 'name' | 'property', key: string) =>
  new RegExp(`<meta[^>]*${attr}="${key}"[^>]*?content="([^"]*)"`, 's').exec(html)?.[1]

describe('anteprima del link e SEO (index.html)', () => {
  it('ha titolo e descrizione di lunghezza giusta per i motori di ricerca', () => {
    expect(/<title>[^<]{10,60}<\/title>/.test(html)).toBe(true)
    expect(meta('name', 'description')?.length).toBeGreaterThan(70)
    expect(meta('name', 'description')?.length).toBeLessThanOrEqual(160)
  })

  it('Open Graph completo, con indirizzi assoluti e immagine che esiste davvero', () => {
    for (const key of ['og:title', 'og:description', 'og:url', 'og:image', 'og:image:alt'])
      expect(meta('property', key), key).toBeTruthy()
    const image = meta('property', 'og:image')!
    expect(image.startsWith('https://')).toBe(true)
    expect(publicFiles).toContain(`../public${new URL(image).pathname}`)
    expect(meta('property', 'og:url')?.startsWith('https://')).toBe(true)
  })

  it('stesso dominio nel canonical, in og:url e nelle immagini', () => {
    const canonical = /<link rel="canonical" href="([^"]+)"/.exec(html)?.[1]
    expect(canonical).toBe(meta('property', 'og:url'))
    expect(meta('property', 'og:image')?.startsWith(canonical!)).toBe(true)
    expect(meta('name', 'twitter:image')).toBe(meta('property', 'og:image'))
  })

  it('anteprima grande su Twitter / X', () =>
    expect(meta('name', 'twitter:card')).toBe('summary_large_image'))
})
