import { FunctionsHttpError } from '@supabase/supabase-js'
import { inviteErrorMessage, type InviteResult } from './inviteMessages'
import { messages } from './messages'
import { supabase } from './supabase'

const m = messages.app.athletes.invite

export async function inviteAthlete(args: { email: string; name?: string }): Promise<InviteResult> {
  const { data, error } = await supabase.functions.invoke<{ result: InviteResult }>('invite-athlete', {
    body: args,
  })
  if (error) {
    if (error instanceof FunctionsHttpError) {
      const res = error.context as Response
      const payload = (await res.json().catch(() => null)) as { error?: string; limit?: number | null } | null
      throw new Error(inviteErrorMessage(payload?.error, res.status, payload?.limit))
    }
    throw new Error(m.errors.network)
  }
  return data!.result
}
