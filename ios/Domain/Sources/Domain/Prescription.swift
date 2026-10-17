import Foundation

/// Come si misura lo sforzo prescritto (colonna `method` di `block_weeks`).
public enum IntensityMethod: String, Codable, Sendable, CaseIterable {
    case buf = "BUF"
    case rpe = "RPE"
    case rm = "RM"
    case pct1RM = "PCT_1RM"
    case load = "LOAD"
}

/// La prescrizione di un blocco in una settimana (una riga di `block_weeks`).
public struct Prescription: Equatable, Sendable {
    public var sets: Int
    public var repsMin: Int?
    public var repsMax: Int?
    public var method: IntensityMethod?
    public var value: Double?
    /// Percentuale del carico del blocco di riferimento (back-off).
    public var refPct: Double?

    public init(
        sets: Int, repsMin: Int? = nil, repsMax: Int? = nil, method: IntensityMethod? = nil, value: Double? = nil,
        refPct: Double? = nil
    ) {
        self.sets = sets
        self.repsMin = repsMin
        self.repsMax = repsMax
        self.method = method
        self.value = value
        self.refPct = refPct
    }

    /// La prescrizione a parole, come la scrive il coach sul web: «3 serie da 8-10 ripetizioni, 2 ripetizioni in
    /// riserva». Ripetizioni, sforzo e carico compaiono solo se il coach li ha scritti.
    public var text: String {
        var parts = ["\(sets) serie"]
        if let reps = repsText { parts[0] += " da \(reps) ripetizioni" }
        if let effort = effortText { parts.append(effort) }
        return parts.joined(separator: ", ")
    }

    /// La prescrizione in notazione da palestra, per leggerla al volo: «3×8–10 · BUF 2», «2×8–10 · 85% top set».
    /// `text` resta la versione a parole (VoiceOver).
    public var shortText: String {
        var parts = [repsText.map { "\(sets)×\($0.replacingOccurrences(of: "-", with: "–"))" } ?? "\(sets) serie"]
        if let effort = effortShort { parts.append(effort) }
        return parts.joined(separator: " · ")
    }

    private var effortShort: String? {
        if let refPct, method == nil { return "\(Format.number(refPct))% top set" }
        guard let method, let value else { return nil }
        let v = Format.number(value)
        switch method {
        case .buf: return value == 0 ? "cedimento" : "BUF \(v)"
        case .rpe: return "RPE \(v)"
        case .load: return "\(v) kg"
        case .pct1RM: return "\(v)% 1RM"
        case .rm: return "\(v)RM"
        }
    }

    /// «8-10», oppure «8» se è un numero solo.
    public var repsText: String? {
        guard let min = repsMin ?? repsMax else { return nil }
        let max = repsMax ?? min
        return min == max ? "\(min)" : "\(min)-\(max)"
    }

    /// Lo sforzo o il carico prescritto, a parole.
    public var effortText: String? {
        if let refPct, method == nil { return "\(Format.number(refPct))% del carico del top set" }
        guard let method, let value else { return nil }
        let v = Format.number(value)
        switch method {
        case .buf:
            switch value {
            case 0: return "a cedimento"
            case 1: return "1 ripetizione in riserva"
            default: return "\(v) ripetizioni in riserva"
            }
        case .rpe: return "sforzo \(v) su 10"
        case .load: return "\(v) kg"
        case .pct1RM: return "\(v)% del massimale"
        case .rm: return "carico da \(v)RM"
        }
    }
}

/// Numeri all'italiana, senza decimali inutili: 100 → «100», 102.5 → «102,5».
enum Format {
    static func number(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(rounded).replacingOccurrences(of: ".", with: ",")
    }
}

public enum RestText {
    /// 45 → «45 s», 120 → «2 min», 90 → «1 min 30 s».
    public static func format(seconds: Int) -> String {
        guard seconds >= 60 else { return "\(seconds) s" }
        let minutes = seconds / 60, rest = seconds % 60
        return rest == 0 ? "\(minutes) min" : "\(minutes) min \(rest) s"
    }
}
