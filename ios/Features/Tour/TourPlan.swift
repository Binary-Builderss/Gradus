import Foundation

/// Dove sta la guida dentro la scheda Allenamento: la lista (home), una seduta aperta (la n-esima del programma) o il
/// primo esercizio di una seduta. Le altre schede stanno sempre alla radice.
enum TourScreen: Equatable, Sendable {
    case root
    case session(Int)
    case exercise(Int)

    /// L'indice della seduta da tenere aperta, se ce n'è una.
    var sessionIndex: Int? {
        switch self {
        case .root: nil
        case .session(let i), .exercise(let i): i
        }
    }
}

/// Cosa c'è nel programma dell'atleta, quanto basta a costruire il percorso: i nomi delle sedute in ordine e se la prima ha
/// almeno un esercizio da aprire.
struct TourProgram: Equatable, Sendable {
    var sessionNames: [String]
    var firstHasExercises: Bool
}

/// Un passo della guida: la scheda (e la schermata) in cui sta, l'elemento da evidenziare (`tourTarget`) se c'è, e il testo.
struct TourStep: Equatable, Identifiable, Sendable {
    var id: String
    var tab: MainTab
    var screen: TourScreen = .root
    var target: String?
    var title: String
    var body: String
}

/// Il percorso della guida, in ordine d'uso: allenamento (home, ogni seduta, un esercizio) → macro → profilo. Ogni scheda
/// dell'app ha i suoi passi; quando un'altra funzione nasce, qui nasce il suo passo (un test controlla che nessun elemento
/// evidenziato resti senza passo).
enum TourPlan {
    /// `program` è nil quando l'atleta non ha ancora un mesociclo attivo: la guida salta i passi che lo mostrano.
    static func steps(program: TourProgram?) -> [TourStep] {
        var steps: [TourStep] = [
            TourStep(
                id: "welcome", tab: .workout, target: nil, title: "Benvenuto in Gradus Atleta",
                body: "Qui trovi il programma che ha scritto il tuo coach e registri le serie mentre ti alleni. Ti faccio un giro veloce: puoi saltarlo e rivederlo quando vuoi dal Profilo."),
        ]
        guard let program else {
            steps.append(
                TourStep(
                    id: "no-program", tab: .workout, target: nil, title: "Il tuo programma",
                    body: "Appena il tuo coach attiva un mesociclo lo trovi qui, con le settimane e le sedute. Funziona anche senza rete."))
            return steps + common
        }
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
        for (index, name) in program.sessionNames.enumerated() {
            if index == 0 {
                steps.append(
                    TourStep(
                        id: "session-0", tab: .workout, screen: .session(0), target: "session-exercise",
                        title: "Dentro la seduta: \(name)",
                        body: "Ecco gli esercizi che ti ha dato il coach, con serie, ripetizioni e recupero. Un esercizio diventa verde quando hai fatto tutte le serie previste. Superset e circuiti sono raggruppati."))
                steps += exerciseSteps(open: program.firstHasExercises)
            } else {
                steps.append(
                    TourStep(
                        id: "session-\(index)", tab: .workout, screen: .session(index), target: "session-exercise",
                        title: "Seduta: \(name)",
                        body: "Un'altra seduta del programma. Si apre e si registra allo stesso modo."))
            }
        }
        return steps + common
    }

    /// I passi dentro un esercizio. Se la prima seduta non ha esercizi da aprire restano come testo, senza evidenziare niente.
    private static func exerciseSteps(open: Bool) -> [TourStep] {
        let screen: TourScreen = open ? .exercise(0) : .session(0)
        func at(_ target: String) -> String? { open ? target : nil }
        return [
            TourStep(
                id: "exercise", tab: .workout, screen: screen, target: at("exercise-block"), title: "Cosa devi fare",
                body: "Aprendo un esercizio vedi la prescrizione del coach per ogni blocco: quante serie, le ripetizioni e il recupero. Nel back-off trovi anche il carico indicativo."),
            TourStep(
                id: "logging", tab: .workout, screen: screen, target: at("exercise-set"), title: "Registrare le serie",
                body: "Per ogni serie scrivi carico e ripetizioni: i campi partono vuoti e si salva tutto da solo, non c'è un tasto Salva. Sopra la serie vedi cosa hai fatto la settimana scorsa."),
            TourStep(
                id: "effort", tab: .workout, screen: screen, target: at("exercise-effort"), title: "Lo sforzo percepito",
                body: "Se vuoi, tocca quanto è stata dura la serie, sulla scala che usa il tuo coach. Tocco lungo per il mezzo punto, un secondo tocco per toglierlo."),
            TourStep(
                id: "timer", tab: .workout, screen: screen, target: at("exercise-timer"), title: "Il recupero",
                body: "«Avvia timer» fa partire il recupero: lo ritrovi in basso in tutta l'app e ti avvisa anche a schermo bloccato."),
            TourStep(
                id: "next-exercise", tab: .workout, screen: screen, target: nil, title: "Esercizio dopo esercizio",
                body: "Scorri di lato per passare all'esercizio successivo senza tornare all'elenco. Se il coach ha collegato un video, lo apri dal tasto in alto a destra."),
        ]
    }

    private static let common: [TourStep] = [
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
}
