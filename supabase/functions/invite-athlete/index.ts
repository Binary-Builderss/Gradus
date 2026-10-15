// Invito di un atleta da parte del coach. Gira con la service_role (iniettata da Supabase): il browser non la vede mai.
// Body: { email, name? }. Il nome entra nel profilo solo se l'atleta è nuovo; poi lo cambia lui. Risposta: { result: 'invited' | 'linked' | 'reopened' | 'already' }.
import { createClient } from 'npm:@supabase/supabase-js@2'
import { z } from 'npm:zod@4'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const body = z.object({
  email: z.email().transform((e) => e.trim().toLowerCase()),
  name: z
    .string()
    .trim()
    .max(80)
    .optional()
    .transform((n) => n || undefined),
})

const reply = (status: number, payload: Record<string, unknown>) =>
  new Response(JSON.stringify(payload), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return reply(405, { error: 'method_not_allowed' })

  const url = Deno.env.get('SUPABASE_URL')!
  const authHeader = req.headers.get('Authorization') ?? ''

  // Chi chiama: l'utente del JWT diventa il coach. Mai un coach_id preso dal body.
  const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: userData, error: userError } = await caller.auth.getUser()
  if (userError || !userData.user) return reply(401, { error: 'unauthorized' })
  const coachId = userData.user.id

  const parsed = body.safeParse(await req.json().catch(() => null))
  if (!parsed.success) return reply(400, { error: 'invalid_email' })
  const { email, name } = parsed.data

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

  // Atleta già registrato? Il profilo ha l'email (trigger su auth.users).
  const { data: profile, error: profileError } = await admin
    .from('profiles')
    .select('id')
    .ilike('email', email)
    .maybeSingle()
  if (profileError) return reply(500, { error: 'lookup_failed' })

  let athleteId = profile?.id
  let invited = false
  if (!athleteId) {
    const siteUrl = Deno.env.get('SITE_URL')
    const { data, error } = await admin.auth.admin.inviteUserByEmail(email, {
      redirectTo: siteUrl ? `${siteUrl}/nuova-password` : undefined,
      // Il trigger su auth.users lo copia in profiles.full_name.
      data: name ? { full_name: name } : undefined,
    })
    if (error || !data.user) return reply(error?.status === 429 ? 429 : 502, { error: 'invite_failed' })
    athleteId = data.user.id
    invited = true
  }

  if (athleteId === coachId) return reply(400, { error: 'self_invite' })

  const { data: existing, error: linkError } = await admin
    .from('coach_athletes')
    .select('id, status')
    .eq('coach_id', coachId)
    .eq('athlete_id', athleteId)
    .maybeSingle()
  if (linkError) return reply(500, { error: 'link_failed' })

  if (existing) {
    if (existing.status !== 'ended') return reply(200, { result: 'already' })
    const { error } = await admin.from('coach_athletes').update({ status: 'pending' }).eq('id', existing.id)
    return error ? reply(500, { error: 'link_failed' }) : reply(200, { result: 'reopened' })
  }

  const { error: insertError } = await admin
    .from('coach_athletes')
    .insert({ coach_id: coachId, athlete_id: athleteId, status: 'pending' })
  if (insertError) return reply(500, { error: 'link_failed' })
  return reply(200, { result: invited ? 'invited' : 'linked' })
})
