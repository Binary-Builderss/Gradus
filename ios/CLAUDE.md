# CLAUDE.md — Gradus Atleta, app iOS (`/ios`)

App iPhone per l'**atleta**: esegue i mesocicli scritti dal coach sul web e registra serie, check
giornalieri, misure. Regole di dominio, proprietà dei dati e logica condivisa sono nel `CLAUDE.md` alla
radice: valgono anche qui. Il progetto si apre in Xcode da `ios/`; Claude Code va lanciato dalla radice
quando un task tocca anche `/supabase` o `/fixtures`.

## Stack

- SwiftUI, iOS 17+ (Observation `@Observable`), Swift con strict concurrency `complete`.
- Persistenza locale: GRDB (SQLite). Il database locale è la fonte di verità per la UI.
- Backend: Supabase (`supabase-swift`) per Auth e REST. Lo schema sta in `/supabase` ed è gestito dal web:
  l'app non crea né modifica tabelle remote.
- Notifiche locali: UserNotifications. Live Activity / Dynamic Island: ActivityKit (fase 2).
- Test: Swift Testing / XCTest. UI test solo per i flussi principali.
- Codice in inglese; testi in italiano in `Localizable.xcstrings`.

## Progetto e comandi

- `ios/project.yml` (XcodeGen) genera `ios/Gradus.xcodeproj`, che è nel repo: `cd ios && xcodegen generate` se cambia il
  file. Bundle id `dev.binarybuilders.gradus` (da cambiare in `project.yml` se serve un altro).
- **Firma e chiavi**: stanno in `Config/Secrets.xcconfig` (ignorato da git; modello in `Secrets.example.xcconfig`):
  `SUPABASE_URL`, `SUPABASE_ANON_KEY` (publishable) e `DEVELOPMENT_TEAM`. Il team non va scritto nel `.xcodeproj` né in
  `project.yml`: il progetto si rigenera con XcodeGen e il team andrebbe perso a ogni modifica. Non committare i
  cambiamenti che Xcode fa da solo a `project.pbxproj` e `Localizable.xcstrings` se non vengono da `project.yml`.
- `ios/Domain` è un pacchetto Swift locale con le regole pure: `cd ios/Domain && swift test` (senza simulatore, legge
  `/fixtures`). L'app lo importa con `import Domain`.
- App e test: `xcodebuild test -project Gradus.xcodeproj -scheme Gradus -destination 'platform=iOS Simulator,id=<id>'`
  (gli id con `xcodebuild -showdestinations`); aggiungi `CODE_SIGNING_ALLOWED=NO` da terminale.
- `Tests/LiveSyncTests.swift` prova accesso e sincronizzazione contro il Supabase LOCALE vero (RLS compresa) e si salta
  da solo. Per lanciarla: `supabase start && python3 ios/Scripts/seed_local.py`, poi davanti a `xcodebuild` metti
  `TEST_RUNNER_GRADUS_LIVE_KEY=<PUBLISHABLE_KEY di supabase status -o env>`. Senza firma il portachiavi del simulatore
  non c'è: la prova usa un archivio in memoria.

## Architettura

```
App/            entry point, DI, routing
Features/       Workout, Exercise, Timer, Checks, Progress, Profile — View + ViewModel (@Observable)
Domain/         pacchetto Swift locale: modelli e regole pure, senza I/O (stati, riferimento settimana precedente, back-off, timer)
Data/Local/     GRDB: migrazioni locali, record, repository
Data/Sync/      SyncEngine: pull incrementale + coda di push
Data/Remote/    client Supabase
```

- Le View leggono solo dai repository locali (GRDB `ValueObservation`), mai direttamente dalla rete.
- Le regole di dominio sono funzioni pure in `Domain/`, testate senza database.

## Dati sul telefono

- Programmazione in sola lettura (nessuna UI per modificarla); scritture solo sulle tabelle dell'atleta
  elencate nel `CLAUDE.md` alla radice.
- I mesocicli `completed` si consultano in sola lettura; i `draft` non arrivano mai sul telefono.
- Modelli Swift allineati a `/supabase/migrations`: dopo una migrazione aggiorna record GRDB e mapping.

## Sincronizzazione

