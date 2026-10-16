import { CheckIcon, MinusIcon, PencilSimpleIcon, PlusIcon, XIcon } from '@phosphor-icons/react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { fieldErrors } from '@/lib/auth'
import { messages } from '@/lib/messages'
import {
  addDays,
  adherenceSummary,
  deviationPct,
  kcalFromMacros,
  macroFormSchema,
  macroMismatch,
  nutritionOverviewQuery,
  nutritionPlansQuery,
  planInForce,
  saveNutritionPlan,
  todayIso,
  type MacroTargets,
  type NutritionPlan,
  type OverviewDay,
} from '@/lib/nutrition'
import { cn } from '@/lib/utils'

const m = messages.app.nutrition
const dateFormat = new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'short', year: 'numeric' })
const shortDate = new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'short' })
const number = new Intl.NumberFormat('it-IT', { maximumFractionDigits: 0 })
const label = (iso: string, format = dateFormat) => format.format(new Date(`${iso}T12:00:00`))

const DAYS = 14

/** Obiettivi di macro dell'atleta (li scrive il coach) e come li sta seguendo (lo registra l'atleta, con il suo consenso). */
export function MacroSection({ coachId, athleteId }: { coachId: string; athleteId: string }) {
  const plans = useQuery(nutritionPlansQuery(athleteId))
  const [editing, setEditing] = useState(false)
  const today = todayIso()
  const current = plans.data ? planInForce(plans.data, today) : null
  const upcoming = plans.data?.filter((p) => p.validFrom > today).at(-1) ?? null

  return (
    <section className="space-y-3" data-tour="macros">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="grid gap-0.5">
          <h2 className="text-sm font-semibold">{m.title}</h2>
          <p className="max-w-prose text-xs text-muted-foreground">{m.hint}</p>
        </div>
        {plans.isSuccess && !editing && (
          <Button variant="outline" onClick={() => setEditing(true)}>
            {current ? <PencilSimpleIcon data-icon="inline-start" /> : <PlusIcon data-icon="inline-start" />}
            {current ? m.edit : m.set}
          </Button>
        )}
      </div>

      {plans.isPending ? (
        <div aria-hidden className="h-20 animate-pulse rounded-lg border bg-muted/40" />
      ) : plans.isError ? (
        <p role="alert" className="text-sm text-destructive">
          {m.loadError}
        </p>
      ) : editing ? (
        <MacroForm
          coachId={coachId}
          athleteId={athleteId}
          initial={current}
          today={today}
          onDone={() => setEditing(false)}
        />
      ) : current ? (
        <Targets plan={current} upcoming={upcoming} />
      ) : (
        <div className="space-y-1 rounded-lg border border-dashed p-4">
          <p className="text-sm font-medium">{m.empty}</p>
          <p className="max-w-prose text-sm text-muted-foreground">{m.emptyHint}</p>
        </div>
      )}

      {plans.isSuccess && current && <Adherence athleteId={athleteId} today={today} />}
    </section>
  )
}

function Targets({ plan, upcoming }: { plan: NutritionPlan; upcoming: NutritionPlan | null }) {
  const t = plan.targets
  const stats: { key: keyof typeof m.stats; value: number | null; unit: string }[] = [
    { key: 'kcal', value: t.kcal, unit: m.units.kcal },
    { key: 'protein', value: t.protein_g, unit: m.units.g },
    { key: 'carbs', value: t.carbs_g, unit: m.units.g },
    { key: 'fat', value: t.fat_g, unit: m.units.g },
    { key: 'fiber', value: t.fiber_g, unit: m.units.g },
  ]
  return (
    <div className="space-y-2">
      <dl className="grid grid-cols-2 divide-x divide-y overflow-hidden rounded-lg border bg-card sm:grid-cols-5 sm:divide-y-0">
        {stats.map((s) => (
          <div key={s.key} className="px-4 py-3">
            <dt className="text-xs text-muted-foreground">{m.stats[s.key]}</dt>
            <dd className="text-lg font-semibold tabular-nums">
              {s.value === null ? '–' : number.format(s.value)}
              {s.value !== null && (
                <span className="ml-1 text-xs font-normal text-muted-foreground">{s.unit}</span>
              )}
            </dd>
          </div>
        ))}
      </dl>
      <p className="text-xs text-muted-foreground">
        {m.current(label(plan.validFrom))} · {m.tolerance(plan.tolerancePct)}
        {upcoming && <> · {m.next(label(upcoming.validFrom))}</>}
      </p>
    </div>
  )
}

