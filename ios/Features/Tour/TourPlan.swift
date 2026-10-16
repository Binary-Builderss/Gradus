import Foundation

/// Un passo della guida: la scheda in cui sta, l'elemento da evidenziare (`tourTarget`) se c'è, e il testo.
struct TourStep: Equatable, Identifiable, Sendable {
    var id: String
    var tab: MainTab
    var target: String?
    var title: String
    var body: String
}

/// Il percorso della guida, in ordine d'uso: allenamento → macro → profilo. Ogni scheda dell'app ha i suoi passi; quando
/// un'altra funzione nasce, qui nasce il suo passo (un test controlla che nessun elemento evidenziato resti senza passo).
enum TourPlan {
    static func steps(hasProgram: Bool) -> [TourStep] {
        var steps: [TourStep] = [
            TourStep(
                id: "welcome", tab: .workout, target: nil, title: "Benvenuto in Gradus",
                body: "Qui trovi il programma che ha scritto il tuo coach e registri le serie mentre ti alleni. Ti faccio un giro veloce: puoi saltarlo e rivederlo quando vuoi dal Profilo."),
        ]
        if hasProgram {
            steps += [
                TourStep(
                    id: "program", tab: .workout, target: "home-program", title: "Il tuo mesociclo",
                    body: "È il programma in corso: il nome, quante settimane dura e le note del tuo coach."),
                TourStep(
                    id: "weeks", tab: .workout, target: "home-weeks", title: "Le settimane",
                    body: "Scegli la settimana. Si apre su quella in corso; le settimane di scarico hanno una freccia in giù."),
                TourStep(
                    id: "sessions", tab: .workout, target: "home-sessions", title: "Le sedute",
                    body: "Tocca una seduta per aprirla. Vedi se l'hai iniziata o completata, senza dover premere «fine»."),
            ]
        } else {
            steps.append(
                TourStep(
                    id: "no-program", tab: .workout, target: nil, title: "Il tuo programma",
                    body: "Appena il tuo coach attiva un mesociclo lo trovi qui, con le settimane e le sedute. Funziona anche senza rete."))
        }
        steps += [
            TourStep(
                id: "session", tab: .workout, target: nil, title: "Dentro la seduta",
                body: "Apri un esercizio per vedere cosa ti ha prescritto il coach e registrare le serie. Un esercizio diventa verde quando hai fatto tutte le serie previste."),
            TourStep(
                id: "logging", tab: .workout, target: nil, title: "Registrare le serie",
                body: "Per ogni serie scrivi carico e ripetizioni: i campi partono vuoti e si salva tutto da solo, non c'è un tasto Salva. Sopra la serie vedi cosa hai fatto la settimana scorsa; nel back-off trovi il carico indicativo."),
            TourStep(
                id: "effort-timer", tab: .workout, target: nil, title: "Sforzo e recupero",
                body: "Se vuoi, tocca lo sforzo percepito (tocco lungo per il mezzo punto). «Avvia timer» fa partire il recupero: lo ritrovi in basso in tutta l'app e ti avvisa anche a schermo bloccato."),
            TourStep(
                id: "macro-target", tab: .macro, target: "macro-target", title: "Il tuo obiettivo",
                body: "Calorie e macro che il tuo coach ha impostato per te. Compaiono qui appena li scrive."),
            TourStep(
                id: "macro-days", tab: .macro, target: "macro-days", title: "Come vanno i giorni",
                body: "Tocca un giorno per segnare se hai rispettato i macro e, se vuoi, aggiungere quanto hai assunto. Verde rispettati, rosso no, grigio non registrato."),
            TourStep(
                id: "macro-reminder", tab: .macro, target: nil, title: "Il promemoria della sera",
                body: "Ogni sera ti chiedo «Hai rispettato i macro di oggi?» e rispondi con un tocco, anche dalla notifica. Lo accendi, lo spegni e scegli l'orario da Profilo → Preferenze. Per registrare i macro serve il tuo consenso a condividerli con il coach."),
            TourStep(
                id: "profile", tab: .profile, target: "profile-sections", title: "Il tuo profilo",
                body: "Account (nome e password), Preferenze (promemoria dei macro e timer), Sincronizzazione, Privacy e Assistenza. In fondo puoi disattivare o eliminare l'account, o uscire."),
            TourStep(
                id: "offline", tab: .profile, target: nil, title: "Anche senza rete",
                body: "Le serie e i macro si salvano sul telefono e partono appena c'è connessione. Dalla Sincronizzazione vedi quante ne restano da inviare."),
            TourStep(
                id: "guide", tab: .profile, target: "profile-guide", title: "Rivedi la guida",
                body: "Quando vuoi, da qui rifai questo giro. Buon allenamento!"),
        ]
        return steps
    }
}
