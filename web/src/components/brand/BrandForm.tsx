import { ImageIcon, TrashIcon } from '@phosphor-icons/react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useRef, useState } from 'react'
import { BrandPreview } from '@/components/brand/BrandPreview'
import { ColorField } from '@/components/brand/ColorField'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  BRAND_KEYS,
  contrastProblems,
  overridesFrom,
  resolveColors,
  STANDARD_COLORS,
  type BrandColors,
} from '@/lib/brand'
import { type Branding, saveBranding } from '@/lib/branding'
import { fileToLogoPng, LogoError } from '@/lib/logoImage'
import { messages } from '@/lib/messages'

const m = messages.app.settings.brand

export function BrandForm({
  coachId,
  fallbackName,
  initial,
  pro,
}: {
  coachId: string
  /** Nome del profilo: compare se il nome del marchio è vuoto. */
  fallbackName: string
  initial: Branding | null
  pro: boolean
}) {
  const queryClient = useQueryClient()
  const fileInput = useRef<HTMLInputElement>(null)
  const [name, setName] = useState(initial?.brandName ?? '')
  const [logo, setLogo] = useState<string | null>(initial?.logoPng ?? null)
  const [colors, setColors] = useState<BrandColors>(() => resolveColors(initial?.colors))
  const [logoError, setLogoError] = useState<string | null>(null)
  const [saved, setSaved] = useState(false)

  const save = useMutation({
    mutationFn: () =>
      saveBranding(coachId, { brandName: name, logoPng: logo, colors: overridesFrom(colors) }),
    onSuccess: async () => {
      setSaved(true)
      await queryClient.invalidateQueries({ queryKey: ['branding', coachId] })
    },
  })
  const touch =
    <T,>(set: (v: T) => void) =>
    (v: T) => {
      set(v)
      setSaved(false)
    }
  const problems = contrastProblems(colors)

  async function onFile(file: File | undefined) {
    if (!file) return
    setLogoError(null)
    try {
      touch(setLogo)(await fileToLogoPng(file))
    } catch (e) {
      setLogoError(e instanceof LogoError && e.reason === 'too-big' ? m.logoTooBig : m.logoUnreadable)
    }
  }

  return (
    <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_minmax(0,22rem)]" data-tour="brand-form">
      <form
        className="grid gap-6"
        onSubmit={(e) => {
          e.preventDefault()
          save.mutate()
        }}
      >
        {!pro && (
          <p role="status" className="rounded-lg border border-dashed p-4 text-muted-foreground">
            {m.locked}
          </p>
        )}
        <fieldset disabled={!pro} className="grid gap-6 disabled:opacity-70">
          <div className="grid gap-2">
            <label htmlFor="brand-name" className="font-medium">
              {m.name}
            </label>
            <Input
              id="brand-name"
              value={name}
              maxLength={80}
              placeholder={m.namePlaceholder}
              onChange={(e) => touch(setName)(e.target.value)}
              className="max-w-sm"
            />
            <p className="text-xs text-muted-foreground">{m.nameHint}</p>
          </div>

          <div className="grid gap-2">
            <span className="font-medium">{m.logo}</span>
            <div className="flex flex-wrap items-center gap-3">
              {logo ? (
                <img
                  src={`data:image/png;base64,${logo}`}
                  alt={m.logoAlt}
                  className="h-14 w-auto max-w-40 rounded-md border bg-muted/40 object-contain p-1"
                />
              ) : (
                <span className="grid h-14 w-14 place-items-center rounded-md border border-dashed text-muted-foreground">
                  <ImageIcon size={22} />
                </span>
              )}
              <input
                ref={fileInput}
                type="file"
                accept="image/png,image/jpeg,image/webp,image/svg+xml"
                className="sr-only"
                aria-label={m.logo}
                onChange={(e) => {
                  void onFile(e.target.files?.[0])
                  e.target.value = ''
                }}
              />
              <Button type="button" variant="outline" onClick={() => fileInput.current?.click()}>
                {logo ? m.logoChange : m.logoUpload}
              </Button>
              {logo && (
                <Button type="button" variant="ghost" onClick={() => touch(setLogo)(null)}>
                  <TrashIcon data-icon="inline-start" />
                  {m.logoRemove}
                </Button>
              )}
            </div>
            <p className="text-xs text-muted-foreground">{m.logoHint}</p>
            {logoError && (
              <p role="alert" className="text-sm text-destructive">
                {logoError}
              </p>
            )}
          </div>

          <div className="grid gap-4">
            <div className="flex flex-wrap items-end justify-between gap-2">
              <div>
                <h2 className="font-medium">{m.colors}</h2>
                <p className="text-xs text-muted-foreground">{m.colorsHint}</p>
              </div>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={() => touch(setColors)({ ...STANDARD_COLORS })}
              >
                {m.resetAll}
              </Button>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              {BRAND_KEYS.map((key) => (
                <ColorField
                  key={key}
                  name={m.colorNames[key]}
                  help={m.colorHelp[key]}
                  value={colors[key]}
                  standard={STANDARD_COLORS[key]}
                  disabled={!pro}
                  onChange={(hex) => touch(setColors)({ ...colors, [key]: hex })}
                />
              ))}
            </div>
            {problems.map((p) => (
              <p key={p} role="status" className="text-sm text-warning-foreground">
                {m.contrast[p]}
              </p>
            ))}
          </div>
        </fieldset>

        <div className="flex items-center gap-3">
          <Button type="submit" disabled={!pro || save.isPending}>
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

      <div className="lg:sticky lg:top-8 lg:self-start">
        <BrandPreview colors={colors} brandName={name.trim() || fallbackName} logoPng={logo} />
      </div>
    </div>
  )
}
