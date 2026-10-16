/** Titolare e contatti scritti nelle pagine legali. Un solo posto: cambiano qui. */
export const legal = {
  controller: 'Binary Builders',
  // TODO: scrivere l'indirizzo reale prima del lancio; il test lo segnala finché è un segnaposto.
  contactEmail: '[email di contatto da inserire]',
  /** Versione dei testi: va cambiata quando cambiano, e finisce nei metadati di chi accetta. */
  version: '2026-10-16',
}

export type LegalSection = { title: string; paragraphs: readonly string[] }
