/** Testi dell'interfaccia (italiano). Unico punto da cui i componenti leggono le stringhe. */
export const messages = {
  brand: {
    name: 'Gradus',
    claimStart: 'Un passo alla',
    claimEnd: 'volta.',
    body: 'Programma i mesocicli dei tuoi atleti e segui ogni serie che registrano.',
  },
  auth: {
    email: 'Email',
    password: 'Password',
    showPassword: 'Mostra password',
    hidePassword: 'Nascondi password',
    backToLogin: "Torna all'accesso",
    login: {
      title: 'Accedi',
      subtitle: 'Entra nel tuo spazio coach.',
      submit: 'Entra',
      submitting: 'Accesso in corso…',
      forgot: 'Password dimenticata?',
    },
    recovery: {
      title: 'Recupera la password',
      subtitle: 'Ti mandiamo un link per sceglierne una nuova.',
      submit: 'Invia il link',
      submitting: 'Invio in corso…',
      sentTitle: 'Controlla la posta',
      sent: "Se l'indirizzo è registrato, tra poco riceverai un'email con il link.",
    },
    newPassword: {
      title: 'Nuova password',
      subtitle: 'Scegli una password di almeno 8 caratteri.',
      label: 'Nuova password',
      confirm: 'Ripeti la password',
      submit: 'Salva ed entra',
      submitting: 'Salvataggio…',
      expiredTitle: 'Link non valido',
      expired: 'Il link è scaduto o è già stato usato. Richiedine uno nuovo.',
      requestNew: 'Richiedi un nuovo link',
    },
    errors: {
      emailInvalid: 'Inserisci un indirizzo email valido.',
      passwordRequired: 'Inserisci la password.',
      passwordTooShort: 'La password deve avere almeno 8 caratteri.',
      passwordMismatch: 'Le due password non coincidono.',
      samePassword: 'La nuova password deve essere diversa da quella attuale.',
      invalidCredentials: 'Email o password non corretti.',
      rateLimit: 'Troppi tentativi. Aspetta qualche minuto e riprova.',
      network: 'Connessione non riuscita. Controlla la rete e riprova.',
      generic: 'Qualcosa non ha funzionato. Riprova.',
    },
  },
  app: {
    nav: { athletes: 'Atleti' },
    signOut: 'Esci',
    athletes: {
      title: 'Atleti',
      emptyTitle: 'Nessun atleta collegato',
      emptyBody:
        "Qui comparirà ogni atleta che segui, con l'ultima seduta registrata e l'aderenza degli ultimi 7 giorni.",
    },
  },
} as const
