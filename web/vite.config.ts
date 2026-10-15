/// <reference types="vitest/config" />
import tailwindcss from '@tailwindcss/vite'
import { tanstackRouter } from '@tanstack/router-plugin/vite'
import react from '@vitejs/plugin-react'
import { copyFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { defineConfig, type Plugin } from 'vite'

/**
 * Collegamenti diretti (/piani, /nuova-password…) e ricarica della pagina: il server statico non ha un file per
 * quel percorso. Con un `404.html` uguale a `index.html` l'app parte comunque e il router legge l'indirizzo, sia su
 * Cloudflare Pages sia su Workers con asset statici, senza dipendere da come è configurato il progetto.
 */
const spaFallback = (): Plugin => ({
  name: 'spa-fallback-404',
  apply: 'build',
  closeBundle() {
    const out = fileURLToPath(new URL('./dist/', import.meta.url))
    copyFileSync(`${out}index.html`, `${out}404.html`)
  },
})

// https://vite.dev/config/
export default defineConfig({
  // Il plugin del router deve stare prima di react(): genera src/routeTree.gen.ts
  resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
  plugins: [
    tanstackRouter({ target: 'react', autoCodeSplitting: true }),
    react(),
    tailwindcss(),
    spaFallback(),
  ],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
  },
})
