import { XIcon } from '@phosphor-icons/react'
import { useMutation, useQuery, useQueryClient, type UseQueryResult } from '@tanstack/react-query'
import { useEffect, useState, type FormEvent, type ReactNode } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { deletePreset, progressionPresetsQuery, savePreset } from '@/lib/progressionPresets'
import { applyProgression, previewProgression, type ProgressionWeek } from '@/lib/blocks'
import { fieldErrors } from '@/lib/auth'
import { describeCell } from '@/lib/cellFields'
import { messages } from '@/lib/messages'
import {
  buildRule,
  EMPTY_PROGRESSION,
  PROGRESSION_EXAMPLES,
  progressionSchema,
  ruleToInput,
  type ProgressionInput,
} from '@/lib/progressionRule'
import { cn } from '@/lib/utils'

const m = messages.app.mesocycle.progression
const METHODS = ['BUF', 'RPE', 'RM', 'PCT_1RM', 'LOAD'] as const
const PREVIEW_DELAY_MS = 350

export function ProgressionForm({
  coachId,
  mesocycleId,
  blockId,
}: {
  coachId: string
  mesocycleId: string
  blockId: string
}) {
  const queryClient = useQueryClient()
  const [values, setValues] = useState<ProgressionInput>(EMPTY_PROGRESSION)
  const [errors, setErrors] = useState<Record<string, string | undefined>>({})

  const parsed = progressionSchema.safeParse(values)
  const rule = parsed.success ? buildRule(parsed.data) : null
  const ruleKey = rule ? JSON.stringify(rule) : null
  // L'anteprima parte quando si smette di scrivere, non a ogni tasto.
  const [settledKey, setSettledKey] = useState<string | null>(null)
  useEffect(() => {
    const timer = setTimeout(() => setSettledKey(ruleKey), PREVIEW_DELAY_MS)
    return () => clearTimeout(timer)
  }, [ruleKey])

  const preview = useQuery({
    queryKey: ['progression-preview', blockId, settledKey],
    queryFn: () => previewProgression(blockId, JSON.parse(settledKey!) as Record<string, unknown>),
    enabled: settledKey !== null,
    retry: false,
  })

  const apply = useMutation({
    mutationKey: ['editor'],
    mutationFn: (r: Record<string, unknown>) => applyProgression(blockId, r),
    onSettled: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: ['block-weeks', mesocycleId] }),
        queryClient.invalidateQueries({ queryKey: ['progression-preview', blockId] }),
      ]),
  })

  const presets = useQuery(progressionPresetsQuery(coachId))
  const refreshPresets = () => queryClient.invalidateQueries({ queryKey: ['progression-presets', coachId] })
  const [modelName, setModelName] = useState('')
  const [modelError, setModelError] = useState<string | null>(null)
  const saveModel = useMutation({
    mutationFn: (v: { name: string; rule: Record<string, unknown> }) => savePreset(coachId, v.name, v.rule),
    onSuccess: async (_, v) => {
      setModelName('')
      await refreshPresets()
      return v
    },
    onError: (error: { code?: string }) =>
      setModelError(error.code === '23505' ? m.models.errors.duplicate : m.models.errors.generic),
  })
  const removeModel = useMutation({
    mutationFn: (id: string) => deletePreset(coachId, id),
    onSuccess: refreshPresets,
  })

  function submitModel(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    saveModel.reset()
    const name = modelName.trim()
    if (!name) return setModelError(m.models.errors.nameRequired)
    if (name.length > 80) return setModelError(m.models.errors.nameTooLong)
    if (!parsed.success) {
      setErrors(fieldErrors(parsed.error))
      return setModelError(m.models.errors.incomplete)
    }
    setModelError(null)
    saveModel.mutate({ name, rule: buildRule(parsed.data) })
  }

  const set = (name: keyof ProgressionInput) => (value: string) => {
    setValues((v) => ({ ...v, [name]: value }))
    apply.reset()
  }
  function load(example: ProgressionInput) {
    setValues(example)
    setErrors({})
    apply.reset()
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    apply.reset()
    if (!parsed.success) return setErrors(fieldErrors(parsed.error))
    setErrors({})
    apply.mutate(buildRule(parsed.data))
  }

  const writable = preview.data?.filter((w) => w.action === 'write').length

  return (
    <div className="grid gap-4">
      <form noValidate onSubmit={submit} className="grid gap-4">
        <p className="text-sm text-muted-foreground">{m.hint}</p>

        <div className="flex flex-wrap items-center gap-2" role="group" aria-label={m.examples}>
          <span className="text-xs text-muted-foreground">{m.examples}</span>
          {(Object.keys(PROGRESSION_EXAMPLES) as (keyof typeof PROGRESSION_EXAMPLES)[]).map((key) => (
            <Button
              key={key}
              type="button"
              variant="outline"
              size="sm"
              onClick={() => load(PROGRESSION_EXAMPLES[key])}
            >
              {m.exampleNames[key]}
            </Button>
          ))}
        </div>

        <div className="grid gap-2" role="group" aria-label={m.models.title}>
          <span className="text-xs text-muted-foreground">{m.models.title}</span>
          {presets.isError ? (
            <p className="text-sm text-destructive">{m.models.loadError}</p>
          ) : presets.data?.length === 0 ? (
            <p className="text-sm text-muted-foreground">{m.models.empty}</p>
          ) : (
            <ul className="flex flex-wrap gap-2">
              {presets.data?.map((p) => (
                <li
                  key={p.id}
                  className="inline-flex items-center rounded-md border bg-background dark:bg-input/30"
                >
                  <button
                    type="button"
                    onClick={() => load(ruleToInput(p.rule))}
                    className="h-8 rounded-l-md px-3 text-sm hover:bg-muted focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
                  >
                    {p.name}
                  </button>
                  <button
                    type="button"
                    aria-label={m.models.remove(p.name)}
                    title={m.models.remove(p.name)}
                    disabled={removeModel.isPending}
                    onClick={() => removeModel.mutate(p.id)}
                    className="grid h-8 w-8 place-items-center rounded-r-md border-l text-muted-foreground hover:bg-muted hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
                  >
                    <XIcon size={14} />
                  </button>
                </li>
              ))}
            </ul>
          )}
          {removeModel.isError && (
            <p role="alert" className="text-sm text-destructive">
              {m.models.errors.removeFailed}
            </p>
          )}
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <Group title={m.setsGroup} hint={m.setsHint}>
            <Num
              label={m.setsStart}
              value={values.setsStart}
              onChange={set('setsStart')}
              error={errors.setsStart}
            />
            <Num
              label={m.setsStep}
              value={values.setsStep}
              onChange={set('setsStep')}
              error={errors.setsStep}
            />
            <Num label={m.setsMax} value={values.setsMax} onChange={set('setsMax')} error={errors.setsMax} />
          </Group>
          <Group title={m.repsGroup} hint={m.repsHint}>
            <Num label={m.repsMin} value={values.repsMin} onChange={set('repsMin')} error={errors.repsMin} />
            <Num label={m.repsMax} value={values.repsMax} onChange={set('repsMax')} error={errors.repsMax} />
          </Group>
          <Group title={m.effortGroup} hint={m.effortHint}>
            <label className="grid gap-1.5 text-xs text-muted-foreground">
              {m.method}
              <select
                value={values.method}
                onChange={(e) => set('method')(e.target.value)}
                className="h-9 rounded-md border bg-background px-2 text-sm text-foreground dark:bg-input/30"
              >
                <option value="">{m.noMethod}</option>
                {METHODS.map((x) => (
                  <option key={x} value={x}>
                    {m.methods[x]}
                  </option>
                ))}
              </select>
            </label>
            <Num
              label={m.intStart}
              value={values.intStart}
              onChange={set('intStart')}
              error={errors.intStart}
            />
            <Num label={m.intStep} value={values.intStep} onChange={set('intStep')} error={errors.intStep} />
            <Num label={m.intMin} value={values.intMin} onChange={set('intMin')} error={errors.intMin} />
          </Group>
          <Group title={m.weeksGroup} hint={m.weeksHint}>
            <Num
              label={m.fromWeek}
              value={values.fromWeek}
              onChange={set('fromWeek')}
              error={errors.fromWeek}
            />
            <Num label={m.toWeek} value={values.toWeek} onChange={set('toWeek')} error={errors.toWeek} />
          </Group>
        </div>

        <section aria-label={m.preview.title} className="grid gap-2 rounded-md border p-3">
          <h4 className="text-sm font-medium">{m.preview.title}</h4>
          <Preview query={preview} idle={ruleKey === null} />
        </section>

        <div className="flex flex-wrap items-center gap-3">
          <Button type="submit" disabled={apply.isPending}>
            {apply.isPending
              ? m.applying
              : writable !== undefined && ruleKey === settledKey
                ? m.applyTo(writable)
                : m.apply}
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

      <form noValidate onSubmit={submitModel} className="grid gap-2 rounded-md border p-3">
        <h4 className="text-sm font-medium">{m.models.saveTitle}</h4>
        <p className="text-xs text-muted-foreground">{m.models.saveHint}</p>
        <div className="flex flex-wrap items-start gap-3">
          <label className="grid min-w-56 flex-1 gap-1.5 text-xs text-muted-foreground">
            {m.models.nameLabel}
            <Input
              value={modelName}
              maxLength={80}
              onChange={(e) => {
                setModelName(e.target.value)
                setModelError(null)
                saveModel.reset()
              }}
              aria-invalid={modelError ? true : undefined}
              className="h-9 text-sm text-foreground"
            />
          </label>
          <Button type="submit" variant="outline" disabled={saveModel.isPending} className="mt-5">
            {saveModel.isPending ? m.models.saving : m.models.save}
          </Button>
        </div>
        <p role={modelError ? 'alert' : 'status'} className="min-h-5 text-sm">
          {modelError ? (
            <span className="text-destructive">{modelError}</span>
          ) : saveModel.isSuccess ? (
            <span className="text-primary">{m.models.saved(saveModel.variables.name)}</span>
          ) : null}
        </p>
      </form>
    </div>
  )
}

