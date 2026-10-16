import Domain
import Foundation
import GRDB
import Testing

@testable import Gradus

@MainActor
struct ProfileStoreTests {
    private func make() async throws -> (FakeRemote, AppDatabase, ProfileStore) {
        let remote = FakeRemote()
        Sample.populate(remote)
        let database = try AppDatabase.inMemory()
        _ = try await SyncEngine(remote: remote, database: database).sync()
        return (remote, database, ProfileStore(database: database, remote: remote))
    }

    private func localName(_ database: AppDatabase) async throws -> String? {
        try await database.writer.read { try ProfileRecord.fetchOne($0, key: Sample.athlete)?.fullName }
    }

    @Test("il nome si ripulisce, va al server e poi sul telefono")
    func savesEverywhere() async throws {
        let (remote, database, store) = try await make()
        let saved = try await store.setName("  Marco   Bianchi ", userID: Sample.athlete)
        #expect(saved == "Marco Bianchi")
        #expect(remote.names[Sample.athlete] == "Marco Bianchi")
        #expect(try await localName(database) == "Marco Bianchi")
    }

    @Test("senza rete non si dà per salvato: il telefono resta com'era")
    func offline() async throws {
        let (remote, database, store) = try await make()
        remote.failOnName = URLError(.notConnectedToInternet)
        await #expect(throws: URLError.self) { try await store.setName("Marco Bianchi", userID: Sample.athlete) }
        #expect(try await localName(database) == "Marco Rossi")  // quello di prima
    }

    @Test("un nome vuoto non parte")
    func empty() async throws {
        let (remote, _, store) = try await make()
        await #expect(throws: ProfileStore.NameError.empty) { try await store.setName("   ", userID: Sample.athlete) }
        #expect(remote.names.isEmpty)
    }

    @Test("lo stato dell'account chiede il nome solo se il profilo è arrivato e il nome manca")
    func gateNeedsName() async throws {
        let remote = FakeRemote()
        Sample.populate(remote)
        var profiles = remote.rows(.profiles)
        profiles[0]["full_name"] = NSNull()
        remote.set(.profiles, profiles)
        let database = try AppDatabase.inMemory()
        let status = AccountStatus()
        let watching = Task { await status.watch(database: database, userID: Sample.athlete) }
        try await Task.sleep(for: .milliseconds(100))
        #expect(!status.needsName)  // il profilo non è ancora arrivato: non si chiede
        _ = try await SyncEngine(remote: remote, database: database).sync()
        try await Task.sleep(for: .milliseconds(150))
        #expect(status.needsName)
        _ = try await ProfileStore(database: database, remote: remote).setName("Marco", userID: Sample.athlete)
        try await Task.sleep(for: .milliseconds(150))
        #expect(!status.needsName)
        watching.cancel()
    }
}
