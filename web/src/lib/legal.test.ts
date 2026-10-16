import { describe, expect, it } from 'vitest'
import { legal } from './legal'

describe('pagine legali', () => {
  it('il contatto è un indirizzo email vero, non un segnaposto', () => {
    expect(legal.contactEmail).toMatch(/^[^\s@[]+@[^\s@]+\.[^\s@]+$/)
  })
})
