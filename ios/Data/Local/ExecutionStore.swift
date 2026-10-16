import Domain
import Foundation
import GRDB

/// Una modifica a una serie, come la scrive l'atleta: tutti i segmenti (carico × ripetizioni) e lo sforzo.
struct SetEdit: Equatable, Sendable {
    var athleteID: UUID
    var mesocycleID: UUID
    var sessionID: UUID
    var week: Int
    var blockID: UUID
    var setIdx: Int
    var segments: [Segment]
    var effort: Effort?

    /// Una serie esiste solo se contiene dati: svuotare tutti i campi la cancella.
    var hasData: Bool { effort != nil || segments.contains { $0.loadKg != nil || $0.reps != nil } }
}

/// Scritture e letture dell'esecuzione sul database locale. Il salvataggio è sempre locale e immediato; l'invio al
/// server passa dalla coda (`pending_push`) e si può rifare quante volte si vuole: gli id sono derivati dalla chiave
/// naturale, quindi lo stesso dato è sempre lo stesso upsert.
struct ExecutionStore: Sendable {
    let database: AppDatabase

    // MARK: Scrittura

    func save(_ edit: SetEdit, at date: Date = .now) async throws {
        try await database.writer.write { db in try Self.apply(edit, at: Self.timestamp(date), in: db) }
    }

