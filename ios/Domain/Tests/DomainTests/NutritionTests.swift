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

struct MacroReminderTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test("un promemoria per ogni giorno dei prossimi 14, all'orario scelto")
    func fourteenDays() {
        let plan = MacroReminder.plan(now: date(2026, 10, 16, 9), minutes: 22 * 60, registeredDays: [], calendar: calendar)
        #expect(plan.count == 14)
        #expect(plan.first?.day == "2026-10-16")
        #expect(plan.first?.fireDate == date(2026, 10, 16, 22))
        #expect(plan.last?.day == "2026-10-29")
    }

    @Test("se l'orario di oggi è già passato si parte da domani")
    func startsTomorrowWhenLate() {
        let plan = MacroReminder.plan(now: date(2026, 10, 16, 22, 30), minutes: 22 * 60, registeredDays: [], calendar: calendar)
        #expect(plan.first?.day == "2026-10-17")
        #expect(plan.count == 13)
    }

    @Test("i giorni già registrati non ricevono il promemoria")
    func skipsRegisteredDays() {
        let plan = MacroReminder.plan(
            now: date(2026, 10, 16, 9), minutes: 22 * 60, registeredDays: ["2026-10-16", "2026-10-18"], calendar: calendar)
        #expect(plan.map(\.day).prefix(3) == ["2026-10-17", "2026-10-19", "2026-10-20"])
    }

    @Test("orario personalizzato, anche con i minuti; valori fuori misura si riportano dentro")
    func customTime() {
        let plan = MacroReminder.plan(now: date(2026, 10, 16, 9), minutes: 21 * 60 + 45, registeredDays: [], calendar: calendar)
        #expect(plan.first?.fireDate == date(2026, 10, 16, 21, 45))
        #expect(MacroReminder.clamp(-5) == 0)
        #expect(MacroReminder.clamp(99_999) == 1439)
        #expect(MacroReminder.timeText(minutes: 21 * 60 + 5) == "21:05")
        #expect(MacroReminder.timeText(minutes: MacroReminder.defaultMinutes) == "22:00")
    }

    @Test("attraverso il cambio di mese e di anno")
    func acrossYear() {
        let plan = MacroReminder.plan(now: date(2026, 12, 25, 9), minutes: 22 * 60, registeredDays: [], calendar: calendar)
        #expect(plan.map(\.day).contains("2026-12-31") && plan.map(\.day).contains("2027-01-01"))
    }
}
