import Foundation

@testable import Gradus

/// Un server finto: tiene le righe di ogni tabella e risponde come PostgREST (filtro `updated_at >= since`,
/// ordine per `updated_at` e `id`, paginazione con offset). Registra le richieste per i controlli.
final class FakeRemote: RemoteAPI, @unchecked Sendable {
    typealias Row = [String: Any]

    private let lock = NSLock()
    private var tables: [SyncTable: [Row]] = [:]
    private(set) var pageRequests: [(table: SyncTable, since: String?, offset: Int)] = []
    var failOnPage: Int?  // fa fallire la richiesta di pagina numero N (da 1)
    private var pageCount = 0
    private(set) var reactivated: [UUID] = []

    func set(_ table: SyncTable, _ rows: [Row]) {
        lock.withLock { tables[table] = rows }
    }

    func fetchPage(table: SyncTable, since: String?, offset: Int, limit: Int) async throws -> Data {
        try lock.withLock {
            pageCount += 1
            pageRequests.append((table, since, offset))
            if pageCount == failOnPage { throw URLError(.notConnectedToInternet) }
            let rows = (tables[table] ?? [])
                .filter { since == nil || ($0["updated_at"] as! String) >= since! }
                .sorted { (($0["updated_at"] as! String), ($0["id"] as! String)) < (($1["updated_at"] as! String), ($1["id"] as! String)) }
            let page = Array(rows.dropFirst(offset).prefix(limit))
            return try JSONSerialization.data(withJSONObject: page)
        }
    }

    func fetchIDs(table: SyncTable) async throws -> Data {
        try lock.withLock {
            try JSONSerialization.data(withJSONObject: (tables[table] ?? []).map { ["id": $0["id"] as! String] })
        }
    }

    private(set) var names: [UUID: String] = [:]
    var failOnName: Error?

    func updateName(userID: UUID, name: String) async throws {
        try lock.withLock {
            if let failOnName { throw failOnName }
            names[userID] = name
        }
    }

    func reactivateAccount(userID: UUID) async throws {
        lock.withLock { reactivated.append(userID) }
    }

    /// Come PostgREST: upsert sull'id (le chiavi devono essere uguali in ogni riga), `updated_at` lo assegna il server.
    private(set) var upsertCalls: [(table: SyncTable, count: Int)] = []
    var failOnUpsert: Error?
    private var serverClock = 100

    func upsert(table: SyncTable, rows: Data) async throws {
        try lock.withLock {
            if let failOnUpsert { throw failOnUpsert }
            let incoming = try JSONSerialization.jsonObject(with: rows) as! [Row]
            if let first = incoming.first {
                precondition(incoming.allSatisfy { Set($0.keys) == Set(first.keys) }, "All object keys must match")
                precondition(!first.keys.contains("updated_at"), "updated_at lo scrive il server")
            }
            upsertCalls.append((table, incoming.count))
            var stored = tables[table] ?? []
            for var row in incoming {
                serverClock += 1
                row["updated_at"] = Sample.t(1).replacingOccurrences(of: "T10:00:00", with: "T11:\(String(format: "%02d", serverClock % 60)):00")
                if let index = stored.firstIndex(where: { ($0["id"] as! String).lowercased() == (row["id"] as! String).lowercased() }) {
                    stored[index] = row
                } else {
                    stored.append(row)
                }
            }
            tables[table] = stored
        }
    }

    func rows(_ table: SyncTable) -> [Row] { lock.withLock { tables[table] ?? [] } }

    var requestCount: Int { lock.withLock { pageRequests.count } }
    func resetRequests() { lock.withLock { pageRequests = []; pageCount = 0 } }
}

/// Un programma d'esempio, con gli id fissi per poterli controllare.
enum Sample {
    static let athlete = UUID(uuidString: "A0000000-0000-4000-8000-000000000001")!
    static let coach = UUID(uuidString: "C0000000-0000-4000-8000-000000000001")!
    static let mesocycle = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
    static let session = UUID(uuidString: "20000000-0000-4000-8000-000000000001")!
    static let session2 = UUID(uuidString: "20000000-0000-4000-8000-000000000002")!
    static let group = UUID(uuidString: "30000000-0000-4000-8000-000000000001")!
    static let slot = UUID(uuidString: "40000000-0000-4000-8000-000000000001")!
    static let slot2 = UUID(uuidString: "40000000-0000-4000-8000-000000000002")!
    static let top = UUID(uuidString: "50000000-0000-4000-8000-000000000001")!
    static let backoff = UUID(uuidString: "50000000-0000-4000-8000-000000000002")!
    static let exercise = UUID(uuidString: "E0000000-0000-4000-8000-000000000001")!
    static let exercise2 = UUID(uuidString: "E0000000-0000-4000-8000-000000000002")!

    static func t(_ n: Int) -> String { String(format: "2026-10-%02dT10:00:00.123456+00:00", n) }