- **Pull**: per tabella, incrementale su `updated_at > ultimo cursore`; all'avvio, al ritorno in
  foreground, con pull-to-refresh.
- **Push**: ogni scrittura locale accoda un'operazione; la coda invia upsert sulle chiavi naturali
  (`workout_id, block_id, set_idx` per `set_logs`; `set_log_id, seg_idx` per `set_segments`;
  `athlete_id, date, slot` per `daily_checks`). Reinviare non deve creare duplicati.
- **Id derivati**: `workouts`, `set_logs` e `set_segments` hanno l'id calcolato dalla chiave naturale (UUID v5,
  `Domain/DeterministicID`): stesso dato = stesso id su ogni telefono e a ogni reinstallazione, quindi l'upsert è sulla
  chiave primaria e non nascono righe doppie. Non cambiare il namespace né le stringhe da cui si calcola.
- **Coda**: tabella locale `pending_push (tabella, id, versione)`; l'invio avviene in ordine di chiavi esterne (seduta →
  serie → segmenti) e una riga esce dalla coda solo se la versione non è cambiata mentre si inviava. Ogni sincronizzazione
  prima legge, poi invia; il pull non sovrascrive le righe ancora in coda. Lo svuotamento di una serie è un soft delete.
- **Conflitti**: un solo autore per riga → vince l'`updated_at` più recente (iPhone + iPad).
- **Cancellazioni**: soft delete con `deleted_at`.
- L'app funziona interamente offline; lo stato di sincronizzazione è visibile nel Profilo.

## Schermata esercizio — regole (non negoziabili)

0. **Le righe sono le serie prescritte** dal coach per quella settimana: l'atleta non ne aggiunge (se un blocco non ha
   prescrizione c'è una riga sola; le serie già registrate oltre il prescritto restano visibili).
1. **Nessun precompilato.** Kg, reps e sforzo sono vuoti finché l'atleta non scrive. Niente valori
   grigi dentro i campi.
2. **Salvataggio automatico** a ogni modifica, nel DB locale (debounce massimo 300 ms durante la
   digitazione). Nessun pulsante Salva, nessun pulsante "Fatto".
3. Una serie esiste solo se contiene dati. Svuotare tutti i campi di una serie la cancella.
   `done_at` = orario dell'ultima modifica.
4. **Righe raggruppate per blocco** (es. "Top 1×5", "Back-off 2×7"). Con una tecnica a segmenti
   (drop, rest-pause, myo, cluster) ogni serie ha una riga kg × reps per segmento.
5. **Sforzo percepito**: facoltativo, una volta per serie. Una riga di tasti interi sotto i campi (BUF 0–5 o RPE 6–10);
   un tocco sceglie, un secondo tocco toglie, il mezzo punto (2,5) con il tocco lungo. La scala è quella della
   prescrizione del coach (RPE se la scrive RPE; altrimenti BUF, ripetizioni in riserva): non c'è una scelta
   dell'atleta. BUF = RIR (RPE = 10 − BUF); lo sforzo si salva nella scala in cui è stato inserito.
6. **Riferimento alla settimana precedente** nell'intestazione di ogni serie, come testo
   ("Sett. 3: 100 × 5 · BUF 1"; drop: "100 × 8 + 75 × 6"):
   - settimana 1 → nessun riferimento;
   - settimana N → stesso blocco, stessa sessione, settimana N−1 dello **stesso mesociclo**;
   - seduta saltata (nessun dato in N−1) → nessun riferimento;
   - settimane di scarico escluse; **mai** dati di un mesociclo precedente.
   Implementazione in `Domain/`, verificata con `/fixtures/previous_week_cases.json` (stessi casi
   della funzione SQL lato web).
7. **Back-off legato**: mostra il carico target ("≈ 90 kg") nel riquadro prescrizione appena il blocco
   di riferimento ha dati. Formula e arrotondamento da `/fixtures/backoff_cases.json`. È un'indicazione,
   mai un valore inserito nei campi.
8. **Stati derivati**: esercizio vuoto / parziale / completo confrontando serie registrate e prescritte;
   seduta iniziata alla prima serie, finita all'ultima. Nessun "termina allenamento".

## Timer di recupero

- **Unico pulsante** della schermata: "Avvia timer". Non salva né conferma niente; su una serie vuota
  la serie resta vuota.
