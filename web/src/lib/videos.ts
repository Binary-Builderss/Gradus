import { z } from 'zod'
import { messages } from './messages'

const e = messages.app.exercises.videos.errors

export type VideoPlatform = 'youtube' | 'vimeo' | 'instagram' | 'tiktok' | 'other'

const PLATFORM_HOSTS: [VideoPlatform, RegExp][] = [
  ['youtube', /^(?:[a-z0-9-]+\.)*(?:youtube\.com|youtube-nocookie\.com|youtu\.be)$/],
  ['vimeo', /^(?:[a-z0-9-]+\.)*vimeo\.com$/],
  ['instagram', /^(?:[a-z0-9-]+\.)*instagram\.com$/],
  ['tiktok', /^(?:[a-z0-9-]+\.)*tiktok\.com$/],
]

/** Dove vive un link, solo per mostrare l'etichetta giusta. */
export function videoPlatform(url: string): VideoPlatform {
  try {
    const host = new URL(url).hostname.toLowerCase()
    return PLATFORM_HOSTS.find(([, pattern]) => pattern.test(host))?.[0] ?? 'other'
  } catch {
    return 'other'
  }
}

/**
 * Il link come lo incolla il coach: senza schema («youtube.com/…») si aggiunge https://; http:// e gli altri
 * schemi (`javascript:`, `ftp:`) sono rifiutati, perché il link arriva all'atleta.
 */
const videoUrl = z
  .string()
  .trim()
  .min(1, e.required)
  .transform((v) => (/^[a-z][a-z0-9+.-]*:/i.test(v) ? v : `https://${v}`))
  .superRefine((v, ctx) => {
    if (!/^https:\/\//i.test(v)) return ctx.addIssue({ code: 'custom', message: e.notHttps })
    try {
      const { hostname } = new URL(v)
      if (!hostname.includes('.') || /\s/.test(v) || v.length > 2048) throw new Error('bad host')
    } catch {
      ctx.addIssue({ code: 'custom', message: e.invalid })
    }
  })

export const videoSchema = z.object({
  url: videoUrl,
  title: z
    .string()
    .trim()
    .max(120, e.invalid)
    .transform((v) => (v === '' ? null : v)),
})
export type VideoInput = z.infer<typeof videoSchema>