    static func populate(_ remote: FakeRemote, status: String = "active", day: Int = 1) {
        remote.set(.profiles, [
            ["id": athlete.uuidString, "email": "marco@prova.dev", "full_name": "Marco Rossi", "disabled_at": NSNull(), "updated_at": t(day)],
            ["id": coach.uuidString, "email": "giulia@prova.dev", "full_name": "Giulia Coach", "disabled_at": NSNull(), "updated_at": t(day)],
        ])
        remote.set(.coachAthletes, [
            ["id": "B0000000-0000-4000-8000-000000000001", "coach_id": coach.uuidString, "athlete_id": athlete.uuidString, "status": "active", "updated_at": t(day)]
        ])
        remote.set(.mesocycles, [
            ["id": mesocycle.uuidString, "athlete_id": athlete.uuidString, "name": "Ipertrofia 1", "start_date": "2026-10-05", "weeks": 6, "deload_weeks": [6], "status": status, "coach_notes": "Scalda bene", "updated_at": t(day)]
        ])
        remote.set(.sessions, [
            ["id": session.uuidString, "mesocycle_id": mesocycle.uuidString, "position": 0, "name": "Spinta", "coach_notes": NSNull(), "updated_at": t(day), "deleted_at": NSNull()],
            ["id": session2.uuidString, "mesocycle_id": mesocycle.uuidString, "position": 1, "name": "Tirata", "coach_notes": NSNull(), "updated_at": t(day), "deleted_at": NSNull()],
        ])
        remote.set(.slotGroups, [
            ["id": group.uuidString, "mesocycle_id": mesocycle.uuidString, "session_id": session.uuidString, "position": 0, "kind": "superset", "rest_between_s": 0, "rest_after_round_s": 90, "updated_at": t(day), "deleted_at": NSNull()]
        ])
        remote.set(.exercises, [
            ["id": exercise.uuidString, "owner_id": NSNull(), "name": "Panca piana", "notes": NSNull(), "updated_at": t(day), "deleted_at": NSNull()],
            ["id": exercise2.uuidString, "owner_id": NSNull(), "name": "Croci ai cavi", "notes": NSNull(), "updated_at": t(day), "deleted_at": NSNull()],
        ])
        remote.set(.slots, [
            ["id": slot.uuidString, "mesocycle_id": mesocycle.uuidString, "group_id": group.uuidString, "position": 0, "exercise_id": exercise.uuidString, "coach_notes": "Gomiti stretti", "updated_at": t(day), "deleted_at": NSNull()],
            ["id": slot2.uuidString, "mesocycle_id": mesocycle.uuidString, "group_id": group.uuidString, "position": 1, "exercise_id": exercise2.uuidString, "coach_notes": NSNull(), "updated_at": t(day), "deleted_at": NSNull()],
        ])
        remote.set(.setBlocks, [
            block(top, slot: slot, position: 0, role: "top", rest: 180, day: day),
            block(backoff, slot: slot, position: 1, role: "backoff", rest: 120, day: day),
        ])
        remote.set(.blockWeeks, [
            week(top, 1, sets: 1, reps: (5, 5), method: "BUF", value: 3, day: day),
            week(top, 2, sets: 1, reps: (5, 5), method: "BUF", value: 2, day: day),
            ["id": "70000000-0000-4000-8000-000000000003", "mesocycle_id": mesocycle.uuidString, "block_id": backoff.uuidString, "week": 1, "sets": 2, "reps_min": 8, "reps_max": 10, "method": NSNull(), "intensity_value": NSNull(), "ref_pct": 85, "updated_at": t(day), "deleted_at": NSNull()],
        ])
        remote.set(.exerciseVideos, [])
    }

    static func block(_ id: UUID, slot: UUID, position: Int, role: String, rest: Int?, day: Int) -> [String: Any] {
        ["id": id.uuidString, "mesocycle_id": mesocycle.uuidString, "slot_id": slot.uuidString, "position": position, "role": role, "technique": "none",
         "tut_eccentric_s": NSNull(), "tut_bottom_pause_s": NSNull(), "tut_concentric_s": NSNull(), "tut_top_pause_s": NSNull(),
         "rest_s": rest as Any? ?? NSNull(), "prep_s": NSNull(), "ref_block_id": NSNull(), "updated_at": t(day), "deleted_at": NSNull()]
    }

    static func week(_ block: UUID, _ week: Int, sets: Int, reps: (Int, Int), method: String, value: Double, day: Int) -> [String: Any] {
        ["id": "70000000-0000-4000-8000-00000000000\(week)", "mesocycle_id": mesocycle.uuidString, "block_id": block.uuidString, "week": week, "sets": sets,
         "reps_min": reps.0, "reps_max": reps.1, "method": method, "intensity_value": value, "ref_pct": NSNull(), "updated_at": t(day), "deleted_at": NSNull()]
    }
}