- Durata: `rest_s` del blocco; nei gruppi `rest_between_s` o, sull'ultimo esercizio del giro,
  `rest_after_round_s`. Se la durata è 0 il pulsante non compare. Nessun pulsante sull'ultima serie
  della seduta.
- Dopo l'avvio: scorri alla serie successiva o all'esercizio successivo del gruppo.
- Barra fissa in basso: tempo residuo, +15 s, −15 s, Salta. Alla fine: vibrazione + suono
  (configurabili).
- **Persisti l'orario di fine**, non un contatore: il timer deve sopravvivere a background, blocco
  schermo, chiusura e riavvio dell'app.
- Programma una notifica locale all'orario di fine; annullala o riprogrammala su Salta / ±15 s / nuovo avvio.
- Un solo timer attivo; un nuovo avvio sostituisce il precedente.
- Fase 2: Live Activity con `Text(timerInterval:)`, nessun aggiornamento push necessario.
- Fuori MVP: timer di esecuzione con PREP e cadenza vocale del TUT.

## Altre schermate

- **Allenamento (home)**: mesociclo attivo, selettore settimana × sessione aperto sulla prossima seduta
  non completata, note del coach, lista gruppi con riepilogo compatto e stato; storico mesocicli.
- **Check** (fase 2): check giornaliero mattina/sera, feedback per muscolo a fine seduta, questionari.
- **Progressi** (fase 3): misure, pliche, circonferenze, foto (Storage privato), grafico carichi.
- **Coach che si segue da solo**: lo stesso account può essere coach e atleta (collegamento con sé stesso, vedi la
  radice): se l'utente ha programmi come atleta, l'app mostra la vista atleta come per chiunque; niente seconda
  email né secondo account.
- **Nome**: se il profilo arrivato sul telefono non ha il nome, al primo accesso compare «Come ti chiami?» (si può
  rimandare; senza rete non si dà per salvato). Dal Profilo si cambia in ogni momento.
- **Profilo**: elenco di sezioni, ognuna in una schermata sua: **Account** (nome modificabile, email, coach, cambio
  password via email con link al sito), **Preferenze** (suono e vibrazione del timer), **Sincronizzazione** (stato, serie
  da inviare), **Assistenza e informazioni** (contatto, termini, privacy, versione). In fondo: **Disattiva o elimina
  l'account** (disattivare è reversibile, eliminare è definitivo e chiede l'email scritta a mano: Edge Function
  `delete-account`, come sul sito) ed **Esci** (prima invia le serie in coda). Il nome si chiede al primo
  accesso se manca.

## Test obbligatori

- `Domain/`: riferimento settimana precedente (tutti i casi di fixture), stati derivati, durata del
  timer per tipo di gruppo, carico back-off.
- Sync: upsert idempotente (stessa operazione inviata due volte), ordine della coda, ripresa dopo errore
  di rete.
- Timer: ricalcolo del residuo dopo background simulato.

## App Store

- Gli account atleta li crea il coach: per la revisione serve un account demo con un mesociclo attivo
  già assegnato, indicato nelle note per il revisore. Lo crea `Scripts/seed_review.py` (lo lanci tu contro il
  progetto online con `SUPABASE_SERVICE_ROLE_KEY` e `REVIEW_PASSWORD` come variabili d'ambiente; non salva né stampa
  chiave e password): coach e atleta `demo.*@binarybuilders.dev`, mesociclo di 8 settimane con la settimana 1 già
  registrata (si vedono subito riferimento e back-off). Rilancialo poco prima di ogni invio in revisione: riporta il
  mesociclo alla settimana 2. Scrivi la password nelle note per il revisore su App Store Connect.
- Eliminazione dell'account: l'app non crea account (arrivano dagli inviti), ma se la revisione la chiede c'è la Edge
  Function `delete-account` pronta da collegare al Profilo.
- Nessun acquisto in-app nell'app atleta.

## Cosa non fare

- Nessuna modifica della programmazione dal telefono.
- Nessuna nutrizione, gamification, chat (fase successiva).
- Non chiamare la rete dalle View; non bloccare la UI in attesa della sincronizzazione.
- Non reintrodurre precompilati o pulsanti di conferma della serie.