    static func apply(_ edit: SetEdit, at now: String, in db: Database) throws {
        let workoutID = DeterministicID.workout(sessionID: edit.sessionID, week: edit.week)
        let logID = DeterministicID.setLog(workoutID: workoutID, blockID: edit.blockID, setIdx: edit.setIdx)
        let existing = try SetLogRecord.fetchOne(db, key: logID)
        let segmentIDs = edit.segments.indices.map { DeterministicID.segment(setLogID: logID, segIdx: $0) }
        let oldSegments = try SetSegmentRecord.filter(Column("set_log_id") == logID).fetchAll(db)

        guard edit.hasData else {
            // Tutto vuoto: la serie sparisce (se c'era), e con lei la seduta se era l'ultima.
            guard var log = existing, log.deletedAt == nil else { return }
            log.deletedAt = now
            log.updatedAt = now
            try log.update(db)
            try enqueue(.setLogs, log.id, in: db)
            for var segment in oldSegments where segment.deletedAt == nil {
                segment.deletedAt = now
                segment.updatedAt = now
                try segment.update(db)
                try enqueue(.setSegments, segment.id, in: db)
            }
            try retireWorkoutIfEmpty(workoutID, at: now, in: db)
            return
        }

        let effortValue = edit.effort?.value
        let effortScale = edit.effort?.scale.rawValue
        let liveOld = oldSegments.filter { $0.deletedAt == nil }
        let unchanged =
            existing?.deletedAt == nil && existing?.effortValue == effortValue && existing?.effortScale == effortScale
            && Self.sameSegments(liveOld, edit.segments, ids: segmentIDs)
        if unchanged { return }

        // La seduta (workout) esiste dalla prima serie; se era stata ritirata (serie svuotate) si riprende.
        let storedWorkout = try WorkoutRecord.fetchOne(db, key: workoutID)
        if storedWorkout == nil || storedWorkout?.deletedAt != nil {
            try WorkoutRecord(
                id: workoutID, athleteId: edit.athleteID, mesocycleId: edit.mesocycleID, sessionId: edit.sessionID,
                week: edit.week, athleteNotes: storedWorkout?.athleteNotes, updatedAt: now, deletedAt: nil
            ).save(db)
            try enqueue(.workouts, workoutID, in: db)
        }

        let log = SetLogRecord(
            id: logID, athleteId: edit.athleteID, mesocycleId: edit.mesocycleID, workoutId: workoutID,
            blockId: edit.blockID, setIdx: edit.setIdx, effortValue: effortValue, effortScale: effortScale,
            doneAt: now, updatedAt: now, deletedAt: nil)
        try log.save(db)
        try enqueue(.setLogs, logID, in: db)

        let previous = Dictionary(oldSegments.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (index, segment) in edit.segments.enumerated() {
            let id = segmentIDs[index]
            if segment.loadKg == nil && segment.reps == nil {
                guard var old = previous[id], old.deletedAt == nil else { continue }
                old.deletedAt = now
                old.updatedAt = now
                try old.update(db)
                try enqueue(.setSegments, id, in: db)
            } else {
                try SetSegmentRecord(
                    id: id, athleteId: edit.athleteID, setLogId: logID, segIdx: index, loadKg: segment.loadKg,
                    reps: segment.reps, updatedAt: now, deletedAt: nil
                ).save(db)
                try enqueue(.setSegments, id, in: db)
            }
        }
        // Segmenti in coda oltre quelli attuali (l'atleta ne ha tolto uno): si ritirano.
        for var old in oldSegments where old.segIdx >= edit.segments.count && old.deletedAt == nil {
            old.deletedAt = now
            old.updatedAt = now
            try old.update(db)
            try enqueue(.setSegments, old.id, in: db)
        }
    }

    private static func sameSegments(_ stored: [SetSegmentRecord], _ edited: [Segment], ids: [UUID]) -> Bool {
        let wanted = edited.enumerated().filter { $0.element.loadKg != nil || $0.element.reps != nil }
        guard stored.count == wanted.count else { return false }
        let byIndex = Dictionary(stored.map { ($0.segIdx, $0) }, uniquingKeysWith: { first, _ in first })
        return wanted.allSatisfy { index, segment in
            guard let row = byIndex[index] else { return false }
            return row.loadKg == segment.loadKg && row.reps == segment.reps
        }
    }

    private static func retireWorkoutIfEmpty(_ workoutID: UUID, at now: String, in db: Database) throws {
        let live = try Int.fetchOne(
            db, sql: "SELECT COUNT(*) FROM set_logs WHERE workout_id = ? AND deleted_at IS NULL", arguments: [workoutID]) ?? 0
        guard live == 0, var workout = try WorkoutRecord.fetchOne(db, key: workoutID), workout.deletedAt == nil else { return }
        workout.deletedAt = now
        workout.updatedAt = now
        try workout.update(db)
        try enqueue(.workouts, workoutID, in: db)
    }

    static func enqueue(_ table: SyncTable, _ id: UUID, in db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO pending_push (table_name, row_id, version) VALUES (?, ?, 1)
                ON CONFLICT (table_name, row_id) DO UPDATE SET version = version + 1
                """,
            arguments: [table.rawValue, id])
    }

    // MARK: Lettura

    /// Le serie registrate di una seduta, di tutte le settimane (servono la corrente e quelle di riferimento).
    func loggedSets(mesocycleID: UUID, sessionID: UUID) async throws -> [LoggedSet] {
        try await database.writer.read { db in try Self.loggedSets(db, mesocycleID: mesocycleID, sessionID: sessionID) }
    }

    static func loggedSets(_ db: Database, mesocycleID: UUID, sessionID: UUID) throws -> [LoggedSet] {
        let logs = try Row.fetchAll(
            db,
            sql: """
                SELECT l.id, l.block_id, l.set_idx, l.effort_value, l.effort_scale, w.week
                FROM set_logs l JOIN workouts w ON w.id = l.workout_id
                WHERE l.deleted_at IS NULL AND w.deleted_at IS NULL AND w.session_id = ? AND w.mesocycle_id = ?
                ORDER BY w.week, l.block_id, l.set_idx
                """,
            arguments: [sessionID, mesocycleID])
        let ids: [UUID] = logs.map { $0["id"] }
        let segments = try SetSegmentRecord
            .filter(ids.contains(Column("set_log_id")) && Column("deleted_at") == nil)
            .order(Column("seg_idx")).fetchAll(db)
        let byLog = Dictionary(grouping: segments, by: \.setLogId)
        return logs.map { row in
            let id: UUID = row["id"]
            let value: Double? = row["effort_value"]
            let scale: String? = row["effort_scale"]
            return LoggedSet(
                mesocycleID: mesocycleID, sessionID: sessionID, blockID: row["block_id"], week: row["week"],
                setIdx: row["set_idx"],
                segments: (byLog[id] ?? []).map { Segment(loadKg: $0.loadKg, reps: $0.reps) },
                effort: value.flatMap { v in scale.flatMap(EffortScale.init(rawValue:)).map { Effort(value: v, scale: $0) } })
        }
    }

    /// Quante serie sono registrate per ogni blocco di una seduta in una settimana.
    static func loggedCounts(_ db: Database, sessionID: UUID, week: Int) throws -> [UUID: Int] {
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT l.block_id, COUNT(*) AS n FROM set_logs l JOIN workouts w ON w.id = l.workout_id
                WHERE l.deleted_at IS NULL AND w.deleted_at IS NULL AND w.session_id = ? AND w.week = ?
                GROUP BY l.block_id
                """,
            arguments: [sessionID, week])
        return Dictionary(uniqueKeysWithValues: rows.map { (row: Row) -> (UUID, Int) in (row["block_id"], row["n"]) })
    }

