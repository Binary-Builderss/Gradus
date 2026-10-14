import { ArrowRightIcon, EyeIcon, EyeSlashIcon } from '@phosphor-icons/react'
import { useState, type FormEvent } from 'react'
import type { z } from 'zod'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { credentialsSchema, emailSchema, fieldErrors, newPasswordSchema } from '@/lib/auth'
import { messages } from '@/lib/messages'

const m = messages.auth

/** Risultato di un invio: messaggio d'errore da mostrare, o null se è andato a buon fine. */
type Submit<T> = (values: T) => Promise<string | null>

function useAuthForm<S extends z.ZodType>(schema: S, onSubmit: Submit<z.infer<S>>) {
  const [errors, setErrors] = useState<Record<string, string | undefined>>({})
  const [formError, setFormError] = useState<string | null>(null)
  const [pending, setPending] = useState(false)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const parsed = schema.safeParse(Object.fromEntries(new FormData(event.currentTarget)))
    if (!parsed.success) {
      setErrors(fieldErrors(parsed.error))
      return
    }
    setErrors({})
    setFormError(null)
    setPending(true)
    try {
      setFormError(await onSubmit(parsed.data))
    } catch {
      setFormError(m.errors.generic)
    } finally {
      setPending(false)
    }
  }

  return { errors, formError, pending, submit }
}

function TextField({
  name,
  label,
  type = 'text',
  autoComplete,
  autoFocus,
  error,
}: {
  name: string
  label: string
  type?: 'text' | 'email' | 'password'
  autoComplete: string
  autoFocus?: boolean
  error?: string
}) {
  const [visible, setVisible] = useState(false)
  const id = `field-${name}`
  const isPassword = type === 'password'
  return (
    <div className="grid gap-2">
      <Label htmlFor={id}>{label}</Label>
      <div className="relative">
        <Input
          id={id}
          name={name}
          type={isPassword && visible ? 'text' : type}
          autoComplete={autoComplete}
          autoFocus={autoFocus}
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? `${id}-error` : undefined}
          className={isPassword ? 'h-11 pr-11 text-base' : 'h-11 text-base'}
        />
        {isPassword && (
          <button
            type="button"
            onClick={() => setVisible((v) => !v)}
            aria-label={visible ? m.hidePassword : m.showPassword}
            className="absolute inset-y-0 right-0 grid w-11 place-items-center rounded-r-lg text-muted-foreground transition-colors hover:text-foreground focus-visible:text-foreground focus-visible:outline-none"
          >
            {visible ? <EyeSlashIcon size={18} /> : <EyeIcon size={18} />}
          </button>
        )}
      </div>
      {error && (
        <p id={`${id}-error`} className="text-sm text-destructive">
          {error}
        </p>
      )}
    </div>
  )
}

function FormError({ message }: { message: string | null }) {
  if (!message) return null
  return (
    <p
      role="alert"
      className="rounded-lg border border-destructive/30 bg-destructive/10 px-3 py-2.5 text-sm text-destructive"
    >
      {message}
    </p>
  )
}

function SubmitButton({
  pending,
  label,
  pendingLabel,
}: {
  pending: boolean
  label: string
  pendingLabel: string
}) {
  return (
    <Button
      type="submit"
      size="lg"
      disabled={pending}
      className="h-11 w-full font-display text-base font-semibold tracking-wider uppercase"
    >
      {pending ? pendingLabel : label}
      {!pending && <ArrowRightIcon weight="bold" />}
    </Button>
  )
}

export function LoginForm({ onSubmit }: { onSubmit: Submit<z.infer<typeof credentialsSchema>> }) {
  const { errors, formError, pending, submit } = useAuthForm(credentialsSchema, onSubmit)
  return (
    <form noValidate onSubmit={submit} className="grid gap-5">
      <TextField
        name="email"
        type="email"
        label={m.email}
        autoComplete="email"
        autoFocus
        error={errors.email}
      />
      <TextField
        name="password"
        type="password"
        label={m.password}
        autoComplete="current-password"
        error={errors.password}
      />
      <FormError message={formError} />
      <SubmitButton pending={pending} label={m.login.submit} pendingLabel={m.login.submitting} />
    </form>
  )
}

export function RecoveryForm({ onSubmit }: { onSubmit: Submit<z.infer<typeof emailSchema>> }) {
  const { errors, formError, pending, submit } = useAuthForm(emailSchema, onSubmit)
  return (
    <form noValidate onSubmit={submit} className="grid gap-5">
      <TextField
        name="email"
        type="email"
        label={m.email}
        autoComplete="email"
        autoFocus
        error={errors.email}
      />
      <FormError message={formError} />
      <SubmitButton pending={pending} label={m.recovery.submit} pendingLabel={m.recovery.submitting} />
    </form>
  )
}

export function NewPasswordForm({ onSubmit }: { onSubmit: Submit<z.infer<typeof newPasswordSchema>> }) {
  const { errors, formError, pending, submit } = useAuthForm(newPasswordSchema, onSubmit)
  return (
    <form noValidate onSubmit={submit} className="grid gap-5">
      <TextField
        name="password"
        type="password"
        label={m.newPassword.label}
        autoComplete="new-password"
        autoFocus
        error={errors.password}
      />
      <TextField
        name="confirm"
        type="password"
        label={m.newPassword.confirm}
        autoComplete="new-password"
        error={errors.confirm}
      />
      <FormError message={formError} />
      <SubmitButton pending={pending} label={m.newPassword.submit} pendingLabel={m.newPassword.submitting} />
    </form>
  )
}
