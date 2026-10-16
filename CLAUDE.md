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
| Link ai video degli esercizi (`exercise_videos`, nessuno di default) | coach (web), ognuno i propri | i suoi atleti |
| Marchio del coach (logo, nome, colori) | coach dal piano basic (web) | atleta collegato, solo se il coach ha la personalizzazione |
| Piano del coach (`coach_plans`) | solo service_role / SQL | il coach, il proprio |
| Sedute, serie, segmenti, feedback per muscolo | atleta (iOS) | coach |
| Check giornalieri, questionari compilati, misure, foto, massimali | atleta (iOS) | coach |
| Obiettivi nutrizionali (oggi i macro; domani la dieta) | coach, o professionista verificato per la dieta (web) | atleta, sola lettura |
| Aderenza giornaliera ai macro e macro assunti | atleta (iOS) | coach |

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
  Passaggi ammessi (trigger `check_mesocycle_status_change`): `draft → active` solo se ha almeno una prescrizione e l'atleta
  non ne ha già un altro attivo; `active → completed` sempre; `active → draft` solo senza sedute registrate; tutto
  il resto no. Si elimina fisicamente solo una bozza. Lo fa il coach (anche per sé stesso), mai l'atleta.
  È sempre una **copia** del template o del mesociclo clonato, mai un riferimento.
- Le righe di esecuzione esistono solo se contengono dati reali. Chiavi naturali uniche
  (`workout_id, block_id, set_idx`; `set_log_id, seg_idx`) → scritture come upsert idempotenti.
- Volume per muscolo = Σ serie × `exercise_muscles.weight` (0..1): sempre dalle sessioni reali di ogni
  settimana, mai da un numero dichiarato; nessuna settimana oltre quelle del mesociclo.

## Logica condivisa

- La logica usata da entrambi i client sta in Postgres (funzioni `security invoker` + viste), con test pgTAP.
- **Tre sole duplicazioni ammesse**, perché servono offline sul telefono:
  1. riferimento alla settimana precedente → casi in `/fixtures/previous_week_cases.json`;
  2. carico target del back-off → casi in `/fixtures/backoff_cases.json`;
  3. obiettivo di macro in vigore un giorno (il piano non eliminato con `valid_from` più recente già iniziato) → casi in
     `/fixtures/nutrition_target_cases.json`; funzione SQL `nutrition_target_on`.
  Funzione SQL e implementazione Swift passano gli stessi casi. Chi cambia una regola aggiorna la
  fixture e entrambe le implementazioni nello stesso commit.
- Regole del riferimento alla settimana precedente: solo dentro il mesociclo in corso; settimana 1 →
  nessun riferimento; stessa seduta, stesso blocco, stessa serie. Le settimane di scarico sono **escluse dalla
  ricerca**: si prende la prima settimana prima di N che non è di scarico (con N−1 normale è N−1). Se in quella
  settimana la seduta non ha dati (saltata) → nessun riferimento, non si risale oltre. Mai dati di un mesociclo
  precedente. La funzione SQL è `previous_week_reference(session_id, week)` (non prende un workout: prima della
  prima serie il workout di N non esiste, le righe di esecuzione ci sono solo con dati).
- Carico target del back-off: carico del top set × percentuale ÷ 100, arrotondato al **2,5 kg** più vicino (a metà si sale);
  funzione SQL `backoff_target_load(top_load_kg, ref_pct)`, indicazione mai scritta nei campi dell'atleta. Come top set si usa
  la serie registrata per ultima nel blocco di riferimento che ha un carico (primo segmento).
- Le fixture sono la fonte: `fixtures/previous_week_cases.json` e `backoff_cases.json` generano i test pgTAP
  (`node fixtures/generate-sql.mjs`, controllato in CI con `--check`) e lo legge direttamente il test Swift.
- Sforzo: BUF = ripetizioni di riserva (RIR), quindi RPE = 10 − BUF. Lo sforzo si salva comunque con la
  sua scala (`effort_value` + `effort_scale`).

## Piano, tetto di atleti, marchio e account

- `coach_plans`: nessuna riga = free. Nessun client scrive qui (solo service_role o SQL): per provare un piano si
  inserisce una riga al coach di prova. Piani, in inglese: **`free`, `basic`, `advanced`, `custom`**; un piano a
  pagamento con `pro_until` scaduto vale free. I tetti di ogni piano hanno **una sola fonte**: `private.plan_limit(piano,
  tipo)` (il client li legge da `plan_limits()` e `plan_usage()`, mai ricalcolati altrove).

  | Tetto | free | basic | advanced | custom |
  | --- | --- | --- | --- | --- |
  | Atleti | 20 | 50 | 100 | 500 |
  | Template mesociclo | 1 | 5 | 10 | 20 |
  | Progressioni salvate | 20 | 350 | 700 | 1400 |
  | Template sessione (non ancora costruiti) | 5 | 35 | 70 | 140 |
  | Schede dieta salvate (non ancora costruite) | 0 | 7 | 15 | 30 |
  | Snapshot dieta per atleta (non ancora costruiti) | 0 | 12 | 12 | 12 |

  Listino indicativo, senza incassi nel codice: basic 19,90 €, advanced 29,90 €, custom 129,90 € + IVA al mese. Il free è
  volutamente limitato, per spingere almeno al basic. I tetti li fanno rispettare i trigger del database (vale per ogni
  via di scrittura): `enforce_athlete_limit` (atleti: conta chi ha un collegamento `pending` o `active`, l'invito in
  attesa occupa il posto, non il collegamento con sé stesso né i chiusi) e `enforce_owner_limit` (template di mesociclo e
  progressioni: errori `mesocycle_templates_limit_reached` / `progression_presets_limit_reached`, con il tetto nel hint).
  Chi supera un tetto dopo un declassamento **tiene quello che ha** ma non ne aggiunge. Le Edge Function e il web non
  ricalcolano le regole: le leggono da `plan_usage()` (piano, tetti, uso, livello di personalizzazione).
