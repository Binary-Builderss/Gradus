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
- Anteprima del link e SEO: titolo, descrizione, Open Graph e Twitter card sono in `index.html` (statici, perché
  WhatsApp, Telegram, Slack e iMessage non eseguono JavaScript), con l'immagine `public/gradus-open-graph-1200x630.png`.
  Gli indirizzi sono assoluti con il dominio di produzione: se cambia, si cambia in `index.html` (canonical, `og:url`,
  immagini). `src/seo.test.ts` controlla che i tag ci siano e coerenti.
- Deploy: Cloudflare Pages (progetto `gradus`, ramo `prod`, cartella `web`, comando `npm run build`, uscita `dist`;
  variabili `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` nelle impostazioni del progetto). Il fallback SPA su
  `index.html` lo fa Pages da solo (non aggiungere un `404.html`); le intestazioni di sicurezza stanno in
  `web/public/_headers`.
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

## Interfaccia

- Linguaggio **strumento di lavoro, chiaro prima che denso** (riferimenti: Linear, Notion): il coach usa la griglia
  per ore. Prima di ogni lavoro di UI carica la skill `design-taste-frontend` (tasteskill).
- Identità: il brand kit sta in `/brand` (marchio, logo, favicon, icona iOS, anteprima social) ed è la fonte
  dei colori: blu `#0D54F3`, ink `#1E2630`, fondo `#F7F8FA`. I token di `src/index.css` e `STANDARD_COLORS` in
  `lib/brand.ts` derivano da lì: se cambia il kit, si cambiano insieme. Il marchio (`Mark`) e il logo
  (`Wordmark`) stanno in `components/brand.tsx`.
- Colori solo dai token in `src/index.css`: grigi tinti di blu e **un solo accento**, il blu del brand `#0D54F3` (`primary`; nel tema scuro la stessa tinta schiarita),
  usato per azioni e stato attivo. Il tema segue il sistema (chiaro / scuro): ogni schermata va controllata
  in entrambi.
- Unico colore di stato oltre all'accento: l'ambra (`warning`) per le settimane di scarico. Le settimane già
  eseguite si distinguono con le righe oblique (`bg-hatch`), mai con un altro colore.
- Nella griglia dell'editor la colonna e la riga della cella attiva restano evidenziate, e sopra la griglia
  una barra dice sempre quale esercizio, blocco e settimana stai modificando e, a parole, cosa hai prescritto
  («3 serie da 8-10 ripetizioni, 2 ripetizioni in riserva»).
- Ogni settimana ha tre campi visibili (serie, ripetizioni, sforzo): niente sigle da imparare né sintassi da
  digitare. Il menu sotto il nome dell'esercizio sceglie come si misura lo sforzo.
- Tipografia: Geist per il testo (radice 17 px, quindi testo base ≈ 15 px e controlli ≈ 34 px; mai testo sotto i 12 px; non mettere `text-sm` o `text-xs` su `html`, cambierebbe il valore di tutti i rem), Geist Mono per numeri e celle della griglia. Titoli in
  semibold, mai maiuscoli.
- Forma: raggio 6 px ovunque, controlli da 2 rem, liste e tabelle con righe divise invece di card
  annidate.
- Icone: solo Phosphor (`@phosphor-icons/react`). Componenti shadcn/ui in `src/components/ui`, mai lasciati
  allo stato di default.
