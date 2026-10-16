import Foundation
import Domain
import GRDB
import Observation

/// Quello che il Profilo e le sue schermate mostrano di chi è collegato, letto dal database locale.
struct ProfileSnapshot: Equatable, Sendable {
    var name: String?
    var email: String?
    var coach: String?
    /// Serie registrate sul telefono e non ancora arrivate al server.
    var unsent = 0
}

@MainActor
@Observable
final class ProfileModel {
    private(set) var snapshot = ProfileSnapshot()
    private(set) var readFailed = false

    func watch(database: AppDatabase, userID: UUID) async {
        readFailed = await !database.watch(
            { db -> ProfileSnapshot in
                let me = try ProfileRecord.fetchOne(db, key: userID)
                let link = try CoachLinkRecord
                    .filter(Column("athlete_id") == userID && Column("status") == "active").fetchOne(db)
                let coach = try link.flatMap { try ProfileRecord.fetchOne(db, key: $0.coachId) }
                return ProfileSnapshot(
                    name: me?.fullName, email: me?.email, coach: coach?.displayName, unsent: try ExecutionStore.unsentSets(db))
            }
        ) { snapshot = $0 }
    }
}