function MacroForm({
  coachId,
  athleteId,
  initial,
  today,
  onDone,
}: {
  coachId: string
  athleteId: string
  initial: NutritionPlan | null
  today: string
  onDone: () => void
}) {
  const f = m.form
  const queryClient = useQueryClient()
  const [errors, setErrors] = useState<Record<string, string | undefined>>({})
  const [values, setValues] = useState({
    kcal: initial ? String(initial.targets.kcal) : '',
    protein_g: initial ? String(initial.targets.protein_g) : '',
    carbs_g: initial ? String(initial.targets.carbs_g) : '',
    fat_g: initial ? String(initial.targets.fat_g) : '',
  })
  const save = useMutation({
    mutationFn: (form: Parameters<typeof saveNutritionPlan>[2]) =>
      saveNutritionPlan(coachId, athleteId, form),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['nutrition-plans', athleteId] })
      await queryClient.invalidateQueries({ queryKey: ['nutrition-overview', athleteId] })
      onDone()
    },
  })

  const targets: MacroTargets = {
    kcal: Number(values.kcal) || 0,
    protein_g: Number(values.protein_g) || 0,
    carbs_g: Number(values.carbs_g) || 0,
    fat_g: Number(values.fat_g) || 0,
    fiber_g: null,
  }
  const mismatch = targets.kcal > 0 && macroMismatch(targets)

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    save.reset()
    const parsed = macroFormSchema.safeParse(Object.fromEntries(new FormData(event.currentTarget)))
    if (!parsed.success) return setErrors(fieldErrors(parsed.error))
    setErrors({})
    save.mutate(parsed.data)
  }
  const bind = (name: keyof typeof values) => ({
    name,
    value: values[name],
    inputMode: 'numeric' as const,
    onChange: (e: React.ChangeEvent<HTMLInputElement>) => setValues({ ...values, [name]: e.target.value }),
  })

  return (
    <form
      noValidate
      onSubmit={submit}
      className="grid gap-4 rounded-lg border bg-card p-4"
      aria-label={f.title}
    >
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Field id="nut-kcal" label={f.kcal} error={errors.kcal}>
          <Input id="nut-kcal" autoFocus className="h-9 text-sm tabular-nums" {...bind('kcal')} />
        </Field>
        <Field id="nut-protein" label={f.protein} error={errors.protein_g}>
          <Input id="nut-protein" className="h-9 text-sm tabular-nums" {...bind('protein_g')} />
        </Field>
        <Field id="nut-carbs" label={f.carbs} error={errors.carbs_g}>
          <Input id="nut-carbs" className="h-9 text-sm tabular-nums" {...bind('carbs_g')} />
        </Field>
        <Field id="nut-fat" label={f.fat} error={errors.fat_g}>
          <Input id="nut-fat" className="h-9 text-sm tabular-nums" {...bind('fat_g')} />
        </Field>
      </div>
      {mismatch && (
        <p role="status" className="text-sm text-warning-foreground">
          {f.mismatch(number.format(kcalFromMacros(targets)))}
        </p>
      )}
      <div className="grid gap-4 sm:grid-cols-3">
        <Field id="nut-fiber" label={f.fiber} error={errors.fiber_g}>
          <Input
            id="nut-fiber"
            name="fiber_g"
            inputMode="numeric"
            defaultValue={initial?.targets.fiber_g ?? ''}
            className="h-9 text-sm tabular-nums"
          />
        </Field>
        <Field id="nut-tolerance" label={f.tolerance} error={errors.tolerance_pct} hint={f.toleranceHint}>
          <Input
            id="nut-tolerance"
            name="tolerance_pct"
            inputMode="numeric"
            defaultValue={initial?.tolerancePct ?? 10}
            className="h-9 text-sm tabular-nums"
          />
        </Field>
        <Field id="nut-from" label={f.validFrom} error={errors.valid_from} hint={f.validFromHint}>
          <Input
            id="nut-from"
            name="valid_from"
            type="date"
            defaultValue={initial && initial.validFrom > today ? initial.validFrom : today}
            className="h-9 text-sm"
          />
        </Field>
      </div>

      <div className="grid gap-1.5">
        <label className="flex items-start gap-2.5 text-sm font-medium">
          <input type="checkbox" name="declaration" className="mt-0.5 size-4 shrink-0 accent-primary" />
          {f.declaration}
        </label>
        <p className="max-w-prose text-xs text-muted-foreground">{f.declarationNote}</p>
        {errors.declaration && (
          <p role="alert" className="text-sm text-destructive">
            {errors.declaration}
          </p>
        )}
      </div>

      {save.isError && (
        <p role="alert" className="text-sm text-destructive">
          {m.errors.saveFailed}
        </p>
      )}
      <div className="flex justify-end gap-2">
        <Button type="button" variant="ghost" onClick={onDone}>
          {f.cancel}
        </Button>
        <Button type="submit" disabled={save.isPending}>
          {save.isPending ? f.saving : f.save}
        </Button>
      </div>
    </form>
  )
}

