import Domain
import Foundation
import GRDB

// La programmazione letta dal database locale, già composta per l'interfaccia. Sola lettura: l'app non scrive mai
// la programmazione. Le righe eliminate sul server (`deleted_at`) restano nel database ma non si mostrano.

struct SessionSummary: Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var coachNotes: String?
    var exerciseCount: Int
}

struct HomeSnapshot: Equatable, Sendable {
    var athleteName: String?
    var coachName: String?
    var mesocycle: MesocycleRecord?
    var sessions: [SessionSummary]
}

struct BlockContent: Equatable, Identifiable, Sendable {
    var id: UUID
    var role: String
    var technique: String
    var restS: Int?
    var tut: [Int?]
    var refBlockId: UUID?
    var prescription: Prescription?

    /// Serie da fare in questa settimana (0 se il coach non ha scritto la prescrizione).
    var prescribedSets: Int { prescription?.sets ?? 0 }
    /// Le tecniche a segmenti hanno una riga carico × ripetizioni per segmento.
    var hasSegments: Bool { technique != "none" }
}

struct SlotContent: Equatable, Identifiable, Sendable {
    var id: UUID
    var exerciseName: String
    var coachNotes: String?
    var blocks: [BlockContent]
    /// Il video dell'esercizio, se il coach ne ha collegato uno.
    var videoURL: URL? = nil
}

struct GroupContent: Equatable, Identifiable, Sendable {
    var id: UUID
    var kind: String
    var restBetweenS: Int
    var restAfterRoundS: Int
    var slots: [SlotContent]
}

struct SessionContent: Equatable, Sendable {
    var sessionID: UUID
    var mesocycleID: UUID
    var athleteID: UUID
    var deloadWeeks: [Int]
    var name: String
    var coachNotes: String?
    var groups: [GroupContent]
    /// Serie registrate per blocco nella settimana mostrata.
    var loggedCounts: [UUID: Int]

    /// Tutti i blocchi della seduta, nell'ordine in cui compaiono.
    var blockOrder: [UUID] { groups.flatMap(\.slots).flatMap(\.blocks).map(\.id) }
}

extension BlockContent {
    func completion(logged: [UUID: Int]) -> Completion {
        Completion(logged: logged[id] ?? 0, prescribed: prescribedSets)
    }
}

extension SlotContent {
    /// Vuoto, parziale o completo, confrontando serie registrate e prescritte (solo i blocchi con prescrizione).
    func completion(logged: [UUID: Int]) -> Completion {
        .combined(blocks.filter { $0.prescribedSets > 0 }.map { $0.completion(logged: logged) })
    }
}

extension SessionContent {
    func completion(of slot: SlotContent) -> Completion { slot.completion(logged: loggedCounts) }

    /// La seduta inizia alla prima serie e finisce con l'ultima: nessun «termina allenamento».
    var completion: Completion {
        .combined(groups.flatMap(\.slots).map { $0.completion(logged: loggedCounts) })
    }
}

