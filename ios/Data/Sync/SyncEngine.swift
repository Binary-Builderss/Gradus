import Foundation
import GRDB

struct SyncSummary: Equatable, Sendable {
    /// Righe lette dal server (nuove o cambiate).
    var rows: Int
    /// Righe inviate al server (serie registrate dall'atleta).
    var sent: Int = 0
}

/// Pull incrementale dal server al database locale: per tabella, le righe con `updated_at >= ultimo cursore`.
/// Le scritture sono upsert sull'id, quindi rileggere le stesse righe non crea duplicati (per questo si usa `>=`: due
/// righe con lo stesso istante, una arrivata dopo il cursore, non si perdono). La programmazione è in sola lettura.
actor SyncEngine {
    private let remote: any RemoteAPI
    private let database: AppDatabase
    private let pageSize: Int

    init(remote: any RemoteAPI, database: AppDatabase, pageSize: Int = 1000) {
        self.remote = remote
        self.database = database
        self.pageSize = pageSize
    }

    func sync() async throws -> SyncSummary {
        var rows = 0
        for table in SyncTable.allCases {
            rows += try await pull(table)
            if table.removesRows { try await reconcile(table) }
        }
        // Prima si legge, poi si invia: un errore dell'invio non impedisce di ricevere il programma.
        let sent = try await push()
        return SyncSummary(rows: rows, sent: sent)
    }

    /// Solo la lettura dal server (per i test dell'ordine pull → push).
    func pullOnlyForTests() async throws -> Int {
        var rows = 0
        for table in SyncTable.allCases { rows += try await pull(table) }
        return rows
    }

    /// Invia le serie registrate sul telefono. Upsert sulla chiave primaria (derivata dalla chiave naturale): reinviare
    /// la stessa riga non crea duplicati. Una riga esce dalla coda solo se non è cambiata mentre si inviava.
    func push(batchSize: Int = 100) async throws -> Int {
        var sent = 0
        for table in SyncTable.allCases where table.isWrittenByAthlete {
            while true {
                try Task.checkCancellation()
                let batch = try await database.writer.read { try ExecutionStore.pending($0, table: table, limit: batchSize) }
                if batch.isEmpty { break }
                let payload = try await database.writer.read {
                    try ExecutionStore.payload($0, table: table, ids: batch.map(\.id))
                }
                try await remote.upsert(table: table, rows: payload)
                try await database.writer.write { try ExecutionStore.clearPending($0, table: table, batch) }
                sent += batch.count
            }
        }
        return sent
    }

    private func pull(_ table: SyncTable) async throws -> Int {
        let key = table.rawValue
        let since = try await database.writer.read { try SyncCursorRecord.fetchOne($0, key: key)?.cursor }
        var offset = 0
        var total = 0
        var cursor = since
        while true {
            try Task.checkCancellation()
            let data = try await remote.fetchPage(table: table, since: since, offset: offset, limit: pageSize)
            let page = try await database.writer.write { db in try Self.save(table, data, in: db) }
            total += page.count
            if let last = page.lastUpdatedAt { cursor = last }
            // Il cursore avanza a ogni pagina: se la rete cade a metà, si riparte da lì.
            if let cursor, cursor != since {
                try await database.writer.write { try SyncCursorRecord(tableName: key, cursor: cursor).upsert($0) }
            }
            if page.count < pageSize { break }
            offset += pageSize
        }
        return total
    }

    /// Le tabelle senza `deleted_at`: toglie dal telefono le righe che il server non mostra più all'atleta.
    private func reconcile(_ table: SyncTable) async throws {
        struct IDRow: Decodable { var id: UUID }
        let remoteIDs = Set(try JSONDecoder().decode([IDRow].self, from: try await remote.fetchIDs(table: table)).map(\.id))
        try await database.writer.write { db in
            let localIDs = try UUID.fetchAll(db, sql: "SELECT id FROM \(table.rawValue)")
            let gone = localIDs.filter { !remoteIDs.contains($0) }
            for id in gone {
                if table == .mesocycles {
                    try db.execute(
                        sql: "DELETE FROM set_segments WHERE set_log_id IN (SELECT id FROM set_logs WHERE mesocycle_id = ?)",
                        arguments: [id])
                    for child in ["sessions", "slot_groups", "slots", "set_blocks", "block_weeks", "workouts", "set_logs"] {
                        try db.execute(sql: "DELETE FROM \(child) WHERE mesocycle_id = ?", arguments: [id])
                    }
                }
                try db.execute(sql: "DELETE FROM \(table.rawValue) WHERE id = ?", arguments: [id])
            }
        }
    }

    private struct Page {
        var count: Int
        var lastUpdatedAt: String?
    }

    private static func save(_ table: SyncTable, _ data: Data, in db: Database) throws -> Page {
        switch table {
        case .profiles: try save(ProfileRecord.self, data, db)
        case .coachAthletes: try save(CoachLinkRecord.self, data, db)
        case .mesocycles: try save(MesocycleRecord.self, data, db)
        case .sessions: try save(SessionRecord.self, data, db)
        case .slotGroups: try save(SlotGroupRecord.self, data, db)
        case .exercises: try save(ExerciseRecord.self, data, db)
        case .slots: try save(SlotRecord.self, data, db)
        case .setBlocks: try save(SetBlockRecord.self, data, db)
        case .blockWeeks: try save(BlockWeekRecord.self, data, db)
        case .exerciseVideos: try save(ExerciseVideoRecord.self, data, db)
        case .workouts: try save(WorkoutRecord.self, data, table: table, db)
        case .setLogs: try save(SetLogRecord.self, data, table: table, db)
        case .setSegments: try save(SetSegmentRecord.self, data, table: table, db)
        }
    }

    private static func save<R: SyncedRecord>(
        _: R.Type, _ data: Data, table: SyncTable? = nil, _ db: Database
    ) throws -> Page {
        let rows = try JSONDecoder().decode([R].self, from: data)
        // Le righe scritte dall'atleta e ancora da inviare valgono più di quelle del server (un solo autore).
        let pending: Set<UUID> =
            table.map { Set((try? UUID.fetchAll(db, sql: "SELECT row_id FROM pending_push WHERE table_name = ?", arguments: [$0.rawValue])) ?? []) } ?? []
        for row in rows where !pending.contains(row.id) { try row.upsert(db) }
        return Page(count: rows.count, lastUpdatedAt: rows.last?.updatedAt)
    }
}
