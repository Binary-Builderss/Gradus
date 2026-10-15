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
