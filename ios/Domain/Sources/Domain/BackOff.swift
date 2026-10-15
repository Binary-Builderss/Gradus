import Foundation

public enum BackOff {
    /// Passo di arrotondamento del carico target, in kg.
    public static let roundingStepKg: Decimal = 2.5

    /// Carico target del back-off: carico del top set × percentuale ÷ 100, arrotondato al 2,5 kg più vicino
    /// (a metà si sale). Duplicazione ammessa della funzione SQL `backoff_target_load`, perché serve offline:
    /// stessi casi in `/fixtures/backoff_cases.json`. È un'indicazione («≈ 90 kg»), mai un valore nei campi.
    public static func targetLoad(topLoadKg: Double, refPct: Double) -> Double {
        // Decimal e non Double: 83,75 ÷ 2,5 deve fare 33,5 esatto per salire a 34, come in Postgres (numeric).
        let exact = decimal(topLoadKg) * decimal(refPct) / 100
        var steps = exact / roundingStepKg
        var rounded = Decimal()
        NSDecimalRound(&rounded, &steps, 0, .plain)  // .plain = a metà lontano da zero, come `round` di Postgres
        return NSDecimalNumber(decimal: rounded * roundingStepKg).doubleValue
    }

    /// Il carico del top set da cui calcolare il back-off, dalle serie già registrate nel blocco di riferimento
    /// della seduta in corso: la serie registrata per ultima (indice più alto) che ha un carico, e in quella il
    /// primo carico (il più alto in un drop set). Nessun carico registrato → nessun target.
    public static func referenceLoad(of referenceSets: [LoggedSet]) -> Double? {
        referenceSets
            .sorted { $0.setIdx > $1.setIdx }
            .lazy
            .compactMap { set in set.segments.lazy.compactMap(\.loadKg).first }
            .first
    }

    /// «≈ 90 kg» per il riquadro prescrizione.
    public static func text(forTarget kg: Double) -> String {
        "≈ \(PreviousWeekReference.number(kg)) kg"
    }

    private static func decimal(_ value: Double) -> Decimal {
        Decimal(string: String(value)) ?? Decimal(value)
    }
}
