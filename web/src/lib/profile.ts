import { queryOptions } from '@tanstack/react-query'
import { supabase } from './supabase'

export type Profile = { fullName: string | null; email: string | null; disabledAt: string | null }

export const profileQuery = (userId: string) =>
  queryOptions({
    queryKey: ['profile', userId],
    queryFn: async (): Promise<Profile> => {
      const { data, error } = await supabase
        .from('profiles')
        .select('full_name, email, disabled_at')
        .eq('id', userId)
        .maybeSingle()
      if (error) throw error
      return {
        fullName: data?.full_name ?? null,
        email: data?.email ?? null,
        disabledAt: data?.disabled_at ?? null,
      }
    },
  })

/** Nome con cui compare una persona: il nome scelto, altrimenti l'email. */
export const displayName = (profile: Profile | undefined, fallback = '') =>
  profile?.fullName?.trim() || profile?.email || fallback

export async function saveProfileName(userId: string, fullName: string) {
  const { error } = await supabase
    .from('profiles')
    .update({ full_name: fullName.trim() || null })
    .eq('id', userId)
  if (error) throw error
}
