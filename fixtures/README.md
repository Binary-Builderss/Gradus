# Fixtures condivise

Casi di test usati **sia** dai test pgTAP / Vitest **sia** dai test Swift. Chi cambia una regola aggiorna
qui i casi e poi entrambe le implementazioni, nello stesso commit.

| File | Regola | Stato |
| --- | --- | --- |
| `previous_week_cases.json` | Riferimento alla settimana precedente | 16 casi, passano SQL e Swift |
| `backoff_cases.json` | Carico target del back-off da un top set (arrotondato al 2,5 kg, a metà si sale) | 13 casi, passano SQL e Swift |

Formato di ogni caso: `{ "name": "...", "input": { ... }, "expected": ... }`.

## Come si usano

- **SQL**: `node fixtures/generate-sql.mjs` scrive `supabase/tests/previous_week_fixtures.test.sql` e `backoff_fixtures.test.sql` (pgTAP) dai casi. Non
  si modifica a mano; la CI lancia `node fixtures/generate-sql.mjs --check` e fallisce se non è aggiornato.
- **Swift**: `PreviousWeekFixtureTests.swift` e `BackOffFixtureTests.swift` in `ios/Domain/Tests/DomainTests` leggono il JSON direttamente (`swift test`).
- Chi cambia una regola aggiorna il JSON, rigenera il test SQL e adegua SQL e Swift nello stesso commit.

### `previous_week_cases.json`

`input`: `weeks`, `deload_weeks`, `blocks` (nomi, nell'ordine della seduta), `week` (la settimana in cui si guarda), `logs`
(serie registrate nella seduta: `week`, `block`, `set_idx`, `segments` con `load_kg` e `reps`, `effort` con `value` e
`scale` o null). Facoltativi: `other_session_logs` (un'altra seduta dello stesso mesociclo) e `previous_mesocycle_logs`
(un mesociclo concluso dello stesso atleta): non devono mai comparire nel risultato. `expected`: le serie di riferimento,
nell'ordine dei blocchi e poi per `set_idx`, con la `week` da cui vengono.

### `backoff_cases.json`

`input`: `top_load_kg` e `ref_pct`; `expected`: `target_kg`. La formula è carico × percentuale ÷ 100 arrotondato al 2,5 kg
più vicino (`rounding_step_kg`), a metà si sale (come `round` di Postgres). Quale serie del blocco di riferimento fa da
top set non è nella fixture: lo decide `BackOff.referenceLoad` (ultima serie registrata con un carico, primo segmento).
