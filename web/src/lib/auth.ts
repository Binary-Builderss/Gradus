import { z } from 'zod'
import { messages } from './messages'

const e = messages.auth.errors

export const credentialsSchema = z.object({
  email: z.email(e.emailInvalid),
  password: z.string().min(1, e.passwordRequired),
})

export const emailSchema = credentialsSchema.pick({ email: true })

export const newPasswordSchema = z
  .object({
    password: z.string().min(8, e.passwordTooShort),
    confirm: z.string(),
  })
  .refine((v) => v.password === v.confirm, { message: e.passwordMismatch, path: ['confirm'] })

/** Errori dei form: primo messaggio per campo. */
export function fieldErrors<T extends string>(error: z.ZodError): Partial<Record<T, string>> {
  const out: Partial<Record<T, string>> = {}
  for (const issue of error.issues) {
    const key = issue.path[0] as T
    out[key] ??= issue.message
  }
  return out
}

type AuthErrorLike = { name?: string; code?: string; status?: number }

/** Traduce un errore di Supabase Auth in un messaggio per l'utente. */
export function mapAuthError(error: AuthErrorLike): string {
  if (error.name === 'AuthRetryableFetchError') return e.network
  switch (error.code) {
    case 'invalid_credentials':
      return e.invalidCredentials
    case 'over_request_rate_limit':
    case 'over_email_send_rate_limit':
      return e.rateLimit
    case 'weak_password':
      return e.passwordTooShort
    case 'same_password':
      return e.samePassword
  }
  return error.status === 429 ? e.rateLimit : e.generic
}
