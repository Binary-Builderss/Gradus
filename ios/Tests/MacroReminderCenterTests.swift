import Domain
import Foundation
import GRDB
import Testing

@testable import Gradus

actor FakeReminderNotifier: ReminderNotifier {
    private(set) var items: [MacroReminder.Item] = []
    private(set) var replaceCalls = 0
    var allowed = true

    func setAllowed(_ value: Bool) { allowed = value }
    func authorizeIfNeeded() -> Bool { allowed }
    func replace(with items: [MacroReminder.Item]) {
        self.items = items
        replaceCalls += 1
    }
}

@MainActor
struct MacroReminderCenterTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }

    /// Venerdì 16 ottobre 2026, ore 9.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 9))! }

    private func make(consent: Bool = true) async throws -> (MacroReminderCenter, FakeReminderNotifier, AppDatabase, FakeRemote) {
        let remote = FakeRemote()
        Sample.populate(remote)
        if consent {
            var profiles = remote.rows(.profiles)
            profiles[0]["nutrition_consent_at"] = "2026-10-10T10:00:00.000+00:00"
            remote.set(.profiles, profiles)
        }
        let database = try AppDatabase.inMemory()
        _ = try await SyncEngine(remote: remote, database: database).sync()
        let notifier = FakeReminderNotifier()
        let fixedNow = now
        let center = MacroReminderCenter(
            database: database, remote: remote, notifier: notifier, defaults: UserDefaults(suiteName: "reminder-\(UUID())")!,
            now: { fixedNow }, calendar: calendar)
        return (center, notifier, database, remote)
    }

    private func register(_ day: String, in database: AppDatabase, remote: FakeRemote) async throws {
        try await NutritionStore(database: database, remote: remote).save(
            DayEdit(athleteID: Sample.athlete, day: day, status: .respected, intake: MacroIntake()), today: now, calendar: calendar)
    }

    @Test("acceso di default alle 22:00: i prossimi 14 giorni, a cominciare da oggi")
    func defaultSchedule() async throws {
        let (center, notifier, _, _) = try await make()
        #expect(center.enabled && center.minutes == 22 * 60)
        await center.setUser(Sample.athlete)
        let items = await notifier.items
        #expect(items.count == 14)
        #expect(items.first?.day == "2026-10-16")
        #expect(items.first?.fireDate == calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 22)))
    }

    @Test("senza consenso non si programma nulla")
    func noConsentNoReminder() async throws {
        let (center, notifier, _, _) = try await make(consent: false)
        await center.setUser(Sample.athlete)
        #expect(await notifier.items.isEmpty)
    }

    @Test("spento dall'atleta: niente; riacceso: torna")
    func toggle() async throws {
        let (center, notifier, _, _) = try await make()
        await center.setUser(Sample.athlete)
        await center.setEnabled(false)
        #expect(await notifier.items.isEmpty)
        await center.setEnabled(true)
        #expect(await notifier.items.count == 14)
    }

    @Test("senza il permesso delle notifiche non si programma nulla")
    func permissionDenied() async throws {
        let (center, notifier, _, _) = try await make()
        await notifier.setAllowed(false)
        await center.setUser(Sample.athlete)
        #expect(await notifier.items.isEmpty)
    }

    @Test("l'orario è personalizzabile")
    func customTime() async throws {
        let (center, notifier, _, _) = try await make()
        await center.setUser(Sample.athlete)
        await center.setMinutes(21 * 60 + 30)
        #expect(center.minutes == 21 * 60 + 30)
        #expect(await notifier.items.first?.fireDate == calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 21, minute: 30)))
    }

    @Test("un giorno già registrato non riceve il promemoria")
    func skipsRegistered() async throws {
        let (center, notifier, database, remote) = try await make()
        await center.setUser(Sample.athlete)
        try await register("2026-10-16", in: database, remote: remote)
        await center.refresh()
        let days = await notifier.items.map(\.day)
        #expect(!days.contains("2026-10-16"))
        #expect(days.first == "2026-10-17")
    }

    @Test("all'uscita si toglie tutto")
    func signOut() async throws {
        let (center, notifier, _, _) = try await make()
        await center.setUser(Sample.athlete)
        await center.setUser(nil)
        #expect(await notifier.items.isEmpty)
    }

    @Test("«Sì» dalla notifica registra la giornata come rispettata, senza altro")
    func yesAction() async throws {
        let (center, _, database, _) = try await make()
        await center.setUser(Sample.athlete)
        await center.handle(.yes, day: "2026-10-16")
        let entry = try await database.writer.read { [now, calendar] in
            try NutritionStore.snapshot($0, athleteID: Sample.athlete, today: now, calendar: calendar).days.first { $0.day == "2026-10-16" }
        }
        #expect(entry?.status == .respected)
        #expect(entry?.intake.isEmpty == true)
        #expect(center.coordinator.askManualEntry == nil)
    }

    @Test("«No» registra non rispettati e chiede se inserire i numeri")
    func noAction() async throws {
        let (center, _, database, _) = try await make()
        await center.setUser(Sample.athlete)
        await center.handle(.no, day: "2026-10-16")
        let entry = try await database.writer.read { [now, calendar] in
            try NutritionStore.snapshot($0, athleteID: Sample.athlete, today: now, calendar: calendar).days.first { $0.day == "2026-10-16" }
        }
        #expect(entry?.status == .notRespected)
        #expect(center.coordinator.askManualEntry == "2026-10-16")
    }

    @Test("il tocco sulla notifica apre il giorno")
    func openAction() async throws {
        let (center, _, _, _) = try await make()
        await center.setUser(Sample.athlete)
        await center.handle(.open, day: "2026-10-15")
        #expect(center.coordinator.openDay == "2026-10-15")
    }

    @Test("senza consenso «Sì» non scrive nulla")
    func yesWithoutConsent() async throws {
        let (center, _, database, _) = try await make(consent: false)
        await center.setUser(Sample.athlete)
        await center.handle(.yes, day: "2026-10-16")
        let count = try await database.writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM nutrition_days") ?? 0 }
        #expect(count == 0)
    }
}