enum ProgramQueries {
    /// La home: il mesociclo attivo e le sue sedute. L'atleta vede solo i suoi (RLS), quindi basta lo stato.
    static func home(_ db: Database, athleteID: UUID) throws -> HomeSnapshot {
        let me = try ProfileRecord.fetchOne(db, key: athleteID)
        let link = try CoachLinkRecord
            .filter(Column("athlete_id") == athleteID && Column("status") == "active").fetchOne(db)
        let coach = try link.flatMap { try ProfileRecord.fetchOne(db, key: $0.coachId) }
        guard
            let mesocycle = try MesocycleRecord.filter(Column("status") == "active")
                .order(Column("start_date").desc).fetchOne(db)
        else {
            return HomeSnapshot(athleteName: me?.displayName, coachName: coach?.displayName, mesocycle: nil, sessions: [])
        }
        let sessions = try SessionRecord
            .filter(Column("mesocycle_id") == mesocycle.id && Column("deleted_at") == nil)
            .order(Column("position")).fetchAll(db)
        let summaries = try sessions.map { session in
            let count = try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM slots
                    JOIN slot_groups g ON g.id = slots.group_id AND g.deleted_at IS NULL
                    WHERE g.session_id = ? AND slots.deleted_at IS NULL
                    """,
                arguments: [session.id]) ?? 0
            return SessionSummary(id: session.id, name: session.name, coachNotes: session.coachNotes, exerciseCount: count)
        }
        return HomeSnapshot(
            athleteName: me?.displayName, coachName: coach?.displayName, mesocycle: mesocycle, sessions: summaries)
    }

    /// Una seduta in una settimana: gruppi, esercizi e prescrizione di ogni blocco.
    static func session(_ db: Database, id: UUID, week: Int) throws -> SessionContent? {
        guard let session = try SessionRecord.fetchOne(db, key: id), session.deletedAt == nil else { return nil }
        let groups = try SlotGroupRecord
            .filter(Column("session_id") == id && Column("deleted_at") == nil).order(Column("position")).fetchAll(db)
        let groupIDs = groups.map(\.id)
        let slots = try SlotRecord
            .filter(groupIDs.contains(Column("group_id")) && Column("deleted_at") == nil)
            .order(Column("position")).fetchAll(db)
        let exercises = try ExerciseRecord.fetchAll(db, keys: Array(Set(slots.map(\.exerciseId))))
        let names = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
        let videos = try ExerciseVideoRecord.filter(exercises.map(\.id).contains(Column("exercise_id"))).fetchAll(db)
        let videoURLs = Dictionary(videos.compactMap { video in URL(string: video.url).map { (video.exerciseId, $0) } }, uniquingKeysWith: { first, _ in first })
        let blocks = try SetBlockRecord
            .filter(slots.map(\.id).contains(Column("slot_id")) && Column("deleted_at") == nil)
            .order(Column("position")).fetchAll(db)
        let weeks = try BlockWeekRecord
            .filter(blocks.map(\.id).contains(Column("block_id")) && Column("week") == week && Column("deleted_at") == nil)
            .fetchAll(db)
        let weekByBlock = Dictionary(weeks.map { ($0.blockId, $0) }, uniquingKeysWith: { first, _ in first })

        func content(_ block: SetBlockRecord) -> BlockContent {
            BlockContent(
                id: block.id, role: block.role, technique: block.technique, restS: block.restS,
                tut: [block.tutEccentricS, block.tutBottomPauseS, block.tutConcentricS, block.tutTopPauseS],
                refBlockId: block.refBlockId, prescription: weekByBlock[block.id].map(prescription))
        }
        let mesocycle = try MesocycleRecord.fetchOne(db, key: session.mesocycleId)
        return SessionContent(
            sessionID: id, mesocycleID: session.mesocycleId, athleteID: mesocycle?.athleteId ?? UUID(),
            deloadWeeks: mesocycle?.deloadWeeks ?? [], name: session.name, coachNotes: session.coachNotes,
            groups: groups.map { group in
                GroupContent(
                    id: group.id, kind: group.kind, restBetweenS: group.restBetweenS,
                    restAfterRoundS: group.restAfterRoundS,
                    slots: slots.filter { $0.groupId == group.id }.map { slot in
                        SlotContent(
                            id: slot.id, exerciseName: names[slot.exerciseId] ?? "Esercizio", coachNotes: slot.coachNotes,
                            blocks: blocks.filter { $0.slotId == slot.id }.map(content), videoURL: videoURLs[slot.exerciseId])
                    })
            },
            loggedCounts: try ExecutionStore.loggedCounts(db, sessionID: id, week: week))
    }

    /// Lo stato di ogni seduta del mesociclo in una settimana (per l'elenco della home).
    static func sessionStates(_ db: Database, mesocycleID: UUID, week: Int) throws -> [UUID: Completion] {
        let sessions = try SessionRecord.filter(Column("mesocycle_id") == mesocycleID && Column("deleted_at") == nil).fetchAll(db)
        var states: [UUID: Completion] = [:]
        for session in sessions { states[session.id] = try Self.session(db, id: session.id, week: week)?.completion ?? .empty }
        return states
    }

    private static func prescription(_ week: BlockWeekRecord) -> Prescription {
        Prescription(
            sets: week.sets, repsMin: week.repsMin, repsMax: week.repsMax,
            method: week.method.flatMap(IntensityMethod.init(rawValue:)), value: week.intensityValue, refPct: week.refPct)
    }
}

extension ProfileRecord {
    /// Il nome, o l'email se non l'ha scritto.
    var displayName: String? {
        let name = fullName?.trimmingCharacters(in: .whitespaces)
        return (name?.isEmpty == false ? name : nil) ?? email
    }
}
