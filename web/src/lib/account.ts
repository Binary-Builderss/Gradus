import { FunctionsHttpError } from '@supabase/supabase-js'
import { supabase } from './supabase'

/** Manda all'utente l'email per scegliere una nuova password (stesso flusso di «Password dimenticata»). */
export async function sendPasswordReset(email: string) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${window.location.origin}/nuova-password`,
  })
  if (error) throw error
}

/** Disattiva o riattiva il proprio account: i dati restano, cambia solo la schermata che si vede. */
export async function setAccountDisabled(userId: string, disabled: boolean) {
  const { error } = await supabase
    .from('profiles')
    .update({ disabled_at: disabled ? new Date().toISOString() : null })
    .eq('id', userId)
  if (error) throw error
}

/** Cancellazione definitiva (Edge Function `delete-account`): serve l'email scritta a mano come conferma. */
export class AccountError extends Error {
  code: string | undefined
  constructor(code: string | undefined) {
    super(code ?? 'account_error')
    this.code = code
  }
}

export async function deleteAccount(confirm: string) {
  const { error } = await supabase.functions.invoke('delete-account', { body: { confirm } })
  if (!error) return
  // Un abbonamento che si rinnova ancora ferma la cancellazione: la persona deve prima disdire.
  if (error instanceof FunctionsHttpError) {
    const payload = (await (error.context as Response).json().catch(() => null)) as { error?: string } | null
    throw new AccountError(payload?.error)
  }
  throw error
}
