import { z } from 'zod'

const envSchema = z.object({
  VITE_SUPABASE_URL: z.url(),
  VITE_SUPABASE_ANON_KEY: z.string().min(1),
})

export type Env = z.infer<typeof envSchema>

/** Valida le variabili d'ambiente pubbliche. Solo URL e anon key: mai la service_role. */
export function parseEnv(source: Record<string, unknown>): Env {
  const result = envSchema.safeParse(source)
  if (!result.success) {
    const missing = result.error.issues.map((issue) => issue.path.join('.')).join(', ')
    throw new Error(`Variabili d'ambiente mancanti o non valide: ${missing}. Vedi web/.env.example.`)
  }
  return result.data
}
