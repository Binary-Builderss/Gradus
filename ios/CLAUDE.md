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

## Architettura

```
App/            entry point, DI, routing
Features/       Workout, Exercise, Timer, Checks, Progress, Profile — View + ViewModel (@Observable)
Domain/         modelli e regole pure, senza I/O (stati, riferimento settimana precedente, back-off, timer)
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
- **Conflitti**: un solo autore per riga → vince l'`updated_at` più recente (iPhone + iPad).
- **Cancellazioni**: soft delete con `deleted_at`.
- L'app funziona interamente offline; lo stato di sincronizzazione è visibile nel Profilo.

## Schermata esercizio — regole (non negoziabili)

1. **Nessun precompilato.** Kg, reps e sforzo sono vuoti finché l'atleta non scrive. Niente valori
   grigi dentro i campi.
2. **Salvataggio automatico** a ogni modifica, nel DB locale (debounce massimo 300 ms durante la
   digitazione). Nessun pulsante Salva, nessun pulsante "Fatto".
3. Una serie esiste solo se contiene dati. Svuotare tutti i campi di una serie la cancella.
   `done_at` = orario dell'ultima modifica.
4. **Righe raggruppate per blocco** (es. "Top 1×5", "Back-off 2×7"). Con una tecnica a segmenti
   (drop, rest-pause, myo, cluster) ogni serie ha una riga kg × reps per segmento.
5. **Sforzo percepito**: facoltativo, una volta per serie (sull'ultimo segmento). Selettore sulla scala
   della prescrizione (BUF 0–5 o RPE 6–10, passo 0,5) o su quella preferita in Impostazioni.
   Se BUF = RIR resta da decidere: non convertire tra scale finché la decisione non è nel doc.
6. **Riferimento alla settimana precedente** nell'intestazione di ogni serie, come testo
   ("Sett. 3: 100 × 5 · BUF 1"; drop: "100 × 8 + 75 × 6"):
   - settimana 1 → nessun riferimento;
   - settimana N → stesso blocco, stessa sessione, settimana N−1 dello **stesso mesociclo**;
   - seduta saltata → settimana più recente dello stesso mesociclo, con etichetta (da confermare);
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
- **Profilo**: coach collegato, impostazioni (scala sforzo, suoni timer), stato sincronizzazione, logout.

## Test obbligatori

- `Domain/`: riferimento settimana precedente (tutti i casi di fixture), stati derivati, durata del
  timer per tipo di gruppo, carico back-off.
- Sync: upsert idempotente (stessa operazione inviata due volte), ordine della coda, ripresa dopo errore
  di rete.
- Timer: ricalcolo del residuo dopo background simulato.

## App Store

- Gli account atleta li crea il coach: per la revisione serve un account demo con un mesociclo attivo
  già assegnato, indicato nelle note per il revisore.
- Nessun acquisto in-app nell'app atleta.

## Cosa non fare

- Nessuna modifica della programmazione dal telefono.
- Nessuna nutrizione, gamification, chat (fase successiva).
- Non chiamare la rete dalle View; non bloccare la UI in attesa della sincronizzazione.
- Non reintrodurre precompilati o pulsanti di conferma della serie.
