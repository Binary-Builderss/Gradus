import { describe, expect, it } from 'vitest'
import { videoPlatform, videoSchema } from './videos'

const parse = (url: string, title = '') => videoSchema.safeParse({ url, title })

describe('videoPlatform', () => {
  it('riconosce le piattaforme dal dominio', () => {
    expect(videoPlatform('https://www.youtube.com/watch?v=abc')).toBe('youtube')
    expect(videoPlatform('https://youtu.be/abc')).toBe('youtube')
    expect(videoPlatform('https://vimeo.com/123')).toBe('vimeo')
    expect(videoPlatform('https://www.instagram.com/reel/x/')).toBe('instagram')
    expect(videoPlatform('https://vm.tiktok.com/x')).toBe('tiktok')
    expect(videoPlatform('https://example.com/v')).toBe('other')
  })
  it('un dominio che contiene il nome ma non lo è non inganna', () => {
    expect(videoPlatform('https://youtube.com.evil.io/x')).toBe('other')
    expect(videoPlatform('https://notyoutube.com/x')).toBe('other')
  })
})

describe('videoSchema', () => {
  it('accetta https e normalizza il titolo vuoto', () => {
    expect(parse('https://youtu.be/abc')).toMatchObject({ success: true, data: { title: null } })
    expect(parse('https://youtu.be/abc', ' Esecuzione ').data?.title).toBe('Esecuzione')
  })
  it('senza schema aggiunge https://', () => {
    expect(parse('youtube.com/watch?v=abc').data?.url).toBe('https://youtube.com/watch?v=abc')
  })
  it('rifiuta http, altri schemi, testo e vuoto', () => {
    expect(parse('http://example.com/v').success).toBe(false)
    expect(parse('javascript:alert(1)').success).toBe(false)
    expect(parse('ftp://example.com/v').success).toBe(false)
    expect(parse('non è un link').success).toBe(false)
    expect(parse('   ').success).toBe(false)
  })
})
