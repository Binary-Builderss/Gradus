import { messages } from './messages'

const m = messages.app.athletes.invite

export type InviteResult = 'invited' | 'linked' | 'reopened' | 'already'

const resultMessage: Record<InviteResult, string> = {
  invited: m.invited,
  linked: m.linked,
  reopened: m.reopened,
  already: m.already,
}

const errorMessage: Record<string, string> = {
  invalid_email: m.errors.invalidEmail,
  self_invite: m.errors.selfInvite,
  invite_failed: m.errors.inviteFailed,
}

export const inviteResultMessage = (result: InviteResult) => resultMessage[result]

/** Codice d'errore della Edge Function (corpo `{ error }`) tradotto in testo per il coach. */
export function inviteErrorMessage(code: string | undefined, status?: number): string {
  if (status === 429) return m.errors.rateLimit
  return (code && errorMessage[code]) || m.errors.generic
}
