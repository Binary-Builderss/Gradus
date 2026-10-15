import { ArrowCounterClockwiseIcon } from '@phosphor-icons/react'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { normalizeHex } from '@/lib/brand'
import { messages } from '@/lib/messages'

const m = messages.app.settings.brand

export function ColorField({
  name,
  help,
  value,
  standard,
  disabled,
  onChange,
}: {
  name: string
  help: string
  value: string
  standard: string
  disabled: boolean
  onChange: (hex: string) => void
}) {
  const [draft, setDraft] = useState(value)
  const [prev, setPrev] = useState(value)
  // Il valore cambia da fuori (selettore, ripristino): la bozza si riallinea.
  if (prev !== value) {
    setPrev(value)
    setDraft(value)
  }
  const invalid = normalizeHex(draft) === null
  const changed = value.toUpperCase() !== standard.toUpperCase()

  return (
    <div className="grid grid-cols-[2.5rem_1fr_auto] items-center gap-x-3 gap-y-0.5">
      <input
        type="color"
        aria-label={m.pickerLabel(name)}
        value={value.toLowerCase()}
        disabled={disabled}
        onChange={(e) => onChange(e.target.value.toUpperCase())}
        className="row-span-2 h-10 w-10 cursor-pointer rounded-md border border-input bg-transparent p-0.5 disabled:cursor-not-allowed disabled:opacity-50"
      />
      <label htmlFor={`hex-${name}`} className="font-medium">
        {name}
      </label>
      <Button
        type="button"
        variant="ghost"
        size="icon-sm"
        className="row-span-2"
        aria-label={m.reset(name)}
        title={m.reset(name)}
        disabled={disabled || !changed}
        onClick={() => onChange(standard)}
      >
        <ArrowCounterClockwiseIcon />
      </Button>
      <div className="grid gap-0.5">
        <Input
          id={`hex-${name}`}
          aria-label={m.hexLabel(name)}
          aria-invalid={invalid || undefined}
          value={draft}
          disabled={disabled}
          maxLength={7}
          spellCheck={false}
          onChange={(e) => {
            setDraft(e.target.value)
            // Mentre scrivi conta solo il codice completo: «#0a7» è ancora a metà di «#0a7d4b».
            if (/^#?[0-9a-f]{6}$/i.test(e.target.value.trim())) onChange(normalizeHex(e.target.value)!)
          }}
          onBlur={() => {
            // Al termine anche la forma corta («#fa0») vale; un testo non valido torna all'ultimo colore buono.
            const hex = normalizeHex(draft)
            if (hex && hex !== value) onChange(hex)
            else setDraft(value)
          }}
          className="h-8 w-28 font-mono text-sm"
        />
        <p className="text-xs text-muted-foreground">{help}</p>
      </div>
    </div>
  )
}
