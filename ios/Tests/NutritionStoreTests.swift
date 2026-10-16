import Domain
import Foundation
import GRDB
import Testing

@testable import Gradus

@MainActor
struct NutritionStoreTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }

    private var today: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 12))! }

    private func make(consent: Bool = true) async throws -> (FakeRemote, AppDatabase, NutritionStore, SyncEngine) {
        let remote = FakeRemote()
        Sample.populate(remote)
        if consent {
            var profiles = remote.rows(.profiles)
            profiles[0]["nutrition_consent_at"] = "2026-10-10T10:00:00.000+00:00"
            profiles[0]["nutrition_consent_version"] = "2026-10-16"
            remote.set(.profiles, profiles)
        }
        let database = try AppDatabase.inMemory()
        let engine = SyncEngine(remote: remote, database: database)
        _ = try await engine.sync()
        return (remote, database, NutritionStore(database: database, remote: remote), engine)
    }

    private func edit(_ day: String = "2026-10-15", _ status: MacroDayStatus = .respected, _ intake: MacroIntake = MacroIntake()) -> DayEdit {
        DayEdit(athleteID: Sample.athlete, day: day, status: status, intake: intake)
    }

    private func snapshot(_ database: AppDatabase) async throws -> NutritionSnapshot {
        try await database.writer.read { [today, calendar] in
            try NutritionStore.snapshot($0, athleteID: Sample.athlete, today: today, calendar: calendar)
        }
    }

    private func pending(_ database: AppDatabase) async throws -> Int {
        try await database.writer.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM pending_push WHERE table_name = 'nutrition_days'") ?? 0
        }
    }

    @Test("senza consenso non si registra nulla")
    func needsConsent() async throws {
        let (_, database, store, _) = try await make(consent: false)
        await #expect(throws: NutritionStore.StoreError.noConsent) { try await store.save(edit(), today: today, calendar: calendar) }
        #expect(try await snapshot(database).consent == false)
        #expect(try await pending(database) == 0)
    }

    @Test("una conferma senza numeri è un giorno verde, fonte «confirm», e va in coda")
    func confirmDay() async throws {
        let (_, database, store, _) = try await make()
        try await store.save(edit(), today: today, calendar: calendar)
        let entry = try await snapshot(database).days.first { $0.day == "2026-10-15" }
        #expect(entry?.status == .respected)
        #expect(entry?.source == .confirm)
        #expect(entry?.intake.isEmpty == true)
        #expect(try await pending(database) == 1)
    }

    @Test("con i numeri la fonte è «manual»; si corregge senza duplicare")
    func manualDayAndEdit() async throws {
        let (_, database, store, _) = try await make()
        try await store.save(edit("2026-10-14", .notRespected, MacroIntake(kcal: 3100, proteinG: 150)), today: today, calendar: calendar)
        try await store.save(edit("2026-10-14", .respected, MacroIntake(kcal: 2550, proteinG: 175, carbsG: 280, fatG: 70)), today: today, calendar: calendar)
        let count = try await database.writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM nutrition_days") ?? 0 }
        #expect(count == 1)
        let entry = try await snapshot(database).days.first { $0.day == "2026-10-14" }
        #expect(entry?.status == .respected)
        #expect(entry?.source == .manual)
        #expect(entry?.intake.kcal == 2550)
    }

    @Test("salvare due volte lo stesso valore non rimette nulla in coda")
    func unchangedIsNoOp() async throws {
        let (_, database, store, engine) = try await make()
        try await store.save(edit(), today: today, calendar: calendar)
        _ = try await engine.push()
        try await store.save(edit(), today: today, calendar: calendar)
        #expect(try await pending(database) == 0)
    }

    @Test("toglierlo riporta il giorno a «non registrato» e lo ritira sul server")
    func clearDay() async throws {
        let (remote, database, store, engine) = try await make()
        try await store.save(edit(), today: today, calendar: calendar)
        _ = try await engine.push()
        try await store.clear(athleteID: Sample.athlete, day: "2026-10-15", today: today, calendar: calendar)
        #expect(try await snapshot(database).days.first { $0.day == "2026-10-15" }?.status == nil)
        _ = try await engine.push()
        #expect(remote.rows(.nutritionDays).first?["deleted_at"] is String)
    }

    @Test("si corregge solo entro 14 giorni e mai il futuro")
    func editableWindow() async throws {
        let (_, _, store, _) = try await make()
        await #expect(throws: NutritionStore.StoreError.notEditable) { try await store.save(edit("2026-10-01"), today: today, calendar: calendar) }
        await #expect(throws: NutritionStore.StoreError.notEditable) { try await store.save(edit("2026-10-17"), today: today, calendar: calendar) }
        try await store.save(edit("2026-10-16"), today: today, calendar: calendar)
    }

    @Test("l'invio è un upsert idempotente con tutte le chiavi e senza updated_at; un secondo invio non duplica")
    func pushIdempotent() async throws {
        let (remote, database, store, engine) = try await make()
        try await store.save(edit("2026-10-15"), today: today, calendar: calendar)
        try await store.save(edit("2026-10-14", .notRespected, MacroIntake(kcal: 3000)), today: today, calendar: calendar)
        #expect(try await engine.push() == 2)  // il finto controlla chiavi uguali e niente updated_at
        try await database.writer.write { db in
            for id in try UUID.fetchAll(db, sql: "SELECT id FROM nutrition_days") { try ExecutionStore.enqueue(.nutritionDays, id, in: db) }
        }
        #expect(try await engine.push() == 2)
        #expect(remote.rows(.nutritionDays).count == 2)
    }

    @Test("un giorno ancora da inviare non sparisce alla sincronizzazione, e un telefono nuovo riceve i giorni del server")
    func reconcileKeepsUnsent() async throws {
        let (remote, database, store, engine) = try await make()
        try await store.save(edit("2026-10-15"), today: today, calendar: calendar)
        _ = try await engine.sync()  // pull + reconcile + push
        #expect(remote.rows(.nutritionDays).count == 1)
        try await store.save(edit("2026-10-14", .notRespected, MacroIntake(kcal: 2000)), today: today, calendar: calendar)
        remote.failOnUpsert = URLError(.notConnectedToInternet)
        _ = try? await engine.sync()  // la lettura riesce, l'invio no: il giorno nuovo deve restare
        #expect(try await snapshot(database).days.filter { $0.status != nil }.count == 2)
        // un altro telefono
        let other = try AppDatabase.inMemory()
        remote.failOnUpsert = nil
        _ = try await SyncEngine(remote: remote, database: other).sync()
        let received = try await other.writer.read { [today, calendar] in
            try NutritionStore.snapshot($0, athleteID: Sample.athlete, today: today, calendar: calendar)
        }
        #expect(received.days.first { $0.day == "2026-10-15" }?.status == .respected)
    }

    @Test("consenso: va al server con la versione e poi sul telefono; ritirarlo cancella i giorni e la coda")
    func consentFlow() async throws {
        let (remote, database, store, _) = try await make(consent: false)
        try await store.grantConsent(userID: Sample.athlete)
        #expect(remote.consentCalls.first?.version == Nutrition.consentVersion)
        #expect(try await snapshot(database).consent)
        try await store.save(edit(), today: today, calendar: calendar)
        try await store.withdrawConsent(userID: Sample.athlete)
        #expect(remote.withdrawCalls == 1)
        let after = try await snapshot(database)
        #expect(after.consent == false)
        #expect(after.days.allSatisfy { $0.status == nil })
        #expect(try await pending(database) == 0)
    }

    @Test("senza rete il consenso non risulta dato")
    func consentOffline() async throws {
        let (remote, database, store, _) = try await make(consent: false)
        remote.failOnConsent = URLError(.notConnectedToInternet)
        await #expect(throws: URLError.self) { try await store.grantConsent(userID: Sample.athlete) }
        #expect(try await snapshot(database).consent == false)
    }

    @Test("l'obiettivo di oggi e quello di ogni giorno vengono dal piano in vigore quel giorno")
    func targets() async throws {
        let remote = FakeRemote()
        Sample.populate(remote)
        let plan = { (id: String, from: String, deleted: Bool) -> [String: Any] in
            ["id": id, "athlete_id": Sample.athlete.uuidString, "author_id": Sample.coach.uuidString, "kind": "macros", "valid_from": from,
             "tolerance_pct": 10, "declared_at": Sample.t(1), "declaration_version": "v1", "updated_at": Sample.t(1),
             "deleted_at": deleted ? Sample.t(2) : NSNull()]
        }
        let day = { (id: String, plan: String, kcal: Int) -> [String: Any] in
            ["id": id, "plan_id": plan, "day_type": "all", "kcal": kcal, "protein_g": 150, "carbs_g": 250, "fat_g": 70, "fiber_g": NSNull(), "updated_at": Sample.t(1)]
        }
        let p1 = "B1000000-0000-4000-8000-000000000001", p2 = "B1000000-0000-4000-8000-000000000002", p3 = "B1000000-0000-4000-8000-000000000003"
        remote.set(.nutritionPlans, [plan(p1, "2026-10-01", false), plan(p2, "2026-10-12", false), plan(p3, "2026-10-14", true)])
        remote.set(.nutritionPlanDays, [
            day("C1000000-0000-4000-8000-000000000001", p1, 2500), day("C1000000-0000-4000-8000-000000000002", p2, 2200),
            day("C1000000-0000-4000-8000-000000000003", p3, 1800),
        ])
        let database = try AppDatabase.inMemory()
        _ = try await SyncEngine(remote: remote, database: database).sync()
        let snap = try await snapshot(database)
        #expect(snap.today?.targets.kcal == 2200)  // il terzo è eliminato
        #expect(snap.days.first { $0.day == "2026-10-11" }?.target?.kcal == 2500)
        #expect(snap.days.first { $0.day == "2026-10-12" }?.target?.kcal == 2200)
        #expect(snap.days.first { $0.day == "2026-10-16" }?.target?.kcal == 2200)
        #expect(snap.days.count == 14)
    }
}
