import Foundation
import Testing

@testable import Domain

struct NutritionTests {
    private func calendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ hour: Int = 12) -> Date {
        calendar().date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    @Test("il giorno è quello di chi guarda, a due cifre; a mezzanotte cambia")
    func dayString() {
        #expect(Nutrition.dayString(date(2026, 1, 5, 23), calendar: calendar()) == "2026-01-05")
        #expect(Nutrition.dayString(date(2026, 1, 6, 0), calendar: calendar()) == "2026-01-06")
    }

    @Test("ultimi giorni: il più recente per primo, attraverso il cambio di mese e di anno")
    func recentDays() {
        let days = Nutrition.recentDays(count: 4, today: date(2027, 1, 2), calendar: calendar())
        #expect(days == ["2027-01-02", "2027-01-01", "2026-12-31", "2026-12-30"])
        #expect(Nutrition.recentDays(count: 0, today: date(2026, 10, 16), calendar: calendar()).isEmpty)
    }

    @Test("si corregge solo entro 14 giorni e mai il futuro")
    func editable() {
        let today = date(2026, 10, 16)
        #expect(Nutrition.isEditable("2026-10-16", today: today, calendar: calendar()))
        #expect(Nutrition.isEditable("2026-10-03", today: today, calendar: calendar()))  // 13 giorni fa
        #expect(!Nutrition.isEditable("2026-10-02", today: today, calendar: calendar()))  // 14 giorni fa
        #expect(!Nutrition.isEditable("2026-10-17", today: today, calendar: calendar()))  // domani
    }

    @Test("la fonte: senza numeri è una conferma, con numeri è a mano")
    func source() {
        #expect(Nutrition.manualSource(for: MacroIntake()) == .confirm)
        #expect(Nutrition.manualSource(for: MacroIntake(kcal: 2400)) == .manual)
        #expect(MacroIntake().isEmpty)
        #expect(!MacroIntake(fiberG: 20).isEmpty)
    }

    @Test("l'id di un giorno dipende da atleta e data, ed è stabile")
    func dayID() {
        let a = UUID(uuidString: "A0000000-0000-4000-8000-000000000001")!
        let b = UUID(uuidString: "A0000000-0000-4000-8000-000000000002")!
        #expect(DeterministicID.nutritionDay(athleteID: a, day: "2026-10-16") == DeterministicID.nutritionDay(athleteID: a, day: "2026-10-16"))
        #expect(DeterministicID.nutritionDay(athleteID: a, day: "2026-10-16") != DeterministicID.nutritionDay(athleteID: a, day: "2026-10-17"))
        #expect(DeterministicID.nutritionDay(athleteID: a, day: "2026-10-16") != DeterministicID.nutritionDay(athleteID: b, day: "2026-10-16"))
    }
}
