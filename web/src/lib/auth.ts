import { z } from 'zod'
import { messages } from './messages'

const e = messages.auth.errors

export const credentialsSchema = z.object({
  email: z.email(e.emailInvalid),
  password: z.string().min(1, e.passwordRequired),
})

export const emailSchema = credentialsSchema.pick({ email: true })

const passwordFields = {
  password: z.string().min(8, e.passwordTooShort),
  confirm: z.string(),
}
const samePasswords = { message: e.passwordMismatch, path: ['confirm'] }

export const newPasswordSchema = z
  .object(passwordFields)
  .refine((v) => v.password === v.confirm, samePasswords)

export const signupSchema = z
  .object({
    full_name: z.string().trim().min(1, e.nameRequired),
    email: z.email(e.emailInvalid),
    ...passwordFields,
  })
  .refine((v) => v.password === v.confirm, samePasswords)

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
    case 'user_already_exists':
    case 'email_exists':
      return e.emailTaken
    case 'signup_disabled':
      return messages.auth.signup.closed
  }
  return error.status === 429 ? e.rateLimit : e.generic
}
