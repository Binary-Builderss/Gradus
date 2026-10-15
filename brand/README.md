# GRADUS — Brand Asset Kit

Identità basata sul monogramma **G** con scalini interni (progressive overload).
Tutti i formati derivano dal simbolo approvato nella conversazione.

## Palette
- Blue: `#0D54F3`
- Ink: `#1E2630`
- Background off-white: `#F7F8FA`
- White: `#FFFFFF`

## Contenuto

**01_Brand_Mark/**
- `gradus-symbol.svg`: marchio vettoriale isolato (trasparente, proporzioni naturali)
- `gradus-symbol-{blue,dark,white}.svg`: versioni colore
- `gradus-symbol-square.svg` + PNG 256/512/1024: marchio centrato su artboard quadrata trasparente

**02_Logo_Sito/**
- `gradus-horizontal-light.svg`: marchio + wordmark per navbar su sfondo chiaro
- `gradus-horizontal-dark.svg`: marchio + wordmark bianco per sfondo scuro
- `gradus-stacked-*.svg`: versione verticale per footer/presentazioni
- Equivalenti PNG a risoluzione elevata. Le versioni con suffisso `background` sono opache.

**03_Favicon_Web/**
- `favicon.ico`: favicon multi-dimensione (16/32/48 px)
- `favicon.svg`: favicon vettoriale
- PNG 16, 32, 48, 64, 96, apple-touch 180 e PWA 192/512
- `site.webmanifest` e icone maskable

**04_iOS_App/**
- `Assets.xcassets/AppIcon.appiconset/`: asset catalog Xcode con app icon 1024px
- `AppIcon-Light.svg`, `AppIcon-Dark.svg`, `AppIcon-Tinted.svg`: sorgenti scalabili
- I file PNG iOS hanno **angoli squadrati**: è iOS ad applicare l'arrotondamento.

**05_Social_Preview/**
- `gradus-open-graph-1200x630.png`: anteprima per condivisioni social della landing

## Inserimento nella landing
Copia il contenuto di `03_Favicon_Web` dentro `/public` (Next.js / Vite) e aggiungi nel `<head>`:

```html
<link rel="icon" href="/favicon.ico" sizes="any" />
<link rel="icon" href="/favicon.svg" type="image/svg+xml" />
<link rel="apple-touch-icon" href="/apple-touch-icon.png" />
<link rel="manifest" href="/site.webmanifest" />
<meta name="theme-color" content="#0D54F3" />
<meta property="og:image" content="https://IL-TUO-DOMINIO/gradus-open-graph-1200x630.png" />
```

Per il logo della navbar utilizza il file `gradus-horizontal-light.svg` o `gradus-horizontal-dark.svg`.

## Inserimento in Xcode
Trascina / sostituisci `AppIcon.appiconset` in `Assets.xcassets`, poi imposta l'asset `AppIcon` in Target > General > App Icons.

Nota: i file SVG sono vettorializzazioni del concept grafico generato, non il progetto Figma/Illustrator originale. Non contengono font distribuiti.
