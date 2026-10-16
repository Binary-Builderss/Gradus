import { describe, expect, it } from 'vitest'
import { legal } from './legal'

describe('pagine legali', () => {
  // Finché fallisce, le pagine /termini e /privacy mostrano un segnaposto al posto del contatto reale.
  it.fails('il contatto non è più un segnaposto', () => {
    expect(legal.contactEmail).toMatch(/^[^\s@[]+@[^\s@]+\.[^\s@]+$/)
  })
})
