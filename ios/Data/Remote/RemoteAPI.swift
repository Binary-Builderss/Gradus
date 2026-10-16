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
    // Macro: gli obiettivi li scrive il coach, l'aderenza l'atleta.
    case nutritionPlans = "nutrition_plans"
    case nutritionPlanDays = "nutrition_plan_days"
    // Esecuzione: scrive l'atleta (workouts → set_logs → set_segments, l'ordine delle chiavi esterne).
    case workouts
    case setLogs = "set_logs"
    case setSegments = "set_segments"
    case nutritionDays = "nutrition_days"

    /// Tabelle senza `deleted_at`: una riga tolta dal server (o che l'atleta non vede più) non arriva come
    /// cancellazione, quindi si confronta l'elenco degli id a ogni sincronizzazione.
    var removesRows: Bool {
        self == .mesocycles || self == .exerciseVideos || self == .coachAthletes || self == .nutritionDays
    }

    /// Le tabelle che l'atleta scrive: si inviano con la coda e il pull non sovrascrive le righe ancora da inviare.
    var isWrittenByAthlete: Bool {
        self == .workouts || self == .setLogs || self == .setSegments || self == .nutritionDays
    }
}

/// Perché la cancellazione dell'account non è andata a buon fine (stessi codici della Edge Function).
enum AccountDeletionError: Error, Equatable {
    case confirmMismatch
    /// Un abbonamento che si rinnova ancora: prima si disdice dal sito.
    case subscriptionActive
    case failed
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
    /// Il proprio nome (`profiles.full_name`): è il nome con cui il coach vede l'atleta.
    func updateName(userID: UUID, name: String) async throws
    /// Il consenso a condividere i macro con il coach (`profiles.nutrition_consent_at`); `nil` lo toglie dal profilo.
    func setNutritionConsent(userID: UUID, at date: Date?, version: String?) async throws
    /// Ritira il consenso: il server cancella i giorni registrati e azzera il consenso (`withdraw_nutrition_consent`).
    func withdrawNutritionConsent() async throws
    /// Disattiva (`profiles.disabled_at = now`) o riattiva (`null`) il proprio account: i dati restano.
    func setAccountDisabled(userID: UUID, disabled: Bool) async throws
    /// Cancellazione definitiva (Edge Function `delete-account`): `confirm` è l'email scritta a mano dalla persona.
    func deleteAccount(confirm: String) async throws
}
