import Foundation

/// Quanto dura il recupero dopo una serie, e se il pulsante «Avvia timer» compare.
public enum RestPlan {
    /// Esercizio da solo: `rest_s` del blocco. Gruppo (superset, giant set, circuito…): `rest_between_s` dopo ogni
    /// esercizio del giro e `rest_after_round_s` dopo l'ultimo. Valori mancanti = 0.
    ///
    /// - Parameters:
    ///   - groupSize: quanti esercizi ha il gruppo (1 = esercizio da solo).
    ///   - position: posizione dell'esercizio nel gruppo, da 0.
    public static func seconds(
        groupSize: Int, position: Int, blockRestS: Int?, restBetweenS: Int, restAfterRoundS: Int
    ) -> Int {
        guard groupSize > 1 else { return max(blockRestS ?? 0, 0) }
        return max(position >= groupSize - 1 ? restAfterRoundS : restBetweenS, 0)
    }

    /// Se la durata è 0 il pulsante non compare; nemmeno sull'ultima serie della seduta.
    public static func showsButton(seconds: Int, isLastSetOfSession: Bool) -> Bool {
        seconds > 0 && !isLastSetOfSession
    }
}

/// Il timer di recupero in corso. Si salva l'**orario di fine**, non un contatore: così sopravvive a background,
/// blocco dello schermo, chiusura e riavvio dell'app. Un solo timer alla volta.
public struct RestTimerState: Codable, Equatable, Sendable {
    public var endDate: Date
    /// Per cosa si recupera, per la notifica («Panca piana · serie 2»).
    public var title: String
    /// Quando è partito, per la barra che si svuota. Facoltativo: i timer salvati prima non ce l'hanno.
    public var startDate: Date?

    public init(endDate: Date, title: String, startDate: Date? = nil) {
        self.endDate = endDate
        self.title = title
        self.startDate = startDate
    }

    public init(startingAt now: Date, seconds: Int, title: String) {
        self.init(endDate: now.addingTimeInterval(TimeInterval(seconds)), title: title, startDate: now)
    }

    /// Quanto manca, da 1 (appena partito) a 0 (finito). Con +15 s la durata totale cresce, quindi resta tra 0 e 1.
    public func remainingFraction(at now: Date) -> Double {
        guard let startDate, endDate > startDate else { return isFinished(at: now) ? 0 : 1 }
        return min(max(endDate.timeIntervalSince(now) / endDate.timeIntervalSince(startDate), 0), 1)
    }

    /// Secondi rimasti, arrotondati per eccesso (a 0,2 s dalla fine si legge ancora «0:01»), mai negativi.
    public func remainingSeconds(at now: Date) -> Int {
        max(Int(endDate.timeIntervalSince(now).rounded(.up)), 0)
    }

    public func isFinished(at now: Date) -> Bool { endDate <= now }

    /// +15 s / −15 s: sposta la fine. Sotto zero il timer è finito.
    public func adjusted(bySeconds seconds: Int) -> RestTimerState {
        RestTimerState(endDate: endDate.addingTimeInterval(TimeInterval(seconds)), title: title, startDate: startDate)
    }

    /// «1:30», «0:05».
    public static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
