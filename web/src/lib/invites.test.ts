import { describe, expect, it } from 'vitest'
import { inviteErrorMessage } from './inviteMessages'
import { messages } from './messages'

const e = messages.app.athletes.invite.errors

describe('inviteErrorMessage', () => {
  it('codici noti', () => {
    expect(inviteErrorMessage('invalid_email')).toBe(e.invalidEmail)
    expect(inviteErrorMessage('self_invite')).toBe(e.selfInvite)
    expect(inviteErrorMessage('invite_failed', 502)).toBe(e.inviteFailed)
  })
  it('tetto di atleti e account disattivato', () => {
    expect(inviteErrorMessage('athlete_limit_reached', 409, 20)).toContain('limite di 20 atleti')
    expect(inviteErrorMessage('athlete_limit_reached', 409, null)).toContain('limite di atleti')
    expect(inviteErrorMessage('account_disabled', 403)).toContain('disattivato')
  })
  it('429 vince sul codice', () => expect(inviteErrorMessage('invite_failed', 429)).toBe(e.rateLimit))
  it('codice sconosciuto o assente', () => {
    expect(inviteErrorMessage('boh')).toBe(e.generic)
    expect(inviteErrorMessage(undefined)).toBe(e.generic)
  })
})
