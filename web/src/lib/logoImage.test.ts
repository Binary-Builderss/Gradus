import { describe, expect, it } from 'vitest'
import { fitWithin, stripDataUrl } from './logoImage'

describe('fitWithin', () => {
  it('riduce mantenendo le proporzioni', () =>
    expect(fitWithin(2000, 1000, 512)).toEqual({ width: 512, height: 256 }))
  it('non ingrandisce le immagini piccole', () =>
    expect(fitWithin(100, 50, 512)).toEqual({ width: 100, height: 50 }))
  it('non scende mai sotto 1 pixel', () => expect(fitWithin(5000, 1, 512).height).toBe(1))
})

describe('stripDataUrl', () => {
  it('toglie il prefisso e lascia il base64', () =>
    expect(stripDataUrl('data:image/png;base64,iVBORw0KGgo=')).toBe('iVBORw0KGgo='))
})
