import Foundation
import GRDB

// Le righe del database locale. Stessi nomi e colonne del server (snake_case): quello che arriva si salva com'è,
// l'interfaccia legge solo da qui. Le date restano testo (`yyyy-MM-dd` e timestamp ISO come li dà il server).

protocol SyncedRecord: Codable, Equatable, FetchableRecord, PersistableRecord, Sendable {
    var id: UUID { get }
    var updatedAt: String { get }
}

struct ProfileRecord: SyncedRecord {
    static let databaseTableName = "profiles"
    var id: UUID
    var email: String?
    var fullName: String?
    var disabledAt: String?
    /// Quando l'atleta ha acconsentito a condividere i macro con il coach (senza, non può registrarli).
    var nutritionConsentAt: String?
    var nutritionConsentVersion: String?
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, email
        case fullName = "full_name"
        case disabledAt = "disabled_at"
        case nutritionConsentAt = "nutrition_consent_at"
        case nutritionConsentVersion = "nutrition_consent_version"
        case updatedAt = "updated_at"
    }
}

struct CoachLinkRecord: SyncedRecord {
    static let databaseTableName = "coach_athletes"
    var id: UUID
    var coachId: UUID
    var athleteId: UUID
    var status: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case coachId = "coach_id"
        case athleteId = "athlete_id"
        case updatedAt = "updated_at"
    }
}

struct MesocycleRecord: SyncedRecord {
    static let databaseTableName = "mesocycles"
    var id: UUID
    var athleteId: UUID
    var name: String
    var startDate: String
    var weeks: Int
    var deloadWeeks: [Int]
    var status: String
    var coachNotes: String?
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, weeks, status
        case athleteId = "athlete_id"
        case startDate = "start_date"
        case deloadWeeks = "deload_weeks"
        case coachNotes = "coach_notes"
        case updatedAt = "updated_at"
    }
}

