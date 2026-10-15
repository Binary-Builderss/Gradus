import { supabase } from './supabase'

/** Manda all'utente l'email per scegliere una nuova password (stesso flusso di «Password dimenticata»). */
export async function sendPasswordReset(email: string) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${window.location.origin}/nuova-password`,
  })
  if (error) throw error
}
