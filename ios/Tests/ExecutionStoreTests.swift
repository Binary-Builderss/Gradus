import Domain
import Foundation
import GRDB
import Testing

@testable import Gradus

struct ExecutionStoreTests {
    private func make() throws -> (FakeRemote, AppDatabase, ExecutionStore, SyncEngine) {
        let remote = FakeRemote()
        let database = try AppDatabase.inMemory()
        return (remote, database, ExecutionStore(database: database), SyncEngine(remote: remote, database: database))
    }

    private func edit(
        set: Int = 0, week: Int = 1, block: UUID = Sample.top, segments: [Segment] = [Segment(loadKg: 100, reps: 5)],
        effort: Effort? = nil
    ) -> SetEdit {
        SetEdit(
            athleteID: Sample.athlete, mesocycleID: Sample.mesocycle, sessionID: Sample.session, week: week,
            blockID: block, setIdx: set, segments: segments, effort: effort)
    }

    private func count(_ db: AppDatabase, _ table: String, live: Bool = true) throws -> Int {
        try db.writer.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM \(table)" + (live ? " WHERE deleted_at IS NULL" : "")) ?? 0
        }
    }

    @Test("la prima serie crea seduta, serie e segmento, e mette tutto in coda")
    func firstSet() async throws {
        let (_, database, store, _) = try make()
        try await store.save(edit(effort: Effort(value: 2, scale: .buf)))
        #expect(try count(database, "workouts") == 1)
        #expect(try count(database, "set_logs") == 1)
        #expect(try count(database, "set_segments") == 1)
        #expect(try await database.writer.read { try ExecutionStore.pendingCount($0) } == 3)
        let logged = try await store.loggedSets(mesocycleID: Sample.mesocycle, sessionID: Sample.session)
        #expect(logged.count == 1)
        #expect(logged[0].segments == [Segment(loadKg: 100, reps: 5)])
        #expect(logged[0].effort == Effort(value: 2, scale: .buf))
    }

    @Test("salvare due volte lo stesso valore non cambia nulla")
    func sameValueIsNoOp() async throws {
        let (_, database, store, engine) = try make()
        try await store.save(edit())
        _ = try await engine.push()
        try await store.save(edit())
        #expect(try await database.writer.read { try ExecutionStore.pendingCount($0) } == 0)
    }

    @Test("modificare riscrive la stessa riga, senza duplicati")
    func editInPlace() async throws {
        let (_, database, store, _) = try make()
        try await store.save(edit(segments: [Segment(loadKg: 100, reps: nil)]))
        try await store.save(edit(segments: [Segment(loadKg: 100, reps: 5)]))
        try await store.save(edit(segments: [Segment(loadKg: 102.5, reps: 5)]))
        #expect(try count(database, "set_logs") == 1)
        #expect(try count(database, "set_segments") == 1)
        let logged = try await store.loggedSets(mesocycleID: Sample.mesocycle, sessionID: Sample.session)
        #expect(logged[0].segments == [Segment(loadKg: 102.5, reps: 5)])
    }

    @Test("svuotare tutti i campi cancella la serie, e la seduta se era l'ultima")
    func emptyingDeletes() async throws {
        let (_, database, store, _) = try make()
        try await store.save(edit(set: 0))
        try await store.save(edit(set: 1, segments: [Segment(loadKg: 90, reps: 8)]))
        try await store.save(edit(set: 0, segments: [Segment(loadKg: nil, reps: nil)]))
        #expect(try count(database, "set_logs") == 1)
        #expect(try count(database, "workouts") == 1)
        try await store.save(edit(set: 1, segments: [Segment(loadKg: nil, reps: nil)]))
        #expect(try count(database, "set_logs") == 0)
        #expect(try count(database, "set_segments") == 0)
        #expect(try count(database, "workouts") == 0)
        // Riscrivere dopo averla svuotata la riprende.
        try await store.save(edit(set: 0))
        #expect(try count(database, "workouts") == 1)
        #expect(try count(database, "set_logs") == 1)
    }

    @Test("un drop set ha un segmento per riga; un segmento vuoto in mezzo non si salva")
    func segments() async throws {
        let (_, database, store, _) = try make()
        try await store.save(edit(segments: [Segment(loadKg: 100, reps: 8), Segment(loadKg: nil, reps: nil), Segment(loadKg: 60, reps: 6)]))
        #expect(try count(database, "set_segments") == 2)
        let logged = try await store.loggedSets(mesocycleID: Sample.mesocycle, sessionID: Sample.session)
        #expect(logged[0].segments == [Segment(loadKg: 100, reps: 8), Segment(loadKg: 60, reps: 6)])
        // Si toglie l'ultimo segmento: sparisce anche dal server (soft delete).
        try await store.save(edit(segments: [Segment(loadKg: 100, reps: 8)]))
        #expect(try count(database, "set_segments") == 1)
    }

    @Test("solo lo sforzo è già un dato")
    func effortOnly() async throws {
        let (_, database, store, _) = try make()
        try await store.save(edit(segments: [Segment(loadKg: nil, reps: nil)], effort: Effort(value: 8, scale: .rpe)))
        #expect(try count(database, "set_logs") == 1)
        #expect(try count(database, "set_segments") == 0)
    }

    @Test("l'invio è un upsert idempotente: due invii, le stesse righe, nessun duplicato sul server")
    func pushIsIdempotent() async throws {
        let (remote, database, store, engine) = try make()
        try await store.save(edit(effort: Effort(value: 2, scale: .buf)))
        #expect(try await engine.push() == 3)
        #expect(try await database.writer.read { try ExecutionStore.pendingCount($0) } == 0)
        // Rimettere in coda le stesse righe (come dopo un invio interrotto) e reinviare.
        try await database.writer.write { db in
            for table in [SyncTable.workouts, .setLogs, .setSegments] {
                for id in try UUID.fetchAll(db, sql: "SELECT id FROM \(table.rawValue)") { try ExecutionStore.enqueue(table, id, in: db) }
            }
        }
        #expect(try await engine.push() == 3)
        #expect(remote.rows(.workouts).count == 1)
        #expect(remote.rows(.setLogs).count == 1)
        #expect(remote.rows(.setSegments).count == 1)
    }

    @Test("l'ordine rispetta le chiavi esterne: seduta, serie, segmenti")
    func pushOrder() async throws {
        let (remote, _, store, engine) = try make()
        try await store.save(edit())
        _ = try await engine.push()
        #expect(remote.upsertCalls.map(\.table) == [.workouts, .setLogs, .setSegments])
    }

    @Test("senza rete la coda resta, e al ritorno parte tutto")
    func resumesAfterNetworkError() async throws {
        let (remote, database, store, engine) = try make()
        try await store.save(edit())
        remote.failOnUpsert = URLError(.notConnectedToInternet)
        await #expect(throws: URLError.self) { try await engine.push() }
        #expect(try await database.writer.read { try ExecutionStore.pendingCount($0) } == 3)
        remote.failOnUpsert = nil
        #expect(try await engine.push() == 3)
        #expect(try await database.writer.read { try ExecutionStore.pendingCount($0) } == 0)
    }

    @Test("il payload ha le stesse chiavi in ogni riga, anche i null, e niente updated_at")
    func payloadShape() async throws {
        let (remote, _, store, engine) = try make()
        try await store.save(edit(set: 0, segments: [Segment(loadKg: 100, reps: nil)]))
        try await store.save(edit(set: 1, segments: [Segment(loadKg: nil, reps: 8)], effort: Effort(value: 7, scale: .rpe)))
        _ = try await engine.push()  // il finto controlla chiavi uguali e assenza di updated_at
        #expect(remote.rows(.setLogs).count == 2)
    }

    @Test("dal server il pull riporta le serie su un telefono nuovo, e non sovrascrive quelle ancora da inviare")
    func pullKeepsPendingRows() async throws {
        let (remote, database, store, engine) = try make()
        Sample.populate(remote)
        try await store.save(edit(segments: [Segment(loadKg: 100, reps: 5)]))
        _ = try await engine.push()
        // Un altro telefono (database vuoto) riceve la stessa serie con lo stesso id.
        let other = try AppDatabase.inMemory()
        _ = try await SyncEngine(remote: remote, database: other).sync()
        let logged = try await ExecutionStore(database: other).loggedSets(mesocycleID: Sample.mesocycle, sessionID: Sample.session)
        #expect(logged.map(\.segments) == [[Segment(loadKg: 100, reps: 5)]])
        // Sul primo telefono si modifica senza rete; il pull non butta via la modifica.
        try await store.save(edit(segments: [Segment(loadKg: 105, reps: 5)]))
        _ = try? await engine.pullOnlyForTests()
        let mine = try await store.loggedSets(mesocycleID: Sample.mesocycle, sessionID: Sample.session)
        #expect(mine[0].segments == [Segment(loadKg: 105, reps: 5)])
        _ = database
    }
}
