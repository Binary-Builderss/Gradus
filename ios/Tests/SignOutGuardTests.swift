import Domain
import Foundation
import Testing

@testable import Gradus

@MainActor
struct SignOutGuardTests {
    private func make() throws -> (FakeRemote, AppDatabase, ExecutionStore, SyncEngine, SyncModel) {
        let remote = FakeRemote()
        let database = try AppDatabase.inMemory()
        let engine = SyncEngine(remote: remote, database: database)
        let model = SyncModel(engine: engine, defaults: UserDefaults(suiteName: "signout-\(UUID())")!)
        return (remote, database, ExecutionStore(database: database), engine, model)
    }

    private func save(_ store: ExecutionStore, set: Int) async throws {
        try await store.save(
            SetEdit(
                athleteID: Sample.athlete, mesocycleID: Sample.mesocycle, sessionID: Sample.session, week: 1, blockID: Sample.top,
                setIdx: set, segments: [Segment(loadKg: 100, reps: 5)], effort: nil))
    }

    @Test("con rete, prima di uscire le serie partono e non ne resta nessuna")
    func flushesWhenOnline() async throws {
        let (remote, _, store, engine, model) = try make()
        Sample.populate(remote)
        try await save(store, set: 0)
        try await save(store, set: 1)
        #expect(await engine.unsentSets() == 2)
        #expect(await model.flushBeforeSignOut() == 0)
        #expect(remote.rows(.setLogs).count == 2)
    }

    @Test("senza rete resta il conto delle serie che si perderebbero")
    func reportsUnsentWhenOffline() async throws {
        let (remote, _, store, _, model) = try make()
        Sample.populate(remote)
        try await save(store, set: 0)
        try await save(store, set: 1)
        try await save(store, set: 2)
        remote.failOnUpsert = URLError(.notConnectedToInternet)
        #expect(await model.flushBeforeSignOut() == 3)
        #expect(model.state == .failed)
    }

    @Test("se la lettura dal server fallisce, le serie partono lo stesso (e l'errore si segnala)")
    func pushesEvenIfPullFails() async throws {
        let (remote, _, store, engine, _) = try make()
        Sample.populate(remote)
        try await save(store, set: 0)
        remote.failOnPage = 1
        await #expect(throws: URLError.self) { try await engine.sync() }
        #expect(remote.rows(.setLogs).count == 1)
        #expect(await engine.unsentSets() == 0)
    }

    @Test("una modifica a una serie già inviata rimette in coda quella serie, una sola volta")
    func countsSetsNotRows() async throws {
        let (_, _, store, engine, _) = try make()
        try await save(store, set: 0)
        try await store.save(
            SetEdit(
                athleteID: Sample.athlete, mesocycleID: Sample.mesocycle, sessionID: Sample.session, week: 1, blockID: Sample.top,
                setIdx: 0, segments: [Segment(loadKg: 102.5, reps: 5)], effort: Effort(value: 2, scale: .buf)))
        #expect(await engine.unsentSets() == 1)  // la stessa serie, non tre righe
    }
}
