import Domain
import Foundation
import GRDB
import Testing

@testable import Gradus

@MainActor
struct MacroDayModelTests {
    private var calendar: Calendar { .current }
    private var day: String { Nutrition.dayString(.now, calendar: calendar) }

    private func make(consent: Bool = true, entry: DayEntry? = nil) async throws -> (MacroDayModel, NutritionStore, AppDatabase) {
        let remote = FakeRemote()
        Sample.populate(remote)
        if consent {
            var profiles = remote.rows(.profiles)
            profiles[0]["nutrition_consent_at"] = "2026-10-10T10:00:00.000+00:00"
            remote.set(.profiles, profiles)
        }
        let database = try AppDatabase.inMemory()
        _ = try await SyncEngine(remote: remote, database: database).sync()
        let store = NutritionStore(database: database, remote: remote)
        let start = entry ?? DayEntry(day: day, status: nil, source: nil, intake: MacroIntake(), target: nil)
        return (MacroDayModel(entry: start, athleteID: Sample.athlete, store: store, debounce: .milliseconds(20)), store, database)
    }

    private func saved(_ database: AppDatabase) async throws -> NutritionSnapshot {
        try await database.writer.read { try NutritionStore.snapshot($0, athleteID: Sample.athlete) }
    }

    @Test("i campi partono vuoti e il giorno non esiste finché non si sceglie come è andata")
    func startsEmpty() async throws {
        let (model, _, database) = try await make()
        #expect(model.status == nil)
        #expect(model.kcal.isEmpty && model.protein.isEmpty && model.carbs.isEmpty && model.fat.isEmpty && model.fiber.isEmpty)
        model.kcal = "2500"
        model.numbersChanged()  // senza stato non si salva nulla
        try await Task.sleep(for: .milliseconds(120))
        #expect(try await saved(database).days.allSatisfy { $0.status == nil })
    }

    @Test("scegliere «Rispettati» salva subito una conferma")
    func choosingStatusSaves() async throws {
        let (model, _, database) = try await make()
        model.setStatus(.respected)
        try await Task.sleep(for: .milliseconds(150))
        let entry = try await saved(database).days.first { $0.day == day }
        #expect(entry?.status == .respected)
        #expect(entry?.source == .confirm)
    }

    @Test("i numeri si salvano da soli e la fonte diventa «a mano»; svuotarli torna alla conferma")
    func numbersAutosave() async throws {
        let (model, _, database) = try await make()
        model.setStatus(.notRespected)
        model.kcal = "3100,5"
        model.protein = "150"
        model.numbersChanged()
        try await Task.sleep(for: .milliseconds(200))
        var entry = try await saved(database).days.first { $0.day == day }
        #expect(entry?.intake.kcal == 3100.5)
        #expect(entry?.source == .manual)
        model.kcal = ""
        model.protein = ""
        model.numbersChanged()
        try await Task.sleep(for: .milliseconds(200))
        entry = try await saved(database).days.first { $0.day == day }
        #expect(entry?.source == .confirm)
        #expect(entry?.status == .notRespected)
    }

    @Test("flush salva subito quello che è in attesa")
    func flushNow() async throws {
        let (model, _, database) = try await make()
        model.setStatus(.respected)
        try await Task.sleep(for: .milliseconds(100))
        model.carbs = "280"
        model.numbersChanged()
        await model.flush()
        #expect(try await saved(database).days.first { $0.day == day }?.intake.carbsG == 280)
    }

    @Test("«Togli questo giorno» lo riporta a non registrato")
    func removeDay() async throws {
        let (model, _, database) = try await make()
        model.setStatus(.respected)
        try await Task.sleep(for: .milliseconds(100))
        await model.remove()
        #expect(model.status == nil)
        #expect(try await saved(database).days.first { $0.day == day }?.status == nil)
    }

    @Test("senza consenso lo dice e non salva")
    func withoutConsent() async throws {
        let (model, _, database) = try await make(consent: false)
        model.setStatus(.respected)
        try await Task.sleep(for: .milliseconds(150))
        #expect(model.error == "Per registrare i macro serve il tuo consenso.")
        #expect(try await saved(database).days.allSatisfy { $0.status == nil })
    }

    @Test("riaprire un giorno riporta i numeri registrati nei campi")
    func reopen() async throws {
        let entry = DayEntry(
            day: day, status: .respected, source: .manual, intake: MacroIntake(kcal: 2480, proteinG: 176.5), target: nil)
        let (model, _, _) = try await make(entry: entry)
        #expect(model.kcal == "2480")
        #expect(model.protein == "176,5")
        #expect(model.status == .respected)
    }
}