struct SessionRecord: SyncedRecord {
    static let databaseTableName = "sessions"
    var id: UUID
    var mesocycleId: UUID
    var position: Int
    var name: String
    var coachNotes: String?
    var updatedAt: String
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, position, name
        case mesocycleId = "mesocycle_id"
        case coachNotes = "coach_notes"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct SlotGroupRecord: SyncedRecord {
    static let databaseTableName = "slot_groups"
    var id: UUID
    var mesocycleId: UUID
    var sessionId: UUID
    var position: Int
    var kind: String
    var restBetweenS: Int
    var restAfterRoundS: Int
    var updatedAt: String
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, position, kind
        case mesocycleId = "mesocycle_id"
        case sessionId = "session_id"
        case restBetweenS = "rest_between_s"
        case restAfterRoundS = "rest_after_round_s"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct ExerciseRecord: SyncedRecord {
    static let databaseTableName = "exercises"
    var id: UUID
    var ownerId: UUID?
    var name: String
    var notes: String?
    var updatedAt: String
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case ownerId = "owner_id"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct SlotRecord: SyncedRecord {
    static let databaseTableName = "slots"
    var id: UUID
    var mesocycleId: UUID
    var groupId: UUID
    var position: Int
    var exerciseId: UUID
    var coachNotes: String?
    var updatedAt: String
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, position
        case mesocycleId = "mesocycle_id"
        case groupId = "group_id"
        case exerciseId = "exercise_id"
        case coachNotes = "coach_notes"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct SetBlockRecord: SyncedRecord {
    static let databaseTableName = "set_blocks"
    var id: UUID
    var mesocycleId: UUID
    var slotId: UUID
    var position: Int
    var role: String
    var technique: String
    var tutEccentricS: Int?
    var tutBottomPauseS: Int?
    var tutConcentricS: Int?
    var tutTopPauseS: Int?
    var restS: Int?
    var prepS: Int?
    var refBlockId: UUID?
    var updatedAt: String
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, position, role, technique
        case mesocycleId = "mesocycle_id"
        case slotId = "slot_id"
        case tutEccentricS = "tut_eccentric_s"
        case tutBottomPauseS = "tut_bottom_pause_s"
        case tutConcentricS = "tut_concentric_s"
        case tutTopPauseS = "tut_top_pause_s"
        case restS = "rest_s"
        case prepS = "prep_s"
        case refBlockId = "ref_block_id"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct BlockWeekRecord: SyncedRecord {
    static let databaseTableName = "block_weeks"
    var id: UUID
    var mesocycleId: UUID
    var blockId: UUID
    var week: Int
    var sets: Int
    var repsMin: Int?
    var repsMax: Int?
    var method: String?
    var intensityValue: Double?
    var refPct: Double?
    var updatedAt: String
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, week, sets, method
        case mesocycleId = "mesocycle_id"
        case blockId = "block_id"
        case repsMin = "reps_min"
        case repsMax = "reps_max"
        case intensityValue = "intensity_value"
        case refPct = "ref_pct"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct ExerciseVideoRecord: SyncedRecord {
    static let databaseTableName = "exercise_videos"
    var id: UUID
    var exerciseId: UUID
    var ownerId: UUID
    var url: String
    var title: String?
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, url, title
        case exerciseId = "exercise_id"
        case ownerId = "owner_id"
        case updatedAt = "updated_at"
    }
}

struct WorkoutRecord: SyncedRecord {
    static let databaseTableName = "workouts"
    var id: UUID
    var athleteId: UUID
    var mesocycleId: UUID
    var sessionId: UUID
    var week: Int
    var athleteNotes: String?
    var updatedAt: String
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, week
        case athleteId = "athlete_id"
        case mesocycleId = "mesocycle_id"
        case sessionId = "session_id"
        case athleteNotes = "athlete_notes"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct SetLogRecord: SyncedRecord {
    static let databaseTableName = "set_logs"
    var id: UUID
    var athleteId: UUID
    var mesocycleId: UUID
    var workoutId: UUID
    var blockId: UUID
    var setIdx: Int
    var effortValue: Double?
    var effortScale: String?
    var doneAt: String
    var updatedAt: String
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case athleteId = "athlete_id"
        case mesocycleId = "mesocycle_id"
        case workoutId = "workout_id"
        case blockId = "block_id"
        case setIdx = "set_idx"
        case effortValue = "effort_value"
        case effortScale = "effort_scale"
        case doneAt = "done_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct SetSegmentRecord: SyncedRecord {
    static let databaseTableName = "set_segments"
    var id: UUID
    var athleteId: UUID
    var setLogId: UUID
    var segIdx: Int
    var loadKg: Double?
    var reps: Int?
    var updatedAt: String
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, reps
        case athleteId = "athlete_id"
        case setLogId = "set_log_id"
        case segIdx = "seg_idx"
        case loadKg = "load_kg"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct NutritionPlanRecord: SyncedRecord {
    static let databaseTableName = "nutrition_plans"
    var id: UUID
    var athleteId: UUID
    var authorId: UUID?
    var kind: String
    var validFrom: String
    var tolerancePct: Int
    var declaredAt: String
    var declarationVersion: String
    var updatedAt: String
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, kind
        case athleteId = "athlete_id"
        case authorId = "author_id"
        case validFrom = "valid_from"
        case tolerancePct = "tolerance_pct"
        case declaredAt = "declared_at"
        case declarationVersion = "declaration_version"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct NutritionPlanDayRecord: SyncedRecord {
    static let databaseTableName = "nutrition_plan_days"
    var id: UUID
    var planId: UUID
    var dayType: String
    var kcal: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int
    var fiberG: Int?
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, kcal
        case planId = "plan_id"
        case dayType = "day_type"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case updatedAt = "updated_at"
    }
}

/// Un giorno di macro registrato dall'atleta. Nessuna riga = giorno non registrato.
struct NutritionDayRecord: SyncedRecord {
    static let databaseTableName = "nutrition_days"
    var id: UUID
    var athleteId: UUID
    var day: String
    var status: String
    var source: String
    var kcal: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var fiberG: Double?
    var updatedAt: String
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, day, status, source, kcal
        case athleteId = "athlete_id"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

/// Fin dove si è letto ogni tabella: il massimo `updated_at` visto.
struct SyncCursorRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "sync_cursors"
    var tableName: String
    var cursor: String

    enum CodingKeys: String, CodingKey {
        case tableName = "table_name"
        case cursor
    }
}
