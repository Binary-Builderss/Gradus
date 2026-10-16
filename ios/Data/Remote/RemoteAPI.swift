import Foundation

/// Le tabelle del server che l'app legge, nell'ordine in cui si sincronizzano. La programmazione è in sola lettura.
enum SyncTable: String, CaseIterable, Sendable {
    case profiles
    case coachAthletes = "coach_athletes"
    case mesocycles
    case sessions
    case slotGroups = "slot_groups"
    case exercises
    case slots
    case setBlocks = "set_blocks"
    case blockWeeks = "block_weeks"
    case exerciseVideos = "exercise_videos"
    // Esecuzione: scrive l'atleta (workouts → set_logs → set_segments, l'ordine delle chiavi esterne).
    case workouts
    case setLogs = "set_logs"
    case setSegments = "set_segments"

    /// Tabelle senza `deleted_at`: una riga tolta dal server (o che l'atleta non vede più) non arriva come
    /// cancellazione, quindi si confronta l'elenco degli id a ogni sincronizzazione.
    var removesRows: Bool { self == .mesocycles || self == .exerciseVideos || self == .coachAthletes }

    /// Le tabelle che l'atleta scrive: si inviano con la coda e il pull non sovrascrive le righe ancora da inviare.
    var isWrittenByAthlete: Bool { self == .workouts || self == .setLogs || self == .setSegments }
}

/// Cosa serve dal server. La rete sta dietro a questo confine: le View non la chiamano mai, e i test usano un finto.
protocol RemoteAPI: Sendable {
    /// Una pagina di righe (JSON) con `updated_at >= since`, ordinate per `updated_at` e `id`.
    func fetchPage(table: SyncTable, since: String?, offset: Int, limit: Int) async throws -> Data
    /// Gli id (JSON: `[{"id": "…"}]`) di tutte le righe che l'atleta vede oggi.
    func fetchIDs(table: SyncTable) async throws -> Data
    /// Upsert idempotente sulla chiave primaria: `rows` è un array JSON di righe con tutte le colonne tranne
    /// `updated_at` (lo scrive il server). Reinviare le stesse righe non crea duplicati.
    func upsert(table: SyncTable, rows: Data) async throws
    /// Riattiva il proprio account (`profiles.disabled_at = null`).
    func reactivateAccount(userID: UUID) async throws
}
