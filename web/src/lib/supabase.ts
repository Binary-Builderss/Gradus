import { createClient } from '@supabase/supabase-js'
import type { Database } from './database.types'
import { parseEnv } from './env'

const env = parseEnv(import.meta.env)

// I tipi si rigenerano con `supabase gen types typescript --local > src/lib/database.types.ts`.
export const supabase = createClient<Database>(env.VITE_SUPABASE_URL, env.VITE_SUPABASE_ANON_KEY)
