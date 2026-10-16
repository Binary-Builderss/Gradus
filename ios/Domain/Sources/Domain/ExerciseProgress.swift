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

/// Lo sforzo percepito, sulla scala della prescrizione: BUF (ripetizioni in riserva) 0–5 oppure RPE 6–10, a passi di
/// 0,5 (stesso vincolo del database). Si sceglie con una riga di tasti interi; il mezzo punto con il tocco lungo.
public enum EffortOptions {
    /// La scala della prescrizione se è RPE; altrimenti ripetizioni in riserva (BUF), che è anche quella dei blocchi
    /// senza sforzo prescritto. Non c'è una scelta dell'atleta: la scala la decide il coach.
    public static func scale(prescribed: IntensityMethod?) -> EffortScale {
        prescribed == .rpe ? .rpe : .buf
    }

    /// I tasti: BUF 0, 1, 2, 3, 4, 5 · RPE 6, 7, 8, 9, 10.
    public static func wholeValues(for scale: EffortScale) -> [Double] {
        let range: ClosedRange<Double> = scale == .buf ? 0...5 : 6...10
        return stride(from: range.lowerBound, through: range.upperBound, by: 1).map { $0 }
    }

    /// Il mezzo punto sopra un valore intero (2 → 2,5), se la scala lo ammette (non oltre il massimo).
    public static func halfStep(above whole: Double, scale: EffortScale) -> Double? {
        let candidate = whole + 0.5
        return wholeValues(for: scale).last.map { candidate <= $0 } == true ? candidate : nil
    }

    public static func title(for scale: EffortScale) -> String {
        scale == .buf ? "Ripetizioni in riserva" : "Sforzo (RPE)"
    }
}

/// Eliminare l'account: serve l'email scritta a mano, come sul sito (stessa regola della Edge Function).
public enum DeleteConfirmation {
    public static func matches(_ typed: String, email: String) -> Bool {
        let normalize = { (text: String) in text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return !normalize(email).isEmpty && normalize(typed) == normalize(email)
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

/// Il nome con cui il coach vede l'atleta: tolti gli spazi in eccesso, mai vuoto, al massimo 80 caratteri.
public enum ProfileName {
    public static let maxLength = 80

    public static func normalized(_ text: String) -> String? {
        let words = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !words.isEmpty else { return nil }
        return String(words.prefix(maxLength))
    }
}
