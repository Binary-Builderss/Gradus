import { queryOptions } from '@tanstack/react-query'
import type { BrandOverrides } from './brand'
import { supabase } from './supabase'

export type Branding = {
  brandName: string | null
  logoPng: string | null
  colors: BrandOverrides
  /** Piano Custom: il PDF non porta «Creato con Gradus». */
  hideGradusCredit: boolean
}

export const brandingQuery = (coachId: string) =>
  queryOptions({
    queryKey: ['branding', coachId],
    queryFn: async (): Promise<Branding | null> => {
      const { data, error } = await supabase
        .from('coach_branding')
        .select('brand_name, logo_png, colors, hide_gradus_credit')
        .eq('coach_id', coachId)
        .maybeSingle()
      if (error) throw error
      return data
        ? {
            brandName: data.brand_name,
            logoPng: data.logo_png,
            colors: data.colors as BrandOverrides,
            hideGradusCredit: data.hide_gradus_credit,
          }
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
      hide_gradus_credit: branding.hideGradusCredit,
    },
    { onConflict: 'coach_id' },
  )
  if (error) throw error
}