- Menu laterale (`components/layout/Sidebar.tsx`): in alto il marchio, al centro le sezioni di lavoro (Atleti,
  Esercizi), in basso la Guida e **il menu dell'account** (`AccountMenu`: nome, email e piano, Profilo, Personalizza, Piano e abbonamento,
  Esci). Profilo, Personalizza e Piano sono pagine diverse: il Profilo è la persona (nome, email, password e,
  più avanti, eliminazione dell'account), Personalizza è il marchio (solo piano Pro, bloccata per gli altri),
  Piano e abbonamento confronta Gratuito e Pro. Sotto la Guida, a chi non ha il Pro, compare «Passa a Pro». Si comprime a una barra di
  sole icone che tiene il marchio (scelta in localStorage); da compresso ogni voce ha l'etichetta al passaggio
  del mouse e il nome accessibile. Su telefono lo stesso menu è l'avatar nell'header. Una sezione di lavoro
  nuova va nel blocco centrale. Le righe con testo lungo (nome, email) vanno sempre con `min-w-0` + `truncate`.
- Ogni stringa visibile sta in `src/lib/messages.ts`.
- Semplicità prima della densità: un dato ha **una sola vista** (la griglia della seduta, non anche un
  elenco degli stessi esercizi); le opzioni avanzate stanno in `Collapsible` (`<details>`, chiusi di
  default); una seduta alla volta (schede); ogni schermata vuota spiega cosa fare e offre l'azione.
- Vocabolario da coach: nell'interfaccia non compaiono i nomi del modello dati (gruppo, slot, blocco).
  Si dice "serie", "tipo di serie", "ordine e superset".
- **Guida a passi** (driver.js, pulsante "Guida" nella barra laterale): il percorso è in `src/lib/tourPlan.ts`,
  i testi in `messages.app.tour`, gli elementi evidenziati hanno `data-tour="..."`. Una pagina o un'azione
  principale nuova va aggiunta alla guida nello stesso commit. La guida non deve mai modificare dati.

- **Piani** (`/piani`): Gratuito, Mid, Pro e Unlimited a confronto, con i posti usati (`plan_usage`) e i tetti letti
  da `plan_limits` (i numeri stanno solo nel database). L'acquisto di ogni piano è un link https in
  `VITE_CHECKOUT_URL_MID` / `_PRO` / `_UNLIMITED` (facoltative): finché manca il pulsante resta «Presto
  disponibile». Nessun incasso nel codice. Sotto la Guida compare «Passa a Pro» a chi è free o mid e «Più
  atleti» al Pro con i posti quasi finiti (`upgradeHint` in `lib/plans.ts`); a tetto raggiunto l'invito di
  nuovi atleti è spento con il rimando ai piani (il blocco vero è il trigger del database).
- **Profilo, account**: Disattiva (reversibile: al posto dell'app si vede solo la schermata per riattivare o
  uscire) ed Elimina (definitivo, con le conseguenze elencate e l'email da scrivere a mano; Edge Function
  `delete-account`).

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
  - scheda **Riepilogo** accanto alla programmazione: serie per seduta e settimana, progressi per esercizio
    (miglior serie e massimale stimato, funzione SQL `weekly_exercise_progress`), volume per muscolo (funzione
    SQL `weekly_muscle_volume`, riscaldamento escluso) con le serie già eseguite sotto.
  - nella pagina dell'atleta, sopra l'elenco dei mesocicli, il colpo d'occhio sul mesociclo attivo: settimana
    in corso, sedute eseguite su previste, ultima seduta.
- **PDF della programmazione** (pulsante «Scarica PDF» nella pagina del mesociclo): generato nel browser con
  jsPDF + autotable, caricati solo al clic. Una pagina A4 orizzontale per seduta, una colonna per settimana.
  Stile Gradus per tutti; con piano Pro usa colori, logo e nome del marchio e un logo-filigrana sbiadito
  (`lib/pdfModel.ts` costruisce i dati, `lib/programPdf.ts` li disegna). Non serve una Edge Function: non ci sono
  privilegi in gioco, i dati sono già visibili al coach per RLS.
- **Profilo** (pagina `/profilo`, dal menu dell'account; nome e cambio password via email): nome e cognome del coach (`profiles.full_name`, scritto solo da lui: ogni dato ha un
  solo autore). Compare nella barra laterale, nel PDF (se non c'è un nome del marchio) e nella lista atleti del
  coach; senza nome si vede l'email. L'invito può portare un nome facoltativo, che entra nel profilo solo se
  l'atleta è nuovo; poi lo cambia lui dall'app.
- **Personalizza** (`/personalizza`, piano pro, `coach_branding`): nome, logo (ridimensionato nel browser e salvato come
  PNG base64) e sette colori liberi con anteprima; i colori non cambiati restano quelli standard
  (`STANDARD_COLORS` in `lib/brand.ts`, da tenere allineati ai token di `index.css`). Chi non è pro vede la
  pagina bloccata. Il sito del coach non cambia colori: il marchio vale per PDF e app atleta.
- **Libreria esercizi**: catalogo globale + esercizi del coach, video, note, pesi per muscolo 0..1.
- **Monitoraggio seduta**: prescritto contro eseguito per serie, sforzo prescritto contro percepito.

Fasi successive (non implementare senza richiesta): template, questionari, misure e
foto, PDF, confronto tra mesocicli, chat, appuntamenti.

## Cosa non fare

- Nessuna interfaccia per l'atleta sul web.
- Niente Next.js, SSR o server applicativo proprio: client statico + Supabase + Edge Functions.
- Non duplicare in TypeScript la logica che sta nelle funzioni SQL.
- Niente `any`; non disattivare RLS "per testare"; nessuna chiave in variabili `VITE_*` oltre a URL e `anon`.
