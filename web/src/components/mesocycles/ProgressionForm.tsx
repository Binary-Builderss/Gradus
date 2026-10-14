import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { applyProgression } from '@/lib/blocks'
import { fieldErrors } from '@/lib/auth'
import { messages } from '@/lib/messages'
import { buildRule, progressionSchema } from '@/lib/progressionRule'

const m = messages.app.mesocycle.progression
const METHODS = ['BUF', 'RPE', 'RM', 'PCT_1RM', 'LOAD'] as const

export function ProgressionForm({ mesocycleId, blockId }: { mesocycleId: string; blockId: string }) {
  const queryClient = useQueryClient()
  const [errors, setErrors] = useState<Record<string, string | undefined>>({})
  const apply = useMutation({
    mutationKey: ['editor'],
    mutationFn: (rule: Record<string, unknown>) => applyProgression(blockId, rule),
    onSettled: () => queryClient.invalidateQueries({ queryKey: ['block-weeks', mesocycleId] }),
  })

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    apply.reset()
    const parsed = progressionSchema.safeParse(Object.fromEntries(new FormData(event.currentTarget)))
    if (!parsed.success) return setErrors(fieldErrors(parsed.error))
    setErrors({})
    apply.mutate(buildRule(parsed.data))
  }

  return (
    <form noValidate onSubmit={submit} className="grid gap-3 border-t pt-4">
      <h4 className="text-sm font-medium">{m.title}</h4>
      <p className="text-xs text-muted-foreground">{m.hint}</p>
      <div className="flex flex-wrap items-start gap-3">
        <Num name="setsStart" label={m.setsStart} error={errors.setsStart} />
        <Num name="setsStep" label={m.setsStep} error={errors.setsStep} />
        <Num name="setsMax" label={m.setsMax} error={errors.setsMax} />
        <Num name="repsMin" label={m.repsMin} error={errors.repsMin} />
        <Num name="repsMax" label={m.repsMax} error={errors.repsMax} />
      </div>
      <div className="flex flex-wrap items-start gap-3">
        <label className="grid gap-1.5 text-xs text-muted-foreground">
          {m.method}
          <select
            name="method"
            defaultValue=""
            className="h-8 rounded-md border bg-background px-2 text-sm dark:bg-input/30"
          >
            <option value="">{m.noMethod}</option>
            {METHODS.map((x) => (
              <option key={x} value={x}>
                {m.methods[x]}
              </option>
            ))}
          </select>
        </label>
        <Num name="intStart" label={m.intStart} error={errors.intStart} />
        <Num name="intStep" label={m.intStep} error={errors.intStep} />
        <Num name="intMin" label={m.intMin} error={errors.intMin} />
        <Num name="fromWeek" label={m.fromWeek} error={errors.fromWeek} />
        <Num name="toWeek" label={m.toWeek} error={errors.toWeek} />
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <Button type="submit" disabled={apply.isPending}>
          {apply.isPending ? m.applying : m.apply}
        </Button>
        <p role="status" className="text-sm">
          {apply.isError ? (
            <span className="text-destructive">{m.errors.server}</span>
          ) : apply.isSuccess ? (
            <span className="text-primary">{m.done(apply.data)}</span>
          ) : null}
        </p>
      </div>
    </form>
  )
}

function Num({ name, label, error }: { name: string; label: string; error?: string }) {
  return (
    <label className="grid w-36 gap-1.5 text-xs text-muted-foreground">
      {label}
      <Input
        name={name}
        inputMode="decimal"
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? `${name}-error` : undefined}
        className="h-9 text-sm"
      />
      {error && (
        <span id={`${name}-error`} role="alert" className="text-destructive">
          {error}
        </span>
      )}
    </label>
  )
}
