import Foundation

/// Gli obiettivi di macro di un giorno, come li scrive il coach.
public struct MacroTargets: Equatable, Sendable {
    public var kcal: Int
    public var proteinG: Int
    public var carbsG: Int
    public var fatG: Int
    public var fiberG: Int?

    public init(kcal: Int, proteinG: Int, carbsG: Int, fatG: Int, fiberG: Int? = nil) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
    }
}

/// Un piano di macro del coach: vale da `validFrom` (`yyyy-MM-dd`) finché non ne arriva uno più recente.
public struct MacroPlan: Equatable, Sendable {
    public var id: UUID
    public var validFrom: String
    public var deleted: Bool
    public var tolerancePct: Int
    public var targets: MacroTargets

    public init(id: UUID, validFrom: String, deleted: Bool = false, tolerancePct: Int = 10, targets: MacroTargets) {
        self.id = id
        self.validFrom = validFrom
        self.deleted = deleted
        self.tolerancePct = tolerancePct
        self.targets = targets
    }
}

/// Come l'atleta ha chiuso la giornata.
public enum MacroDayStatus: String, Codable, Sendable, CaseIterable {
    case respected
    case notRespected = "not_respected"
}

/// Da dove viene il dato: una conferma («sì, rispettati»), Apple Salute, o inserito a mano.
public enum MacroSource: String, Codable, Sendable, CaseIterable {
    case confirm
    case healthkit
    case manual
}

/// I macro assunti: tutti facoltativi (una semplice conferma non ne ha).
public struct MacroIntake: Equatable, Sendable {
    public var kcal: Double?
    public var proteinG: Double?
    public var carbsG: Double?
    public var fatG: Double?
    public var fiberG: Double?

    public init(kcal: Double? = nil, proteinG: Double? = nil, carbsG: Double? = nil, fatG: Double? = nil, fiberG: Double? = nil) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
    }

    public var isEmpty: Bool { [kcal, proteinG, carbsG, fatG, fiberG].allSatisfy { $0 == nil } }
}

public enum Nutrition {
    /// Il testo del consenso a condividere i macro con il coach: si salva con la data quando l'atleta acconsente.
    public static let consentVersion = "2026-10-16"

    /// Da quanti giorni indietro l'atleta può ancora correggere un giorno (decisione aperta: per ora 14).
    public static let editableDays = 14

    /// L'obiettivo in vigore un giorno: il piano non eliminato con `validFrom` più recente tra quelli già iniziati.
    /// Duplicazione ammessa della funzione SQL `nutrition_target_on`, perché serve offline: stessi casi in
    /// `/fixtures/nutrition_target_cases.json`.
    public static func planInForce(_ plans: [MacroPlan], on day: String) -> MacroPlan? {
        plans.filter { !$0.deleted && $0.validFrom <= day }.max { $0.validFrom < $1.validFrom }
    }

    /// «yyyy-MM-dd» nel fuso e nel calendario dati (di chi guarda: a mezzanotte il giorno cambia per lui).
    public static func dayString(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Gli ultimi `count` giorni fino a oggi compreso, il più recente per primo.
    public static func recentDays(count: Int, today: Date, calendar: Calendar = .current) -> [String] {
        (0..<max(count, 0)).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map { dayString($0, calendar: calendar) }
        }
    }

    /// Un giorno si registra o si corregge solo se non è nel futuro e non è più vecchio di `editableDays`.
    public static func isEditable(_ day: String, today: Date, calendar: Calendar = .current) -> Bool {
        recentDays(count: editableDays, today: today, calendar: calendar).contains(day)
    }

    /// Da quale fonte nasce un giorno scritto dall'atleta: senza numeri è una conferma, con numeri è a mano.
    public static func manualSource(for intake: MacroIntake) -> MacroSource { intake.isEmpty ? .confirm : .manual }
}

/// Il promemoria serale dei macro («Hai rispettato i macro di oggi?»): quando e se farlo partire.
public enum MacroReminder {
    /// Orario di default: le 22:00, in minuti dalla mezzanotte.
    public static let defaultMinutes = 22 * 60
    /// Quanti giorni in avanti si programmano (si riprogramma a ogni apertura dell'app).
    public static let daysAhead = 14

    public struct Item: Equatable, Sendable {
        public var day: String
        public var fireDate: Date

        public init(day: String, fireDate: Date) {
            self.day = day
            self.fireDate = fireDate
        }
    }

    /// I promemoria da programmare: uno per ogni giorno da oggi, all'orario scelto, ma solo se ancora nel futuro e solo per i
    /// giorni che l'atleta non ha già registrato (sul telefono o da Apple Salute): chi ha già risposto non viene disturbato.
    public static func plan(now: Date, minutes: Int, registeredDays: Set<String>, calendar: Calendar = .current) -> [Item] {
        let clamped = clamp(minutes)
        return (0..<daysAhead).compactMap { offset in
            guard let base = calendar.date(byAdding: .day, value: offset, to: now),
                let fire = calendar.date(bySettingHour: clamped / 60, minute: clamped % 60, second: 0, of: base)
            else { return nil }
            let day = Nutrition.dayString(fire, calendar: calendar)
            return fire > now && !registeredDays.contains(day) ? Item(day: day, fireDate: fire) : nil
        }
    }

    /// Un orario valido: tra 00:00 e 23:59.
    public static func clamp(_ minutes: Int) -> Int { min(max(minutes, 0), 24 * 60 - 1) }

    /// «22:00».
    public static func timeText(minutes: Int) -> String {
        let m = clamp(minutes)
        return String(format: "%02d:%02d", m / 60, m % 60)
    }
}
