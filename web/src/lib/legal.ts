/** Titolare e contatti scritti nelle pagine legali. Un solo posto: cambiano qui. */
export const legal = {
  controller: 'Binary Builders',
  contactEmail: 'contactus@binarybuilders.dev',
  /** Versione dei testi: va cambiata quando cambiano, e finisce nei metadati di chi accetta. */
  version: '2026-10-16',
}

export type LegalSection = { title: string; paragraphs: readonly string[] }