- **Personalizzazione a livelli** (`private.branding_level`, esposto come `plan_usage().branding_level`): 0 nessuna
  (free) · 1 basic = logo, nome del marchio e un colore principale (`primary`) · 2 advanced = tavolozza completa · 3
  custom = tavolozza completa e PDF senza la dicitura «Creato con Gradus» (`coach_branding.hide_gradus_credit`). È
  l'unico posto che decide chi ha Personalizza e il PDF col marchio (ha sostituito `is_pro` / `has_pro_plan`). Il trigger
  `enforce_branding_level` fa rispettare i livelli su ogni scrittura (`branding_level_too_low`, hint `plan`, `palette` o
  `credit`); se il piano cambia tra due livelli a pagamento `prune_branding` ridimensiona il marchio (scendendo a free
  il marchio resta ma l'atleta non lo vede più).
- `coach_branding`: logo (PNG base64), colori `#RRGGBB` liberi con chiavi fisse (`primary`, `on_primary`,
  `background`, `foreground`, `surface`, `muted_foreground`, `border`), nome del marchio, dicitura. Lo scrive solo un
  coach dal livello 1; l'atleta collegato lo legge solo finché il coach ha il livello 1 o più. Chiavi assenti = colori
  standard di Gradus.
- **Account**: `profiles.disabled_at` = account disattivato, reversibile dalla persona (il web e l'app mostrano
  una schermata per riattivarlo; un coach disattivato non può invitare). La **cancellazione** è definitiva ed è
  la Edge Function `delete-account` (conferma con l'email scritta a mano): `prepare_account_deletion` (solo
  service_role) ritira gli esercizi del coach usati in qualche programma (senza proprietario e con `deleted_at`)
  e cancella le sedute registrate dalla persona; poi si elimina l'utente di Auth e il resto va in cascata. I
  mesocicli scritti da un coach restano agli atleti; quelli di un atleta se ne vanno con lui.
- **Abbonamento**: `coach_plans.cancel_at_period_end` + `pro_until` (fine del periodo pagato: il piano resta fino
  a quella data e poi `effective_plan` lo riporta a free da solo) e `billing_ref` (abbonamento presso il servizio di
  pagamento; null = piano assegnato a mano, senza addebiti). Li scrive solo il webhook del servizio di pagamento
  (service_role). `prepare_account_deletion` rifiuta (`subscription_active`) un account con `billing_ref` che si
  rinnova ancora: prima si disdice. Disdire non cancella nessun dato.
- Le funzioni a pagamento oggi: più atleti, più template e progressioni, PDF con marchio, Personalizza (a livelli) e
  colori dell'app atleta. Il sito del coach resta Gradus, uguale per tutti.

## Nutrizione: i macro oggi, la dieta domani

Dentro il perimetro **i macro** (obiettivi e aderenza). La **dieta compilabile** (rubrica alimenti, schede) non è
costruita, ma i dati sono già predisposti perché arrivi senza rifare niente.

- **Chi scrive cosa**: gli obiettivi li scrive il coach (o il professionista verificato) dal web; l'aderenza e i macro
  assunti li scrive l'atleta dall'app. Un solo autore per dato, come sempre.
- **Modello (migrazione `20261016130000_nutrition_macros.sql`)**:
  - `nutrition_plans`: atleta, autore (il coach collegato; `on delete set null`), `kind` (`macros` | `diet`),
    `valid_from` (vale da quel giorno finché non ne arriva uno più recente; un solo piano per atleta, tipo e giorno tra i
    non eliminati), `tolerance_pct` (0–50, default 10), `declared_at` e `declaration_version` obbligatori (la
    dichiarazione), `deleted_at`. Le righe di obiettivo sono in `nutrition_plan_days` (kcal, proteine, carboidrati,
    grassi, fibre facoltative). Per ora un solo obiettivo per giorno (`day_type = 'all'`, vincolo da togliere quando si
    decide su allenamento / riposo). Solo l'autore modifica; l'atleta e i coach collegati leggono.
  - `nutrition_days`: per atleta e data (`unique (athlete_id, day)`), stato (`respected` | `not_respected`), fonte
    (`confirm` | `healthkit` | `manual`) e macro assunti (numerici, null se solo confermato; da Apple Salute o a mano
    serve almeno un numero). Nessuna riga = «non registrato». Id derivato dall'app (come per le serie): upsert
    idempotente. Li scrive solo l'atleta e solo con il consenso; niente cancellazioni fisiche dal client.
  - Consenso: `profiles.nutrition_consent_at` / `nutrition_consent_version` (lo scrive l'atleta sul suo profilo). Senza
    consenso l'atleta non scrive e il coach non legge i giorni; `withdraw_nutrition_consent()` cancella i giorni e
    azzera il consenso. Le righe dell'atleta vanno via con l'account (cascade).
  - Funzioni per i client: `nutrition_target_on(atleta, giorno)` (l'obiettivo in vigore) e
    `nutrition_overview(atleta, da, a)` (un giorno per riga con obiettivo e registrato, al massimo un anno). Il trigger
    `reject_unavailable_kind` rifiuta `kind = 'diet'` finché non esiste la verifica del professionista.
  - Per la dieta futura: tabelle di alimenti, pasti e voci collegate a un `nutrition_plans` con `kind = 'diet'`.
- **Verifica del professionista** (`professional_verifications`): professione (`physician` | `biologist_nutritionist`
  sezione A | `dietitian`), numero e ordine di iscrizione, certificato (storage privato), stato `pending` → `verified` /
  `rejected` / `revoked`, scadenza. Il coach scrive la richiesta; lo stato lo cambia **solo** service_role o SQL, a
  mano, dopo aver controllato l'albo (come `coach_plans`). `private.is_verified_professional(coach)` è l'unico posto
  che decide. L'atleta vede chi ha scritto la dieta e con quale iscrizione.
- **Chi può cosa**: i **macro** li può impostare ogni coach, ma con una dichiarazione esplicita («questi obiettivi mi
  sono stati forniti da un professionista abilitato», con data e versione del testo salvate sul piano). La **dieta**
  compilabile solo a un professionista verificato **e** da un piano `basic` in su, con i tetti per fascia. Il trigger sul
  database rifiuta `kind = 'diet'` a chi non è verificato (vale per ogni via di scrittura).
- **Aderenza (app)**: notifica locale la sera (default 22:00, modificabile) «Hai rispettato i macro di oggi?» con
  azioni Sì / No. Sì → giorno verde, senza numeri inventati. No → chiede se inserirli a mano; se sì si apre la
  schermata dei macro, altrimenti il giorno è «non rispettato». Se Apple Salute (HealthKit, sola lettura) ha già dati di
  alimentazione per quel giorno la notifica non parte: i totali arrivano come `healthkit` e si confrontano con
  l'obiettivo entro la tolleranza scelta dal coach. L'atleta può sempre correggere a mano, anche i giorni passati (per
  ora 14). Un giorno senza risposta resta «non registrato» e **non** conta come non rispettato.
- **Privacy**: dall'app escono solo i totali giornalieri, mai i singoli alimenti. iOS non dice se il permesso di
  lettura è stato negato: «nessun dato» e «negato» coincidono, quindi l'inserimento a mano c'è sempre. Servono il consenso
  esplicito e separato a condividere i dati nutrizionali con il coach, il testo della privacy aggiornato (anche per
  numero e certificato d'iscrizione dei professionisti) e le frasi di richiesta permessi. Apple vieta di usare questi
  dati per pubblicità. Alla cancellazione dell'account le righe scritte dall'atleta vanno cancellate
  (`prepare_account_deletion`).
- **Decisioni aperte**: giorni di allenamento / riposo con obiettivi diversi; tolleranza di default; quanti giorni si
  possono correggere; orario della notifica; collegare all'atleta un secondo professionista (nutrizionista) con il suo
  account verificato. Quanto alla legge italiana: prescrivere diete è riservato a figure abilitate; il testo dei termini e
  la dichiarazione sui macro vanno riletti da un legale prima del lancio.

## Sicurezza

- RLS attiva su ogni tabella, nessuna policy `using (true)`. Ogni policy ha test pgTAP con: coach
  collegato, coach non collegato, atleta proprietario, altro atleta.
- La `service_role` key vive solo nelle Edge Functions: mai nel web, mai nell'app iOS.

## Decisioni aperte (non anticiparle nel codice)

- Sono nel doc, sezione "Decisioni aperte".

## Fuori perimetro

Dieta compilabile (rubrica alimenti e schede: predisposta nel modello, non costruita), gamification, directory
pubblica dei professionisti, incassi e abbonamenti veri (esiste solo il piano in `coach_plans`, impostato a mano), chat
(fase successiva). I macro, invece, sono dentro (vedi «Nutrizione»).

## Prima di dichiarare finito

- `supabase test db` verde se è cambiato qualcosa in `/supabase`.
- I controlli della cartella toccata (vedi `web/CLAUDE.md` o `ios/CLAUDE.md`).
- Se è cambiata una regola condivisa: fixture + SQL + Swift aggiornati insieme.
