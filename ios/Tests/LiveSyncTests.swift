import Domain
import Foundation
import GRDB
import Supabase
import Testing

@testable import Gradus

private final class MemoryStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.withLock { items[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { items[key] } }
    func remove(key: String) throws { lock.withLock { items[key] = nil } }
}

/// Prova contro il Supabase LOCALE vero (RLS, PostgREST, formati di data e di numeri), non contro il finto.
/// Si salta da sola; per lanciarla:
///
///     supabase start && python3 ios/Scripts/seed_local.py
///     TEST_RUNNER_GRADUS_LIVE_KEY=<publishable key da `supabase status`> xcodebuild test …
struct LiveSyncTests {
    private static let key = ProcessInfo.processInfo.environment["GRADUS_LIVE_KEY"]
    private static let url = URL(string: "http://127.0.0.1:54321")!
    private static let password = "gradus-locale-1"  // stessa di Scripts/seed_local.py, vale solo in locale

    private func session(as email: String) async throws -> (SupabaseRemote, AppDatabase, SyncEngine) {
        let (remote, database, engine, _) = try await sessionWithUser(as: email)
        return (remote, database, engine)
    }

    private func sessionWithUser(as email: String) async throws -> (SupabaseRemote, AppDatabase, SyncEngine, UUID) {
        // Archivio in memoria: i test non sono firmati, quindi il portachiavi del simulatore non è disponibile.
        let client = SupabaseClient(
            supabaseURL: Self.url, supabaseKey: Self.key!,
            options: SupabaseClientOptions(auth: .init(storage: MemoryStorage(), emitLocalSessionAsInitialSession: true)))
        let user = try await SupabaseAuthClient(client: client, resetRedirect: Self.url).signIn(email: email, password: Self.password)
        let database = try AppDatabase.inMemory()
        let remote = SupabaseRemote(client: client)
        return (remote, database, SyncEngine(remote: remote, database: database), user)
    }

    private func count(_ db: AppDatabase, _ table: String) throws -> Int {
        try db.writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM \(table)") ?? 0 }
    }

    @Test("l'atleta scarica il suo programma attivo e niente altro", .enabled(if: key != nil))
    func athleteSeesOnlyOwnActiveProgram() async throws {
        let (_, database, engine) = try await session(as: "atleta@prova.local")
        _ = try await engine.sync()

        let names = try await database.writer.read { try String.fetchAll($0, sql: "SELECT name FROM mesocycles") }
        #expect(names == ["Ipertrofia 1"])  // né la bozza, né il programma di un altro atleta
        #expect(try count(database, "sessions") == 2)
        #expect(try count(database, "slots") == 2)
        #expect(try count(database, "set_blocks") == 2)
        #expect(try count(database, "block_weeks") == 6)
        let linked = try await database.writer.read {
            try String.fetchOne($0, sql: "SELECT ref_block_id FROM set_blocks WHERE role = 'backoff'")
        }
        #expect(linked != nil)
        let rest = try await database.writer.read {
            try Int.fetchOne($0, sql: "SELECT rest_s FROM set_blocks WHERE role = 'backoff'")
        }
        #expect(rest == 120)
        let refPct = try await database.writer.read {
            try Double.fetchOne($0, sql: "SELECT ref_pct FROM block_weeks WHERE ref_pct IS NOT NULL")
        }
        #expect(refPct == 85)
    }

    @Test("una seconda sincronizzazione non duplica e non perde nulla", .enabled(if: key != nil))
    func secondSyncIsIdempotent() async throws {
        let (_, database, engine) = try await session(as: "atleta@prova.local")
        _ = try await engine.sync()
        _ = try await engine.sync()
        #expect(try count(database, "mesocycles") == 1)
        #expect(try count(database, "block_weeks") == 6)
    }

    @Test("un altro atleta non vede il programma di Marco", .enabled(if: key != nil))
    func otherAthleteIsIsolated() async throws {
        let (_, database, engine) = try await session(as: "altro@prova.local")
        _ = try await engine.sync()
        let names = try await database.writer.read { try String.fetchAll($0, sql: "SELECT name FROM mesocycles") }
        #expect(names == ["Di un altro atleta"])
    }

    @Test("l'atleta registra una serie, la invia (RLS vera) e un altro telefono la riceve; reinviare non duplica", .enabled(if: key != nil))
    func athleteWritesSet() async throws {
        let mesocycle = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!  // da Scripts/seed_local.py
        let sessionID = UUID(uuidString: "20000000-0000-4000-8000-000000000001")!
        let block = UUID(uuidString: "50000000-0000-4000-8000-000000000001")!
        let (_, phone1, engine1, athlete) = try await sessionWithUser(as: "atleta@prova.local")
        _ = try await engine1.sync()

        let store = ExecutionStore(database: phone1)
        func edit(_ segments: [Segment], effort: Effort? = Effort(value: 2, scale: .buf)) -> SetEdit {
            SetEdit(
                athleteID: athlete, mesocycleID: mesocycle, sessionID: sessionID, week: 1, blockID: block, setIdx: 0,
                segments: segments, effort: effort)
        }
        // Si parte da pulito: se una prova precedente ha lasciato la serie sul server, la si ritira.
        try await store.save(edit([Segment(loadKg: nil, reps: nil)], effort: nil))
        _ = try await engine1.push()
        try await store.save(edit([Segment(loadKg: 102.5, reps: 5)]))
        #expect(try await engine1.push() == 3)  // seduta, serie, segmento
        try await store.save(edit([Segment(loadKg: 102.5, reps: 5)]))  // identica: niente da inviare
        #expect(try await engine1.push() == 0)

        // Un altro telefono, stesso account: riceve la serie con gli stessi id.
        let (_, phone2, engine2, _) = try await sessionWithUser(as: "atleta@prova.local")
        _ = try await engine2.sync()
        let received = try await ExecutionStore(database: phone2).loggedSets(mesocycleID: mesocycle, sessionID: sessionID)
        #expect(received.map(\.segments) == [[Segment(loadKg: 102.5, reps: 5)]])
        #expect(received.first?.effort == Effort(value: 2, scale: .buf))

        // Pulizia (così la prova si può rifare): svuotare ritira le righe sul server.
        try await store.save(edit([Segment(loadKg: nil, reps: nil)], effort: nil))
        #expect(try await engine1.push() == 3)
        _ = try await engine2.sync()
        #expect(try await ExecutionStore(database: phone2).loggedSets(mesocycleID: mesocycle, sessionID: sessionID).isEmpty)
    }

    @Test("un altro atleta non può scrivere sul programma di Marco", .enabled(if: key != nil))
    func otherAthleteCannotWrite() async throws {
        let (_, database, engine, other) = try await sessionWithUser(as: "altro@prova.local")
        _ = try await engine.sync()
        try await ExecutionStore(database: database).save(
            SetEdit(
                athleteID: other, mesocycleID: UUID(uuidString: "10000000-0000-4000-8000-000000000001")!,
                sessionID: UUID(uuidString: "20000000-0000-4000-8000-000000000001")!, week: 1,
                blockID: UUID(uuidString: "50000000-0000-4000-8000-000000000001")!, setIdx: 0,
                segments: [Segment(loadKg: 50, reps: 5)], effort: nil))
        await #expect(throws: (any Error).self) { try await engine.push() }  // il server rifiuta (RLS / chiavi esterne)
    }
}
