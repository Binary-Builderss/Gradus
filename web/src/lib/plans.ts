import { z } from 'zod'

const httpsUrl = z.url().refine((u) => u.startsWith('https://'))

/**
 * Indirizzo dove si acquista l'abbonamento Pro (per esempio un link di pagamento): variabile pubblica
 * `VITE_PRO_CHECKOUT_URL`. Finché non è impostata, o se non è un https valido, il pulsante resta «Presto disponibile».
 */
export function proCheckoutUrl(raw: unknown = import.meta.env.VITE_PRO_CHECKOUT_URL): string | null {
  const parsed = httpsUrl.safeParse(raw)
  return parsed.success ? parsed.data : null
}
