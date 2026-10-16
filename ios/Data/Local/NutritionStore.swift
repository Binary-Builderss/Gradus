import Domain
import Foundation
import GRDB

/// Un giorno scritto dall'atleta: come l'ha chiuso e quanto ha assunto (se lo sa).
struct DayEdit: Equatable, Sendable {
    var athleteID: UUID
    var day: String
    var status: MacroDayStatus
    var intake: MacroIntake
}

/// Un giorno della schermata dei macro: com'è andato e con quale obiettivo (quello in vigore quel giorno).
struct DayEntry: Equatable, Identifiable, Sendable {
    var day: String
    var status: MacroDayStatus?
    var source: MacroSource?
    var intake: MacroIntake
    var target: MacroTargets?

    var id: String { day }
}

struct NutritionSnapshot: Equatable, Sendable {
    /// L'atleta ha acconsentito a registrare e condividere i macro.
    var consent: Bool
    /// L'obiettivo in vigore oggi, se il coach ne ha impostato uno.
    var today: MacroPlan?
    /// Gli ultimi giorni, il più recente per primo (anche quelli non registrati).
    var days: [DayEntry]
}

/// Macro sul telefono: i giorni dell'atleta (salvati in locale e inviati dalla coda, come le serie), il consenso e la lettura
/// degli obiettivi del coach. Senza consenso l'atleta non registra nulla.
struct NutritionStore: Sendable {
    enum StoreError: Error, Equatable {
        case noConsent
        case notEditable
    }

    static let visibleDays = 14

    let database: AppDatabase
    let remote: any RemoteAPI

    // MARK: Giorni

    func save(_ edit: DayEdit, today: Date = .now, calendar: Calendar = .current, at date: Date = .now) async throws {
        guard Nutrition.isEditable(edit.day, today: today, calendar: calendar) else { throw StoreError.notEditable }
        try await database.writer.write { db in
            guard try Self.hasConsent(db, userID: edit.athleteID) else { throw StoreError.noConsent }
            try Self.apply(edit, at: ExecutionStore.timestamp(date), in: db)
        }
    }

    /// Toglie il giorno (torna «non registrato»): si ritira sul server con `deleted_at`.
    func clear(athleteID: UUID, day: String, today: Date = .now, calendar: Calendar = .current, at date: Date = .now) async throws {
        guard Nutrition.isEditable(day, today: today, calendar: calendar) else { throw StoreError.notEditable }
        try await database.writer.write { db in
            let id = DeterministicID.nutritionDay(athleteID: athleteID, day: day)
            guard var row = try NutritionDayRecord.fetchOne(db, key: id), row.deletedAt == nil else { return }
            let now = ExecutionStore.timestamp(date)
            row.deletedAt = now
            row.updatedAt = now
            try row.update(db)
            try ExecutionStore.enqueue(.nutritionDays, id, in: db)
        }
    }

    static func apply(_ edit: DayEdit, at now: String, in db: Database) throws {
        let id = DeterministicID.nutritionDay(athleteID: edit.athleteID, day: edit.day)
        let source = Nutrition.manualSource(for: edit.intake)
        let existing = try NutritionDayRecord.fetchOne(db, key: id)
        if let existing, existing.deletedAt == nil, existing.status == edit.status.rawValue, existing.source == source.rawValue,
            existing.kcal == edit.intake.kcal, existing.proteinG == edit.intake.proteinG, existing.carbsG == edit.intake.carbsG,
            existing.fatG == edit.intake.fatG, existing.fiberG == edit.intake.fiberG
        {
            return  // niente è cambiato: nessuna riga in coda
        }
        try NutritionDayRecord(
            id: id, athleteId: edit.athleteID, day: edit.day, status: edit.status.rawValue, source: source.rawValue,
            kcal: edit.intake.kcal, proteinG: edit.intake.proteinG, carbsG: edit.intake.carbsG, fatG: edit.intake.fatG,
            fiberG: edit.intake.fiberG, updatedAt: now, deletedAt: nil
        ).save(db)
        try ExecutionStore.enqueue(.nutritionDays, id, in: db)
    }

    // MARK: Consenso

    /// Prima sul server, poi sul telefono: il consenso vale quando l'ha ricevuto il server (è lui che lo controlla).
    func grantConsent(userID: UUID, at date: Date = .now) async throws {
        try await remote.setNutritionConsent(userID: userID, at: date, version: Nutrition.consentVersion)
        try await database.writer.write { db in
            if var profile = try ProfileRecord.fetchOne(db, key: userID) {
                profile.nutritionConsentAt = ExecutionStore.timestamp(date)
                profile.nutritionConsentVersion = Nutrition.consentVersion
                try profile.update(db)
            }
        }
    }

