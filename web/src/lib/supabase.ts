import { createClient } from '@supabase/supabase-js'
import { parseEnv } from './env'

const env = parseEnv(import.meta.env)

// I tipi del database si generano con `supabase gen types typescript --local > src/lib/database.types.ts`
// e si passano qui come createClient<Database>(...) appena esiste la prima migrazione.
export const supabase = createClient(env.VITE_SUPABASE_URL, env.VITE_SUPABASE_ANON_KEY)
