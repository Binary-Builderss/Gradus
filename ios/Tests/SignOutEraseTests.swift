import Domain
import Foundation
import Testing

@testable import Gradus

@MainActor
struct SignOutEraseTests {
    private func databaseWithASet() async throws -> AppDatabase {
        let database = try AppDatabase.inMemory()
        try await ExecutionStore(database: database).save(
            SetEdit(
                athleteID: Sample.athlete, mesocycleID: Sample.mesocycle, sessionID: Sample.session, week: 1, blockID: Sample.top,
                setIdx: 0, segments: [Segment(loadKg: 100, reps: 5)], effort: nil))
        return database
    }

    private func unsent(_ database: AppDatabase) throws -> Int {
        try database.writer.read { try ExecutionStore.unsentSets($0) }
    }

    private func defaults() -> UserDefaults { UserDefaults(suiteName: "erase-\(UUID())")! }

    @Test("all'uscita i dati dell'utente vanno via e non resta nessun segno")
    func erasesOnSignOut() async throws {
        let database = try await databaseWithASet()
        let defaults = defaults()
        #expect(try unsent(database) == 1)
        AppEnvironment.eraseOnSignOut(database, defaults: defaults)
        #expect(try unsent(database) == 0)
        #expect(!defaults.bool(forKey: AppEnvironment.pendingEraseKey))
    }

    @Test("un'uscita rimasta a metà si finisce all'avvio, prima di aprire i dati")
    func finishesPendingEraseAtLaunch() async throws {
        let database = try await databaseWithASet()
        let defaults = defaults()
        defaults.set(true, forKey: AppEnvironment.pendingEraseKey)
        let opened = try AppEnvironment.openDatabase(onDisk: { database }, defaults: defaults)
        #expect(try unsent(opened) == 0)
        #expect(!defaults.bool(forKey: AppEnvironment.pendingEraseKey))
    }

    @Test("senza uscita in sospeso i dati restano")
    func keepsDataOtherwise() async throws {
        let database = try await databaseWithASet()
        let opened = try AppEnvironment.openDatabase(onDisk: { database }, defaults: defaults())
        #expect(try unsent(opened) == 1)
    }

    @Test("se il database su disco non si apre, se ne usa uno vuoto in memoria")
    func fallsBackToMemory() throws {
        struct Broken: Error {}
        let opened = try AppEnvironment.openDatabase(onDisk: { throw Broken() }, defaults: defaults())
        #expect(try unsent(opened) == 0)
    }
}