function Preview({ query, idle }: { query: UseQueryResult<ProgressionWeek[]>; idle: boolean }) {
  if (idle) return <p className="text-sm text-muted-foreground">{m.preview.empty}</p>
  if (query.isError) return <p className="text-sm text-destructive">{m.preview.error}</p>
  if (!query.data) return <p className="text-sm text-muted-foreground">{m.preview.loading}</p>
  return (
    <ul className="divide-y text-sm">
      {query.data.map((w) => (
        <li key={w.week} className="flex flex-wrap items-baseline gap-x-3 gap-y-0.5 py-1.5">
          <span className="w-28 shrink-0 font-medium">{m.preview.week(w.week)}</span>
          <span
            className={cn(
              'min-w-0',
              w.action !== 'write' && 'text-muted-foreground',
              w.action === 'deload' && 'text-warning-foreground',
            )}
          >
            {w.action === 'deload'
              ? m.preview.deload
              : w.action === 'locked'
                ? m.preview.locked
                : describeCell(w.cell, w.cell.method ?? 'BUF')}
          </span>
        </li>
      ))}
    </ul>
  )
}

function Group({ title, hint, children }: { title: string; hint: string; children: ReactNode }) {
  return (
    <fieldset className="grid content-start gap-2 rounded-md border p-3">
      <legend className="px-1 text-sm font-medium">{title}</legend>
      <p className="text-xs text-muted-foreground">{hint}</p>
      <div className="flex flex-wrap items-start gap-3">{children}</div>
    </fieldset>
  )
}

function Num({
  label,
  value,
  onChange,
  error,
}: {
  label: string
  value: string
  onChange: (value: string) => void
  error?: string
}) {
  return (
    <label className="grid w-32 gap-1.5 text-xs text-muted-foreground">
      {label}
      <Input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        inputMode="decimal"
        aria-invalid={error ? true : undefined}
        className="h-9 text-sm text-foreground"
      />
      {error && (
        <span role="alert" className="text-destructive">
          {error}
        </span>
      )}
    </label>
  )
}
