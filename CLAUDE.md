# CLAUDE.md — Gradus (radice)

Gestionale di programmazione per l'ipertrofia: il **coach** scrive i mesocicli dal web, l'**atleta** li
esegue e registra dall'iPhone. Specifiche complete: doc "Specifiche – Gradus"
(https://claude.ai/code/artifact/7a997fe7-a7fe-4b32-9aea-579273e33fde). Se il codice, questi file e
il doc divergono, chiedi prima di procedere.

Nomi del prodotto: **Gradus** è il sito del coach, **Gradus Atleta** è l'app iOS sull'App Store; sotto
l'icona (`CFBundleDisplayName`) solo "Gradus", perché i nomi lunghi vengono troncati nella Home. Nel codice usa `Gradus` come prefisso o namespace solo dove serve,
non nei nomi delle tabelle.

Questo file vale per tutto il repo. Le regole specifiche stanno in `web/CLAUDE.md` (stack web) e
`ios/CLAUDE.md` (stack iOS).

## Repo

```
/supabase    migrazioni SQL, funzioni, policy RLS, Edge Functions, seed, test pgTAP  ← contratto
/web         gestionale coach — SPA Vite + React + TypeScript (VS Code)
/ios         app atleta — SwiftUI (Xcode)
/fixtures    casi di test condivisi web/iOS, in JSON
/brand       brand kit: marchio, logo, favicon, icona iOS (AppIcon.appiconset), anteprima social, palette
```

- Una modifica che tocca schema e client si fa in un solo commit: migrazione, tipi TypeScript
  rigenerati, modelli Swift aggiornati, test di entrambi i lati.
- Le migrazioni applicate non si modificano mai: se ne aggiunge una nuova.
- `.gitignore` alla radice: `node_modules`, `dist`, `.env*`, `xcuserdata`, `DerivedData`, `*.xcuserstate`.

## Proprietà dei dati (regola centrale)

Ogni dato ha un solo autore.

| Dato | Scrive | Legge |
| --- | --- | --- |
| Mesocicli, sessioni, gruppi, slot, blocchi, prescrizioni settimanali | coach (web) | atleta, sola lettura |
| Libreria esercizi, pesi per muscolo, template | coach (web) | atleta (nome, video, note) |
| Marchio del coach (logo, nome, colori) | coach pro (web) | atleta collegato, solo se il coach è pro |
| Piano del coach (`coach_plans`) | solo service_role / SQL | il coach, il proprio |
| Sedute, serie, segmenti, feedback per muscolo | atleta (iOS) | coach |
| Check giornalieri, questionari compilati, misure, foto, massimali | atleta (iOS) | coach |

Il web non scrive mai dati di esecuzione; l'app iOS non scrive mai la programmazione.

## Modello di dominio

Gerarchia: `mesocycles → sessions → slot_groups → slots → set_blocks → block_weeks`.
Esecuzione: `workouts → set_logs → set_segments`.

- **Gruppo** = esercizi diversi concatenati: `single | superset | giant | circuit | jumpset`, con
  `rest_between_s` e `rest_after_round_s`.
- **Blocco** = serie omogenee dello stesso esercizio: `warmup | top | backoff | working`. Più blocchi
  sullo stesso slot = multiset (es. top 1×5 + back-off 2×7).
- **Tecnica** = modifica di una singola serie: `none | drop | rest_pause | myo | cluster`, parametri in
  `technique_params` jsonb. Produce più **segmenti** (carico × reps) dentro una serie.
- **Prescrizione** per settimana (`block_weeks`): serie, range reps, metodo `BUF | RPE | RM | PCT_1RM | LOAD`
  e valore; back-off legato con `ref_block_id` + `ref_pct`.
- **Mesociclo**: `draft → active → completed`, un solo `active` per atleta, l'atleta non vede i `draft`.
  È sempre una **copia** del template o del mesociclo clonato, mai un riferimento.
- Le righe di esecuzione esistono solo se contengono dati reali. Chiavi naturali uniche
  (`workout_id, block_id, set_idx`; `set_log_id, seg_idx`) → scritture come upsert idempotenti.
- Volume per muscolo = Σ serie × `exercise_muscles.weight` (0..1): sempre dalle sessioni reali di ogni
  settimana, mai da un numero dichiarato; nessuna settimana oltre quelle del mesociclo.

## Logica condivisa

- La logica usata da entrambi i client sta in Postgres (funzioni `security invoker` + viste), con test pgTAP.
- **Due sole duplicazioni ammesse**, perché servono offline sul telefono:
  1. riferimento alla settimana precedente → casi in `/fixtures/previous_week_cases.json`;
  2. carico target del back-off → casi in `/fixtures/backoff_cases.json`.
  Funzione SQL e implementazione Swift passano gli stessi casi. Chi cambia una regola aggiorna la
  fixture e entrambe le implementazioni nello stesso commit.
- Regole del riferimento alla settimana precedente: solo dentro il mesociclo in corso; settimana 1 →
  nessun riferimento; seduta saltata in N−1 (nessun dato registrato) → nessun riferimento; settimane di
  scarico escluse; mai dati di un mesociclo precedente.
- Sforzo: BUF = ripetizioni di riserva (RIR), quindi RPE = 10 − BUF. Lo sforzo si salva comunque con la
  sua scala (`effort_value` + `effort_scale`).

## Piano, tetto di atleti, marchio e account

- `coach_plans`: nessuna riga = gratuito. Nessun client scrive qui (solo service_role o SQL): per provare un
  piano si inserisce una riga al coach di prova. Livelli e tetto di atleti: **free 20, mid 60, pro 100,
  unlimited nessun tetto**; un piano a pagamento con `pro_until` scaduto vale free. Conta chi ha un
  collegamento `pending` o `active` (l'invito in attesa occupa il posto), non quello con sé stesso né i chiusi.
  Il tetto lo fa rispettare il trigger `enforce_athlete_limit` (vale per ogni via di scrittura); chi lo supera
  dopo un declassamento tiene gli atleti ma non ne aggiunge. `plan_usage()` dà piano, tetto e atleti al client.
  Le Edge Function e il web non ricalcolano le regole: le leggono da lì.
- `private.is_pro` = pro **e unlimited** (non mid): è l'unico posto che decide chi ha Personalizza e il PDF col
  marchio. `has_pro_plan()` lo espone al client.
- `coach_branding`: logo (PNG base64), colori `#RRGGBB` liberi con chiavi fisse (`primary`, `on_primary`,
  `background`, `foreground`, `surface`, `muted_foreground`, `border`), nome del marchio. Lo scrive solo un coach
  pro in su; l'atleta collegato lo legge solo finché il coach è pro. Chiavi assenti = colori standard di Gradus.
- **Account**: `profiles.disabled_at` = account disattivato, reversibile dalla persona (il web e l'app mostrano
  una schermata per riattivarlo; un coach disattivato non può invitare). La **cancellazione** è definitiva ed è
  la Edge Function `delete-account` (conferma con l'email scritta a mano): `prepare_account_deletion` (solo
  service_role) ritira gli esercizi del coach usati in qualche programma (senza proprietario e con `deleted_at`)
  e cancella le sedute registrate dalla persona; poi si elimina l'utente di Auth e il resto va in cascata. I
  mesocicli scritti da un coach restano agli atleti; quelli di un atleta se ne vanno con lui.
- Le funzioni a pagamento oggi: PDF con marchio, Personalizza e colori dell'app atleta. Il sito del coach resta
  Gradus, uguale per tutti.

## Sicurezza

- RLS attiva su ogni tabella, nessuna policy `using (true)`. Ogni policy ha test pgTAP con: coach
  collegato, coach non collegato, atleta proprietario, altro atleta.
- La `service_role` key vive solo nelle Edge Functions: mai nel web, mai nell'app iOS.

## Decisioni aperte (non anticiparle nel codice)

- Sono nel doc, sezione "Decisioni aperte".

## Fuori perimetro

Nutrizione, gamification, directory pubblica dei professionisti, incassi e abbonamenti veri (esiste solo il
piano `free` / `pro` in `coach_plans`, impostato a mano), chat (fase successiva).

## Prima di dichiarare finito

- `supabase test db` verde se è cambiato qualcosa in `/supabase`.
- I controlli della cartella toccata (vedi `web/CLAUDE.md` o `ios/CLAUDE.md`).
- Se è cambiata una regola condivisa: fixture + SQL + Swift aggiornati insieme.
