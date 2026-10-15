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
  new Response(JSON.stringify(payload), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })

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

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

  // Un account disattivato non invita nessuno finché non lo riattiva.
  const { data: self } = await admin.from('profiles').select('disabled_at').eq('id', coachId).maybeSingle()
  if (self?.disabled_at) return reply(403, { error: 'account_disabled' })

  // Tetto di atleti del piano (la regola sta nel database: plan_usage). Si controlla prima di mandare
  // l'email di invito, così un tetto pieno non crea utenti a vuoto.
  const { data: usage } = await caller.rpc('plan_usage')
  const row = usage?.[0]
  const full = row != null && row.athlete_limit !== null && row.athletes >= row.athlete_limit
  const limitReached = () =>
    reply(409, {
      error: 'athlete_limit_reached',
      limit: row?.athlete_limit ?? null,
    })

  const parsed = body.safeParse(await req.json().catch(() => null))
  if (!parsed.success) return reply(400, { error: 'invalid_email' })
  const { email, name } = parsed.data

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
    if (full) return limitReached()
    const siteUrl = Deno.env.get('SITE_URL')
    const { data, error } = await admin.auth.admin.inviteUserByEmail(email, {
      redirectTo: siteUrl ? `${siteUrl}/nuova-password` : undefined,
      // Il trigger su auth.users lo copia in profiles.full_name.
      data: name ? { full_name: name } : undefined,
    })
    if (error || !data.user)
      return reply(error?.status === 429 ? 429 : 502, {
        error: 'invite_failed',
      })
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

  if (!existing && full) return limitReached()
  if (existing) {
    if (existing.status !== 'ended') return reply(200, { result: 'already' })
    if (full) return limitReached()
    const { error } = await admin.from('coach_athletes').update({ status: 'pending' }).eq('id', existing.id)
    if (error?.message.includes('athlete_limit_reached')) return limitReached()
    return error ? reply(500, { error: 'link_failed' }) : reply(200, { result: 'reopened' })
  }

  const { error: insertError } = await admin
    .from('coach_athletes')
    .insert({ coach_id: coachId, athlete_id: athleteId, status: 'pending' })
  if (insertError?.message.includes('athlete_limit_reached')) return limitReached()
  if (insertError) return reply(500, { error: 'link_failed' })
  return reply(200, { result: invited ? 'invited' : 'linked' })
})
