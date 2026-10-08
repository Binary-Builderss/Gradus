# CLAUDE.md — Gradus, web coach (`/web` + `/supabase`)

Gestionale web per il **coach**: atleti, editor dei mesocicli, librerie, monitoraggio.
Regole di dominio, proprietà dei dati e logica condivisa sono nel `CLAUDE.md` alla radice: valgono anche qui.
Lo schema in `/supabase` è gestito da questa parte del progetto.

## Stack

- **SPA** Vite + React + TypeScript `strict`. Nessun rendering lato server: l'app è privata, dietro login,
  senza pagine da indicizzare.
- Routing: TanStack Router con route basate su file in `src/routes/` (`src/routeTree.gen.ts` è generato
  dal plugin Vite: non modificarlo a mano). Dati: TanStack Query sopra `supabase-js`.
- Il browser parla direttamente con Supabase usando la sola `anon` key; i permessi li fa RLS.
- Operazioni con privilegi (invito atleta via email, esportazione PDF): Supabase Edge Functions in
  `/supabase/functions`, mai nel client.
- UI: Tailwind + shadcn/ui. Drag and drop: dnd-kit.
- Griglia dell'editor: TanStack Table (headless, righe nel DOM per dnd-kit e Tailwind). Navigazione da
  tastiera e copia/incolla (TSV via `navigator.clipboard`) in un hook nostro, con test. Niente AG Grid
  (intervalli e incolla sono Enterprise) né Glide (canvas, incompatibile con dnd-kit).
- Validazione: zod sui form e sui payload delle Edge Functions.
- Lint: oxlint (`.oxlintrc.json`). Formattazione: Prettier (`.prettierrc.json`, plugin Tailwind).
- Test: Vitest + Testing Library (jsdom), Playwright (e2e, da aggiungere), pgTAP (RLS e funzioni SQL).
- Variabili d'ambiente validate con zod in `src/lib/env.ts`; client Supabase unico in `src/lib/supabase.ts`.
- Deploy: hosting statico (Netlify, Vercel o Cloudflare Pages) con fallback SPA su `index.html`.
- Codice in inglese; testi dell'interfaccia in italiano, in un unico file di messaggi.

## Comandi

```
supabase start                 # stack locale
supabase db reset              # migrazioni + seed
supabase test db               # pgTAP
supabase functions serve       # Edge Functions in locale
supabase gen types typescript --local > web/src/lib/database.types.ts
cd web && npm run dev | npm run build | npm run lint | npm run typecheck | npm test | npm run format
```

Prima di dichiarare finito: lint, typecheck, test unit verdi; `supabase test db` se è cambiato `/supabase`.
Dopo una migrazione: rigenera i tipi e indica nel commit quali modelli Swift vanno aggiornati in `/ios`.

## Funzioni SQL da mantenere

- `instantiate_template(template_id, athlete_id, start_date)`, `clone_mesocycle(mesocycle_id, start_date)` — copia profonda
- `generate_progression(block_id, rule jsonb)` — riempie `block_weeks` (es. BUF da 3 a 0, +1 serie a settimana)
- `weekly_muscle_volume(mesocycle_id)` — prescritto ed eseguito
- `previous_week_reference(workout_id)` — stessi casi di `/fixtures/previous_week_cases.json`
- `top_set_history(athlete_id, exercise_id)` — e1RM, attraversa i mesocicli (solo per il coach)

Ogni funzione ha test pgTAP con i casi limite: settimana 1, seduta saltata, scarico a metà, superset.

## Regole specifiche del web

- Un mesociclo `active` con serie registrate si modifica solo nelle settimane senza dati (proposta da
  confermare nel doc): l'interfaccia blocca le colonne delle settimane già eseguite.
- Salvataggio automatico nell'editor con stato visibile: salvato / in salvataggio / errore.
- Nessuna query senza filtro per atleta o coach: anche se RLS protegge, le query devono essere esplicite.

## Funzionalità (MVP = fase 1)

- **Atleti**: lista con stato collegamento, ultima seduta, aderenza 7 giorni; invito via email (Edge
  Function); chiusura collegamento; scheda atleta.
- **Editor mesociclo** (la parte più importante):
  - griglia blocchi × settimane navigabile da tastiera come un foglio di calcolo (frecce, Tab, Invio,
    copia/incolla di celle);
  - sessioni, gruppi e slot riordinabili con drag and drop; tipo di gruppo con i suoi recuperi;
  - "copia questa settimana sulle successive", "applica regola di progressione";
  - settimana di scarico marcata; anteprima "come la vede l'atleta".
- **Libreria esercizi**: catalogo globale + esercizi del coach, video, note, pesi per muscolo 0..1.
- **Monitoraggio seduta**: prescritto contro eseguito per serie, sforzo prescritto contro percepito.

Fasi successive (non implementare senza richiesta): template, questionari, volume per muscolo, misure e
foto, PDF, confronto tra mesocicli, chat, appuntamenti.

## Cosa non fare

- Nessuna interfaccia per l'atleta sul web.
- Niente Next.js, SSR o server applicativo proprio: client statico + Supabase + Edge Functions.
- Non duplicare in TypeScript la logica che sta nelle funzioni SQL.
- Niente `any`; non disattivare RLS "per testare"; nessuna chiave in variabili `VITE_*` oltre a URL e `anon`.
