import Domain
import Foundation
import GRDB
import Testing

@testable import Gradus

@MainActor
struct AccountStoreTests {
    private func make() async throws -> (FakeRemote, AppDatabase, AccountStore) {
        let remote = FakeRemote()
        Sample.populate(remote)
        let database = try AppDatabase.inMemory()
        _ = try await SyncEngine(remote: remote, database: database).sync()
        return (remote, database, AccountStore(database: database, remote: remote))
    }

    private func disabledAt(_ database: AppDatabase) async throws -> String? {
        try await database.writer.read { try ProfileRecord.fetchOne($0, key: Sample.athlete)?.disabledAt }
    }

    @Test("disattivare: va al server e il telefono cambia subito; riattivare lo toglie")
    func disableAndReactivate() async throws {
        let (remote, database, store) = try await make()
        try await store.disable(userID: Sample.athlete)
        #expect(remote.disabledCalls.map(\.disabled) == [true])
        #expect(try await disabledAt(database) != nil)
        try await store.reactivate(userID: Sample.athlete)
        #expect(remote.disabledCalls.map(\.disabled) == [true, false])
        #expect(try await disabledAt(database) == nil)
    }

    @Test("senza rete l'account non risulta disattivato sul telefono")
    func disableOffline() async throws {
        let (_, database, _) = try await make()
        let offline = AccountStore(database: database, remote: FailingDisableRemote())
        await #expect(throws: URLError.self) { try await offline.disable(userID: Sample.athlete) }
        #expect(try await disabledAt(database) == nil)
    }

    @Test("eliminare: l'email scritta a mano deve coincidere (senza badare a maiuscole), altrimenti non parte nulla")
    func deleteNeedsEmail() async throws {
        let (remote, _, store) = try await make()
        await #expect(throws: AccountDeletionError.confirmMismatch) {
            try await store.delete(typed: "altro@prova.dev", email: "marco@prova.dev")
        }
        #expect(remote.deleteCalls.isEmpty)
        try await store.delete(typed: " Marco@Prova.dev ", email: "marco@prova.dev")
        #expect(remote.deleteCalls == [" Marco@Prova.dev "])
    }

    @Test("un abbonamento attivo ferma l'eliminazione e lo dice")
    func subscriptionActive() async throws {
        let (remote, _, store) = try await make()
        remote.failOnDelete = .subscriptionActive
        await #expect(throws: AccountDeletionError.subscriptionActive) {
            try await store.delete(typed: "marco@prova.dev", email: "marco@prova.dev")
        }
    }
}

/// Un server che non risponde (senza rete).
private struct FailingDisableRemote: RemoteAPI {
    func fetchPage(table: SyncTable, since: String?, offset: Int, limit: Int) async throws -> Data { Data("[]".utf8) }
    func fetchIDs(table: SyncTable) async throws -> Data { Data("[]".utf8) }
    func upsert(table: SyncTable, rows: Data) async throws {}
    func updateName(userID: UUID, name: String) async throws {}
    func setNutritionConsent(userID: UUID, at date: Date?, version: String?) async throws {}
    func withdrawNutritionConsent() async throws {}
    func setAccountDisabled(userID: UUID, disabled: Bool) async throws { throw URLError(.notConnectedToInternet) }
    func deleteAccount(confirm: String) async throws {}
}
