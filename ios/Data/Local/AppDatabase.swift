import Foundation
import GRDB

/// Il database locale (SQLite): la fonte di verità per l'interfaccia. L'app funziona anche senza rete.
final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

    init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// Su disco, nella cartella dell'app (esclusa dai backup: si ricostruisce dal server).
    static func onDisk() throws -> AppDatabase {
        var url = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        url.append(path: "gradus.sqlite")
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        return try AppDatabase(DatabaseQueue(path: url.path))
    }

    /// In memoria, per i test.
    static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        // I dati sono una copia del server: se lo schema locale cambia basta ricostruirli.
        migrator.eraseDatabaseOnSchemaChange = true

        migrator.registerMigration("v1-programma") { db in
            try db.create(table: "sync_cursors") { t in
                t.primaryKey("table_name", .text)
                t.column("cursor", .text).notNull()
            }
            try db.create(table: "profiles") { t in
                t.primaryKey("id", .blob)
                t.column("email", .text)
                t.column("full_name", .text)
                t.column("disabled_at", .text)
                t.column("updated_at", .text).notNull()
            }
            try db.create(table: "coach_athletes") { t in
                t.primaryKey("id", .blob)
                t.column("coach_id", .blob).notNull()
                t.column("athlete_id", .blob).notNull()
                t.column("status", .text).notNull()
                t.column("updated_at", .text).notNull()
            }
            try db.create(table: "mesocycles") { t in
                t.primaryKey("id", .blob)
                t.column("athlete_id", .blob).notNull()
                t.column("name", .text).notNull()
                t.column("start_date", .text).notNull()
                t.column("weeks", .integer).notNull()
                t.column("deload_weeks", .jsonText).notNull()
                t.column("status", .text).notNull()
                t.column("coach_notes", .text)
                t.column("updated_at", .text).notNull()
            }
            try db.create(table: "sessions") { t in
                t.primaryKey("id", .blob)
                t.column("mesocycle_id", .blob).notNull().indexed()
                t.column("position", .integer).notNull()
                t.column("name", .text).notNull()
                t.column("coach_notes", .text)
                t.column("updated_at", .text).notNull()
                t.column("deleted_at", .text)
            }
            try db.create(table: "slot_groups") { t in
                t.primaryKey("id", .blob)
                t.column("mesocycle_id", .blob).notNull().indexed()
                t.column("session_id", .blob).notNull().indexed()
                t.column("position", .integer).notNull()
                t.column("kind", .text).notNull()
                t.column("rest_between_s", .integer).notNull()
                t.column("rest_after_round_s", .integer).notNull()
                t.column("updated_at", .text).notNull()
                t.column("deleted_at", .text)
            }
            try db.create(table: "exercises") { t in
                t.primaryKey("id", .blob)
                t.column("owner_id", .blob)
                t.column("name", .text).notNull()
                t.column("notes", .text)
                t.column("updated_at", .text).notNull()
                t.column("deleted_at", .text)
            }
            try db.create(table: "slots") { t in
                t.primaryKey("id", .blob)
                t.column("mesocycle_id", .blob).notNull().indexed()
                t.column("group_id", .blob).notNull().indexed()
                t.column("position", .integer).notNull()
                t.column("exercise_id", .blob).notNull()
                t.column("coach_notes", .text)
                t.column("updated_at", .text).notNull()
                t.column("deleted_at", .text)
            }
            try db.create(table: "set_blocks") { t in
                t.primaryKey("id", .blob)
                t.column("mesocycle_id", .blob).notNull().indexed()
                t.column("slot_id", .blob).notNull().indexed()
                t.column("position", .integer).notNull()
                t.column("role", .text).notNull()
                t.column("technique", .text).notNull()
                t.column("tut_eccentric_s", .integer)
                t.column("tut_bottom_pause_s", .integer)
                t.column("tut_concentric_s", .integer)
                t.column("tut_top_pause_s", .integer)
                t.column("rest_s", .integer)
                t.column("prep_s", .integer)
                t.column("ref_block_id", .blob)
                t.column("updated_at", .text).notNull()
                t.column("deleted_at", .text)
            }
            try db.create(table: "block_weeks") { t in
                t.primaryKey("id", .blob)
                t.column("mesocycle_id", .blob).notNull().indexed()
                t.column("block_id", .blob).notNull().indexed()
                t.column("week", .integer).notNull()
                t.column("sets", .integer).notNull()
                t.column("reps_min", .integer)
                t.column("reps_max", .integer)
                t.column("method", .text)
                t.column("intensity_value", .double)
                t.column("ref_pct", .double)
                t.column("updated_at", .text).notNull()
                t.column("deleted_at", .text)
            }
            try db.create(table: "exercise_videos") { t in
                t.primaryKey("id", .blob)
                t.column("exercise_id", .blob).notNull().indexed()
                t.column("owner_id", .blob).notNull()
                t.column("url", .text).notNull()
                t.column("title", .text)
                t.column("updated_at", .text).notNull()
            }
        }
        return migrator
    }

    /// Svuota tutto (uscita dall'account): i dati sono di chi era collegato.
    func erase() throws {
        try writer.write { db in
            for table in SyncTable.allCases.map(\.rawValue) + ["sync_cursors"] { try db.execute(sql: "DELETE FROM \(table)") }
        }
    }
}
