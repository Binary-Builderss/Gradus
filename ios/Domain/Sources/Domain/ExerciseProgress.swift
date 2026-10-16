import Foundation

/// Stato di un blocco, di un esercizio o di una seduta, derivato da serie registrate e prescritte. Nessun pulsante
/// «fatto»: la seduta inizia alla prima serie e finisce con l'ultima.
public enum Completion: Equatable, Sendable {
    case empty, partial, complete

    /// Serie registrate contro serie prescritte (le registrate in più contano come complete).
    public init(logged: Int, prescribed: Int) {
        if logged <= 0 { self = .empty } else if logged >= prescribed { self = .complete } else { self = .partial }
    }

    /// Lo stato di un insieme: tutti completi → completo; nessuno iniziato → vuoto; altrimenti parziale.
    public static func combined(_ parts: [Completion]) -> Completion {
        guard !parts.isEmpty, parts.contains(where: { $0 != .empty }) else { return .empty }
        return parts.allSatisfy { $0 == .complete } ? .complete : .partial
    }
}

/// I valori che l'atleta può scegliere per lo sforzo percepito, sulla scala della prescrizione.
public enum EffortOptions {
    /// BUF da 0 a 5, RPE da 6 a 10, a passi di 0,5 (stesso vincolo del database).
    public static func values(for scale: EffortScale) -> [Double] {
        let range: ClosedRange<Double> = scale == .buf ? 0...5 : 6...10
        return stride(from: range.lowerBound, through: range.upperBound, by: 0.5).map { $0 }
    }

    /// La scala in cui chiedere lo sforzo: quella della prescrizione se è BUF o RPE, altrimenti la preferita.
    public static func scale(prescribed: IntensityMethod?, preferred: EffortScale) -> EffortScale {
        switch prescribed {
        case .buf: .buf
        case .rpe: .rpe
        default: preferred
        }
    }
}

/// Numeri scritti dall'atleta: accetta virgola o punto, rifiuta il resto. Vuoto → nil.
public enum NumberInput {
    public static func decimal(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite, value >= 0 else { return nil }
        return value
    }

    public static func integer(_ text: String) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, let value = Int(cleaned), value >= 0 else { return nil }
        return value
    }

    /// Il numero come lo scrive l'atleta: 82.5 → «82,5», 100 → «100».
    public static func text(_ value: Double) -> String { Format.number(value) }
}