    // MARK: Coda di invio

    static func pendingCount(_ db: Database) throws -> Int {
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM pending_push") ?? 0
    }

    /// Le righe da inviare per una tabella: (id, versione) per poterle togliere dalla coda solo se non cambiate nel frattempo.
    static func pending(_ db: Database, table: SyncTable, limit: Int) throws -> [(id: UUID, version: Int)] {
        try Row.fetchAll(
            db, sql: "SELECT row_id, version FROM pending_push WHERE table_name = ? ORDER BY rowid LIMIT ?",
            arguments: [table.rawValue, limit]
        ).map { (id: $0["row_id"], version: $0["version"]) }
    }

    static func clearPending(_ db: Database, table: SyncTable, _ sent: [(id: UUID, version: Int)]) throws {
        for item in sent {
            try db.execute(
                sql: "DELETE FROM pending_push WHERE table_name = ? AND row_id = ? AND version = ?",
                arguments: [table.rawValue, item.id, item.version])
        }
    }

    /// Le righe come JSON per il server, con tutte le colonne (anche `null`: PostgREST vuole le stesse chiavi in ogni
    /// riga) e senza `updated_at`, che scrive il server.
    static func payload(_ db: Database, table: SyncTable, ids: [UUID]) throws -> Data {
        let null = NSNull()
        let rows: [[String: Any]]
        switch table {
        case .workouts:
            rows = try WorkoutRecord.fetchAll(db, keys: ids).map {
                [
                    "id": $0.id.uuidString, "athlete_id": $0.athleteId.uuidString,
                    "mesocycle_id": $0.mesocycleId.uuidString, "session_id": $0.sessionId.uuidString,
                    "week": $0.week, "athlete_notes": $0.athleteNotes ?? null, "deleted_at": $0.deletedAt ?? null,
                ]
            }
        case .setLogs:
            rows = try SetLogRecord.fetchAll(db, keys: ids).map {
                [
                    "id": $0.id.uuidString, "athlete_id": $0.athleteId.uuidString,
                    "mesocycle_id": $0.mesocycleId.uuidString, "workout_id": $0.workoutId.uuidString,
                    "block_id": $0.blockId.uuidString, "set_idx": $0.setIdx,
                    "effort_value": $0.effortValue ?? null, "effort_scale": $0.effortScale ?? null,
                    "done_at": $0.doneAt, "deleted_at": $0.deletedAt ?? null,
                ]
            }
        case .setSegments:
            rows = try SetSegmentRecord.fetchAll(db, keys: ids).map {
                [
                    "id": $0.id.uuidString, "athlete_id": $0.athleteId.uuidString,
                    "set_log_id": $0.setLogId.uuidString, "seg_idx": $0.segIdx, "load_kg": $0.loadKg ?? null,
                    "reps": $0.reps ?? null, "deleted_at": $0.deletedAt ?? null,
                ]
            }
        default:
            rows = []
        }
        return try JSONSerialization.data(withJSONObject: rows)
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
