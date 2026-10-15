import Foundation

/// Una serie registrata dall'atleta (riga di `set_logs` con i suoi segmenti).
public struct LoggedSet: Equatable, Sendable {
    public var mesocycleID: UUID
    public var sessionID: UUID
    public var blockID: UUID
    public var week: Int
    public var setIdx: Int
    public var segments: [Segment]
    public var effort: Effort?

    public init(
        mesocycleID: UUID, sessionID: UUID, blockID: UUID, week: Int, setIdx: Int,
        segments: [Segment], effort: Effort?
    ) {
        self.mesocycleID = mesocycleID
        self.sessionID = sessionID
        self.blockID = blockID
        self.week = week
        self.setIdx = setIdx
        self.segments = segments
        self.effort = effort
    }
}

/// Cosa è stato fatto nella stessa serie nella settimana di riferimento.
public struct PreviousWeekReference: Equatable, Sendable {
    public var blockID: UUID
    public var setIdx: Int
    /// La settimana da cui viene il riferimento (di solito N−1; più indietro se N−1 è di scarico).
    public var week: Int
    public var segments: [Segment]
    public var effort: Effort?

    public init(blockID: UUID, setIdx: Int, week: Int, segments: [Segment], effort: Effort?) {
        self.blockID = blockID
        self.setIdx = setIdx
        self.week = week
        self.segments = segments
        self.effort = effort
    }
}

public enum PreviousWeek {
    /// Riferimento alla settimana precedente, serie per serie.
    ///
    /// Duplicazione ammessa della funzione SQL `previous_week_reference`, perché serve offline: stessi casi in
    /// `/fixtures/previous_week_cases.json`. Regole:
    /// - settimana 1 → nessun riferimento;
    /// - si cerca a ritroso la prima settimana prima di `week` che non è di scarico (gli scarichi sono esclusi
    ///   dalla ricerca); con N−1 normale è N−1;
    /// - stessa seduta, stesso mesociclo, stessa serie; se in quella settimana la seduta non ha dati (saltata) →
    ///   nessun riferimento, non si risale oltre;
    /// - mai dati di un altro mesociclo o di un'altra seduta.
    ///
    /// - Parameter blockOrder: i blocchi della seduta, nell'ordine in cui compaiono. Il risultato segue quest'ordine
    ///   (poi l'indice della serie); le serie di blocchi che non ne fanno parte (eliminati) sono escluse.
    public static func references(
        mesocycleID: UUID,
        sessionID: UUID,
        week: Int,
        deloadWeeks: Set<Int>,
        blockOrder: [UUID],
        logs: [LoggedSet]
    ) -> [PreviousWeekReference] {
        guard week > 1,
            let referenceWeek = (1..<week).reversed().first(where: { !deloadWeeks.contains($0) })
        else { return [] }
        let position = Dictionary(uniqueKeysWithValues: blockOrder.enumerated().map { ($1, $0) })
        return logs
            .filter {
                $0.mesocycleID == mesocycleID && $0.sessionID == sessionID && $0.week == referenceWeek
                    && position[$0.blockID] != nil
            }
            .sorted { (position[$0.blockID]!, $0.setIdx) < (position[$1.blockID]!, $1.setIdx) }
            .map {
                PreviousWeekReference(
                    blockID: $0.blockID, setIdx: $0.setIdx, week: $0.week, segments: $0.segments, effort: $0.effort)
            }
    }
}
