import Foundation
import GRDB
import Testing

@testable import Gradus

struct SyncEngineTests {
    private func make(pageSize: Int = 1000) throws -> (FakeRemote, AppDatabase, SyncEngine) {
        let remote = FakeRemote()
        let database = try AppDatabase.inMemory()
        return (remote, database, SyncEngine(remote: remote, database: database, pageSize: pageSize))
    }

    private func count(_ db: AppDatabase, _ table: String) throws -> Int {
        try db.writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM \(table)") ?? 0 }
    }

    @Test("la prima sincronizzazione porta tutta la programmazione sul telefono")
    func firstSync() async throws {
        let (remote, database, engine) = try make()
        Sample.populate(remote)
        let summary = try await engine.sync()
        #expect(summary.rows > 0)
        #expect(try count(database, "mesocycles") == 1)
        #expect(try count(database, "sessions") == 2)
        #expect(try count(database, "slots") == 2)
        #expect(try count(database, "set_blocks") == 2)
        #expect(try count(database, "block_weeks") == 3)
        let m = try await database.writer.read { try MesocycleRecord.fetchOne($0, key: Sample.mesocycle) }
        #expect(m?.deloadWeeks == [6])
        #expect(m?.startDate == "2026-10-05")
    }

    @Test("la seconda volta chiede solo da dove era arrivata, e non duplica nulla")
    func incrementalAndIdempotent() async throws {
        let (remote, database, engine) = try make()
        Sample.populate(remote)
        _ = try await engine.sync()
        remote.resetRequests()
        _ = try await engine.sync()  // stesso contenuto: le righe uguali al cursore si rileggono (>=) ma restano le stesse
        #expect(try count(database, "sessions") == 2)
        #expect(try count(database, "block_weeks") == 3)
        #expect(remote.pageRequests.allSatisfy { $0.table == .exerciseVideos || $0.table.isWrittenByAthlete || $0.since != nil })  // senza righe non c'è cursore
        #expect(remote.pageRequests.first { $0.table == .mesocycles }?.since == Sample.t(1))
    }

    @Test("una riga cambiata sul server si aggiorna, una nuova arriva")
    func updates() async throws {
        let (remote, database, engine) = try make()
        Sample.populate(remote)
        _ = try await engine.sync()
        var sessions = Sample.sessionsRows(remote)
        sessions[0]["name"] = "Spinta A"
        sessions[0]["updated_at"] = Sample.t(3)
        remote.set(.sessions, sessions)
        _ = try await engine.sync()
        let names = try await database.writer.read { try String.fetchAll($0, sql: "SELECT name FROM sessions ORDER BY position") }
        #expect(names == ["Spinta A", "Tirata"])
    }

    @Test("le pagine più piccole del totale si leggono tutte")
    func pagination() async throws {
        let (remote, database, engine) = try make(pageSize: 1)
        Sample.populate(remote)
        _ = try await engine.sync()
        #expect(try count(database, "sessions") == 2)
        #expect(try count(database, "block_weeks") == 3)
        #expect(remote.pageRequests.filter { $0.table == .blockWeeks }.count >= 3)
    }

    @Test("una riga eliminata sul server (deleted_at) resta nel database ma l'interfaccia non la vede")
    func softDelete() async throws {
        let (remote, database, engine) = try make()
        Sample.populate(remote)
        _ = try await engine.sync()
        var sessions = Sample.sessionsRows(remote)
        sessions[1]["deleted_at"] = Sample.t(4)
        sessions[1]["updated_at"] = Sample.t(4)
        remote.set(.sessions, sessions)
        _ = try await engine.sync()
        let home = try await database.writer.read { try ProgramQueries.home($0, athleteID: Sample.athlete) }
        #expect(home.sessions.map(\.name) == ["Spinta"])
    }

    @Test("un mesociclo che l'atleta non vede più sparisce, con tutto il suo contenuto")
    func reconcile() async throws {
        let (remote, database, engine) = try make()
        Sample.populate(remote)
        _ = try await engine.sync()
        // Come fa il server: con il mesociclo nascosto da RLS, non restituisce più nemmeno le sue righe.
        for table in [SyncTable.mesocycles, .sessions, .slotGroups, .slots, .setBlocks, .blockWeeks] { remote.set(table, []) }
        _ = try await engine.sync()
        #expect(try count(database, "mesocycles") == 0)
        #expect(try count(database, "sessions") == 0)
        #expect(try count(database, "set_blocks") == 0)
        #expect(try count(database, "block_weeks") == 0)
    }

    @Test("se la rete cade a metà, quello che era arrivato resta e si riparte da lì")
    func resumesAfterFailure() async throws {
        let (remote, database, engine) = try make()
        Sample.populate(remote)
        remote.failOnPage = 4  // dopo profiles, coach_athletes e mesocycles
        await #expect(throws: (any Error).self) { try await engine.sync() }
        #expect(try count(database, "profiles") == 2)
        #expect(try count(database, "mesocycles") == 1)
        #expect(try count(database, "sessions") == 0)
        remote.failOnPage = nil
        remote.resetRequests()
        _ = try await engine.sync()
        #expect(try count(database, "sessions") == 2)
        #expect(remote.pageRequests.first { $0.table == .mesocycles }?.since == Sample.t(1))
    }

    @Test("uscire dall'account svuota i dati locali")
    func erase() async throws {
        let (remote, database, engine) = try make()
        Sample.populate(remote)
        _ = try await engine.sync()
        try database.erase()
        #expect(try count(database, "mesocycles") == 0)
        #expect(try count(database, "profiles") == 0)
        #expect(try count(database, "sync_cursors") == 0)
        remote.resetRequests()
        _ = try await engine.sync()
        #expect(remote.pageRequests.allSatisfy { $0.since == nil })  // da capo, senza cursore
        #expect(try count(database, "mesocycles") == 1)
    }
}

extension Sample {
    static func sessionsRows(_ remote: FakeRemote) -> [[String: Any]] {
        [
            ["id": session.uuidString, "mesocycle_id": mesocycle.uuidString, "position": 0, "name": "Spinta", "coach_notes": NSNull(), "updated_at": t(1), "deleted_at": NSNull()],
            ["id": session2.uuidString, "mesocycle_id": mesocycle.uuidString, "position": 1, "name": "Tirata", "coach_notes": NSNull(), "updated_at": t(1), "deleted_at": NSNull()],
        ]
    }
}
