# Gradus

Gestionale di programmazione per l'ipertrofia.

- **Gradus** (`/web`): sito per il coach — atleti, editor dei mesocicli, librerie, monitoraggio.
- **Gradus Atleta** (`/ios`): app iPhone per l'atleta — esecuzione delle sedute, check, misure.
- **Supabase** (`/supabase`): schema, permessi (RLS), funzioni. È il contratto tra web e iOS.

Specifiche: doc "Specifiche – Gradus". Regole per Claude Code: `CLAUDE.md` alla radice + `web/CLAUDE.md` + `ios/CLAUDE.md`.

## Requisiti locali

| Strumento | Per | Installazione (macOS) |
| --- | --- | --- |
| Node.js 22 LTS | web | `brew install node@22` o [nodejs.org](https://nodejs.org) |
| Docker Desktop | Supabase in locale | [docker.com](https://www.docker.com/products/docker-desktop/) |
| Supabase CLI | migrazioni, stack locale | `brew install supabase/tap/supabase` |
| Xcode (ultima stabile) | iOS | Mac App Store |
| VS Code | web, Supabase | [code.visualstudio.com](https://code.visualstudio.com) |

## Avvio rapido (web)

```bash
supabase start                      # avvia Postgres, Auth, Studio in locale (serve Docker)
cd web
cp .env.example .env.local          # incolla API URL e anon key stampati da `supabase start`
npm install
npm run dev                         # http://localhost:5173
```

Controlli: `npm run lint`, `npm run typecheck`, `npm test`, `npm run build`.

## Struttura

```
/supabase    migrazioni, funzioni, RLS, Edge Functions, test pgTAP
/web         SPA Vite + React + TypeScript
/ios         progetto Xcode
/fixtures    casi di test condivisi web/iOS
```

VS Code si apre sulla **radice** del repo; Xcode apre `ios/GradusAtleta.xcodeproj`.
