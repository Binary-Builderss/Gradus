# Fixtures condivise

Casi di test usati **sia** dai test pgTAP / Vitest **sia** dai test Swift. Chi cambia una regola aggiorna
qui i casi e poi entrambe le implementazioni, nello stesso commit.

| File | Regola | Stato |
| --- | --- | --- |
| `previous_week_cases.json` | Riferimento alla settimana precedente | Da scrivere con lo schema |
| `backoff_cases.json` | Carico target del back-off da un top set | In attesa della regola di arrotondamento |

Formato di ogni caso: `{ "name": "...", "input": { ... }, "expected": ... }`.