    /// Ritira il consenso: il server cancella i giorni; qui si cancellano anche quelli sul telefono e quelli in coda.
    func withdrawConsent(userID: UUID) async throws {
        try await remote.withdrawNutritionConsent()
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM nutrition_days WHERE athlete_id = ?", arguments: [userID])
            try db.execute(sql: "DELETE FROM pending_push WHERE table_name = ?", arguments: [SyncTable.nutritionDays.rawValue])
            if var profile = try ProfileRecord.fetchOne(db, key: userID) {
                profile.nutritionConsentAt = nil
                profile.nutritionConsentVersion = nil
                try profile.update(db)
            }
        }
    }

    static func hasConsent(_ db: Database, userID: UUID) throws -> Bool {
        try ProfileRecord.fetchOne(db, key: userID)?.nutritionConsentAt != nil
    }

    // MARK: Lettura

    static func snapshot(
        _ db: Database, athleteID: UUID, today: Date = .now, calendar: Calendar = .current
    ) throws -> NutritionSnapshot {
        let plans = try macroPlans(db, athleteID: athleteID)
        let days = Nutrition.recentDays(count: visibleDays, today: today, calendar: calendar)
        let rows = try NutritionDayRecord
            .filter(days.contains(Column("day")) && Column("athlete_id") == athleteID && Column("deleted_at") == nil)
            .fetchAll(db)
        let byDay = Dictionary(rows.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        let entries = days.map { day -> DayEntry in
            let row = byDay[day]
            return DayEntry(
                day: day, status: row.flatMap { MacroDayStatus(rawValue: $0.status) },
                source: row.flatMap { MacroSource(rawValue: $0.source) },
                intake: MacroIntake(kcal: row?.kcal, proteinG: row?.proteinG, carbsG: row?.carbsG, fatG: row?.fatG, fiberG: row?.fiberG),
                target: Nutrition.planInForce(plans, on: day)?.targets)
        }
        return NutritionSnapshot(
            consent: try hasConsent(db, userID: athleteID),
            today: Nutrition.planInForce(plans, on: Nutrition.dayString(today, calendar: calendar)),
            days: entries)
    }

    /// I piani `macros` dell'atleta con il loro obiettivo giornaliero (un solo tipo di giorno, per ora).
    static func macroPlans(_ db: Database, athleteID: UUID) throws -> [MacroPlan] {
        let plans = try NutritionPlanRecord.filter(Column("athlete_id") == athleteID && Column("kind") == "macros").fetchAll(db)
        let days = try NutritionPlanDayRecord.filter(plans.map(\.id).contains(Column("plan_id")) && Column("day_type") == "all").fetchAll(db)
        let byPlan = Dictionary(days.map { ($0.planId, $0) }, uniquingKeysWith: { first, _ in first })
        return plans.compactMap { plan in
            byPlan[plan.id].map { day in
                MacroPlan(
                    id: plan.id, validFrom: plan.validFrom, deleted: plan.deletedAt != nil, tolerancePct: plan.tolerancePct,
                    targets: MacroTargets(kcal: day.kcal, proteinG: day.proteinG, carbsG: day.carbsG, fatG: day.fatG, fiberG: day.fiberG))
            }
        }
    }

    // MARK: Invio

    /// Le righe per il server, con tutte le colonne (anche `null`: PostgREST vuole le stesse chiavi in ogni riga) e senza
    /// `updated_at`, che scrive il server.
    static func payload(_ db: Database, ids: [UUID]) throws -> Data {
        let null = NSNull()
        let rows: [[String: Any]] = try NutritionDayRecord.fetchAll(db, keys: ids).map {
            [
                "id": $0.id.uuidString, "athlete_id": $0.athleteId.uuidString, "day": $0.day, "status": $0.status,
                "source": $0.source, "kcal": $0.kcal ?? null, "protein_g": $0.proteinG ?? null, "carbs_g": $0.carbsG ?? null,
                "fat_g": $0.fatG ?? null, "fiber_g": $0.fiberG ?? null, "deleted_at": $0.deletedAt ?? null,
            ]
        }
        return try JSONSerialization.data(withJSONObject: rows)
    }
}
