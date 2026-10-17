import Domain
import Foundation
import GRDB
import Testing

@testable import Gradus

struct BrandingTests {
    private func make() throws -> (FakeRemote, AppDatabase, SyncEngine) {
        let remote = FakeRemote()
        let database = try AppDatabase.inMemory()
        return (remote, database, SyncEngine(remote: remote, database: database))
    }

    private func row(colors: [String: String] = ["primary": "#112233"], name: String? = "Studio Verdi", logo: String? = nil) -> [String: Any] {
        [
            "coach_id": Sample.coach.uuidString, "brand_name": name ?? NSNull(), "logo_png": logo ?? NSNull(),
            "colors": colors, "hide_gradus_credit": false, "updated_at": "2026-10-16T10:00:00+00:00",
        ]
    }

    private func current(_ database: AppDatabase) throws -> Branding {
        try database.writer.read { try BrandingStore.current($0) }
    }

    @Test("il marchio del coach arriva sul telefono con nome e colori")
    func downloadsBranding() async throws {
        let (remote, database, engine) = try make()
        Sample.populate(remote)
        remote.setBranding([row()])
        _ = try await engine.sync()
        let branding = try current(database)
        #expect(branding.name == "Studio Verdi")
        #expect(branding.palette.primary == RGB(red: 0x11, green: 0x22, blue: 0x33))
        #expect(branding.palette.background == nil)
    }

    @Test("se il coach perde la personalizzazione il marchio sparisce anche dal telefono")
    func removedWhenServerStopsShowingIt() async throws {
        let (remote, database, engine) = try make()
        Sample.populate(remote)
        remote.setBranding([row()])
        _ = try await engine.sync()
        remote.setBranding([])
        _ = try await engine.sync()
        #expect(try current(database) == .standard)
    }

    @Test("una seconda sincronizzazione non duplica e aggiorna i colori")
    func updatesInPlace() async throws {
        let (remote, database, engine) = try make()
        Sample.populate(remote)
        remote.setBranding([row()])
        _ = try await engine.sync()
        remote.setBranding([row(colors: ["primary": "#445566", "background": "#FAFAFA"])])
        _ = try await engine.sync()
        let count = try await database.writer.read { try CoachBrandingRecord.fetchCount($0) }
        #expect(count == 1)
        #expect(try current(database).palette.background == RGB(red: 0xFA, green: 0xFA, blue: 0xFA))
    }

    @Test("all'uscita il marchio del coach non resta")
    func erasedOnSignOut() async throws {
        let (remote, database, engine) = try make()
        Sample.populate(remote)
        remote.setBranding([row()])
        _ = try await engine.sync()
        try database.erase()
        #expect(try current(database) == .standard)
    }

    @Test("un errore sul marchio si segnala, ma le serie dell'atleta partono lo stesso")
    func brandingFailureIsReported() async throws {
        let (remote, _, engine) = try make()
        Sample.populate(remote)
        remote.failOnBranding = URLError(.notConnectedToInternet)
        await #expect(throws: URLError.self) { _ = try await engine.sync() }
    }

    @Test("nome vuoto e logo non valido valgono come assenti")
    func blankNameAndBadLogo() {
        let record = CoachBrandingRecord(
            coachId: Sample.coach, brandName: "   ", logoPng: "non è base64!", colors: [:], hideGradusCredit: false, updatedAt: "")
        let branding = Branding(record)
        #expect(branding.name == nil)
        #expect(branding.logo == nil)
        #expect(branding.palette == .standard)
    }

    @Test("il logo in base64 si decodifica")
    func decodesLogo() {
        let bytes = Data([1, 2, 3, 4])
        let record = CoachBrandingRecord(
            coachId: Sample.coach, brandName: "X", logoPng: bytes.base64EncodedString(), colors: [:], hideGradusCredit: false, updatedAt: "")
        #expect(Branding(record).logo == bytes)
    }
}