function Field({
  id,
  label,
  error,
  hint,
  children,
}: {
  id: string
  label: string
  error?: string
  hint?: string
  children: React.ReactNode
}) {
  return (
    <div className="grid content-start gap-1.5">
      <Label htmlFor={id}>{label}</Label>
      {children}
      {hint && !error && <p className="text-xs text-muted-foreground">{hint}</p>}
      {error && (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}
    </div>
  )
}

const STATUS = {
  respected: { text: m.adherence.legend.respected, cell: 'bg-emerald-600 text-white', Icon: CheckIcon },
  not_respected: { text: m.adherence.legend.notRespected, cell: 'bg-red-600 text-white', Icon: XIcon },
  none: { text: m.adherence.legend.unregistered, cell: 'bg-muted text-muted-foreground', Icon: MinusIcon },
} as const

/** Gli ultimi giorni: verde rispettato, rosso no, grigio non registrato (mai contato come non rispettato). */
function Adherence({ athleteId, today }: { athleteId: string; today: string }) {
  const overview = useQuery(nutritionOverviewQuery(athleteId, addDays(today, -(DAYS - 1)), today))
  const a = m.adherence
  const days = overview.data ?? []
  const summary = adherenceSummary(days)
  const registered = summary.respected + summary.notRespected
  const withNumbers = days.filter((d) => d.intake.kcal !== null).reverse()

  return (
    <div className="space-y-3 rounded-lg border bg-card p-4" aria-label={a.title} role="group">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h3 className="text-sm font-semibold">{a.title}</h3>
        <span className="text-xs text-muted-foreground">{a.days(DAYS)}</span>
      </div>
      {overview.isPending ? (
        <div aria-hidden className="h-10 animate-pulse rounded-md bg-muted/60" />
      ) : overview.isError ? (
        <p role="alert" className="text-sm text-destructive">
          {a.loadError}
        </p>
      ) : registered === 0 ? (
        <p className="text-sm text-muted-foreground">{a.empty}</p>
      ) : (
        <>
          <ul className="grid grid-cols-7 gap-1.5 sm:grid-cols-14" aria-label={a.days(DAYS)}>
            {days.map((d) => {
              const s = STATUS[d.status ?? 'none']
              return (
                <li
                  key={d.day}
                  className="grid justify-items-center gap-1"
                  aria-label={a.dayLabel(label(d.day, shortDate), s.text)}
                  title={a.dayLabel(label(d.day, shortDate), s.text)}
                >
                  <span className={cn('grid size-7 place-items-center rounded-md', s.cell)}>
                    <s.Icon size={14} weight="bold" aria-hidden />
                  </span>
                  <span className="text-[10px] text-muted-foreground tabular-nums">{d.day.slice(8)}</span>
                </li>
              )
            })}
          </ul>
          <p className="text-sm">{a.summary(summary.respected, registered)}</p>
          {withNumbers.length > 0 && <Details days={withNumbers} />}
        </>
      )}
    </div>
  )
}

function Details({ days }: { days: OverviewDay[] }) {
  const a = m.adherence
  return (
    <div className="space-y-1.5">
      <h4 className="text-xs font-medium text-muted-foreground">{a.detailTitle}</h4>
      <ul className="divide-y overflow-hidden rounded-md border text-sm">
        {days.map((d) => {
          const t = d.target
          return (
            <li key={d.day} className="grid gap-x-4 gap-y-0.5 px-3 py-2 sm:grid-cols-[7rem_1fr_6rem]">
              <span className="tabular-nums">{label(d.day, shortDate)}</span>
              <span className="tabular-nums">
                {m.stats.kcal}:{' '}
                {a.vsTarget(
                  number.format(d.intake.kcal ?? 0),
                  t ? number.format(t.kcal) : '–',
                  deviationPct(d.intake.kcal, t?.kcal),
                )}
                {d.intake.protein_g !== null && (
                  <span className="text-muted-foreground">
                    {' '}
                    · P {number.format(d.intake.protein_g)} · C {number.format(d.intake.carbs_g ?? 0)} · G{' '}
                    {number.format(d.intake.fat_g ?? 0)}
                  </span>
                )}
              </span>
              <span className="text-xs text-muted-foreground sm:text-right">
                {d.source ? a.sources[d.source] : ''}
              </span>
            </li>
          )
        })}
      </ul>
    </div>
  )
}
