import { queryOptions } from '@tanstack/react-query'
import type { BrandOverrides } from './brand'
import { supabase } from './supabase'

export type Branding = { brandName: string | null; logoPng: string | null; colors: BrandOverrides }

export const brandingQuery = (coachId: string) =>
  queryOptions({
    queryKey: ['branding', coachId],
    queryFn: async (): Promise<Branding | null> => {
      const { data, error } = await supabase
        .from('coach_branding')
        .select('brand_name, logo_png, colors')
        .eq('coach_id', coachId)
        .maybeSingle()
      if (error) throw error
      return data
        ? { brandName: data.brand_name, logoPng: data.logo_png, colors: data.colors as BrandOverrides }
        : null
    },
  })

/** Piano pro attivo oggi: la regola sta nel database (`has_pro_plan`), il web non la ricalcola. */
export const proPlanQuery = (coachId: string) =>
  queryOptions({
    queryKey: ['pro-plan', coachId],
    queryFn: async (): Promise<boolean> => {
      const { data, error } = await supabase.rpc('has_pro_plan')
      if (error) throw error
      return data
    },
  })

export async function saveBranding(coachId: string, branding: Branding) {
  const { error } = await supabase.from('coach_branding').upsert(
    {
      coach_id: coachId,
      brand_name: branding.brandName?.trim() || null,
      logo_png: branding.logoPng,
      colors: branding.colors,
    },
    { onConflict: 'coach_id' },
  )
  if (error) throw error
}

/** Nome con cui il coach firma il PDF se non ha scelto un nome del marchio. */
export const coachNameQuery = (coachId: string) =>
  queryOptions({
    queryKey: ['coach-name', coachId],
    queryFn: async (): Promise<string> => {
      const { data, error } = await supabase
        .from('profiles')
        .select('full_name, email')
        .eq('id', coachId)
        .maybeSingle()
      if (error) throw error
      return data?.full_name?.trim() || data?.email || ''
    },
  })
