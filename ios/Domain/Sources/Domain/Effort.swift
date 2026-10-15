import Foundation

/// Scala dello sforzo percepito. BUF = ripetizioni di riserva (RIR), RPE = 10 − BUF; si salva nella scala in cui
/// è stato inserito (`effort_value` + `effort_scale`).
public enum EffortScale: String, Codable, Sendable, CaseIterable {
    case buf = "BUF"
    case rpe = "RPE"
}

public struct Effort: Equatable, Codable, Sendable {
    public var value: Double
    public var scale: EffortScale

    public init(value: Double, scale: EffortScale) {
        self.value = value
        self.scale = scale
    }
}

/// Una coppia carico × ripetizioni dentro una serie: una serie normale ha un segmento, un drop set di 3 ne ha 3.
public struct Segment: Equatable, Codable, Sendable {
    public var loadKg: Double?
    public var reps: Int?

    public init(loadKg: Double?, reps: Int?) {
        self.loadKg = loadKg
        self.reps = reps
    }
}
