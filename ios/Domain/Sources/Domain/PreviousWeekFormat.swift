import Foundation

extension PreviousWeekReference {
    /// Il riferimento come testo per l'intestazione della serie: «Sett. 3: 100 × 5 · BUF 1»; per un drop set
    /// «Sett. 3: 100 × 8 + 75 × 6». È testo, mai un valore dentro i campi.
    public var text: String {
        let work = segments.map(Self.format).joined(separator: " + ")
        let parts = [work, effort.map(Self.format)].compactMap { $0 }.filter { !$0.isEmpty }
        return "Sett. \(week): " + parts.joined(separator: " · ")
    }

    private static func format(_ segment: Segment) -> String {
        "\(number(segment.loadKg)) × \(segment.reps.map(String.init) ?? "–")"
    }

    private static func format(_ effort: Effort) -> String {
        "\(effort.scale.rawValue) \(number(effort.value))"
    }

    static func number(_ value: Double?) -> String {
        value.map(Format.number) ?? "–"
    }
}
