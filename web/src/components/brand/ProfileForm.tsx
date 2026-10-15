import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { messages } from '@/lib/messages'
import { type Profile, saveProfileName } from '@/lib/profile'

const m = messages.app.settings.profile

export function ProfileForm({ userId, profile }: { userId: string; profile: Profile }) {
  const queryClient = useQueryClient()
  const [name, setName] = useState(profile.fullName ?? '')
  const [saved, setSaved] = useState(false)
  const save = useMutation({
    mutationFn: () => saveProfileName(userId, name),
    onSuccess: async () => {
      setSaved(true)
      // Il nome compare nella barra laterale, nella lista atleti (per chi ti ha come coach) e nel PDF.
      await Promise.all(
        [['profile', userId], ['athletes'], ['athlete']].map((queryKey) =>
          queryClient.invalidateQueries({ queryKey }),
        ),
      )
    },
  })

  return (
    <form
      className="grid max-w-md gap-4"
      data-tour="profile-form"
      onSubmit={(e) => {
        e.preventDefault()
        save.mutate()
      }}
    >
      <div className="grid gap-2">
        <label htmlFor="profile-name" className="font-medium">
          {m.name}
        </label>
        <Input
          id="profile-name"
          value={name}
          maxLength={80}
          autoComplete="name"
          placeholder={m.namePlaceholder}
          onChange={(e) => {
            setName(e.target.value)
            setSaved(false)
          }}
        />
      </div>
      <div className="grid gap-1">
        <span className="font-medium">{m.email}</span>
        <p className="text-muted-foreground">{profile.email}</p>
        <p className="text-xs text-muted-foreground">{m.emailHint}</p>
      </div>
      <div className="flex items-center gap-3">
        <Button type="submit" disabled={save.isPending}>
          {save.isPending ? m.saving : m.save}
        </Button>
        {saved && !save.isPending && (
          <span role="status" className="text-sm text-muted-foreground">
            {m.saved}
          </span>
        )}
        {save.isError && (
          <span role="alert" className="text-sm text-destructive">
            {m.saveError}
          </span>
        )}
      </div>
    </form>
  )
}
