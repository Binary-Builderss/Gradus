import Domain
import Foundation
import GRDB

/// Il nome dell'atleta: si scrive sul server (è l'unica cosa del profilo che l'app modifica) e poi sul telefono.
struct ProfileStore: Sendable {
    enum NameError: Error, Equatable { case empty }

    let database: AppDatabase
    let remote: any RemoteAPI

    /// Salva il nome. Senza rete lancia l'errore di rete e il telefono resta com'era: il nome lo vede il coach, quindi
    /// non lo si dà per salvato finché il server non l'ha ricevuto.
    @discardableResult
    func setName(_ raw: String, userID: UUID) async throws -> String {
        guard let name = ProfileName.normalized(raw) else { throw NameError.empty }
        try await remote.updateName(userID: userID, name: name)
        try await database.writer.write { db in
            if var profile = try ProfileRecord.fetchOne(db, key: userID) {
                profile.fullName = name
                try profile.update(db)
            }
        }
        return name
    }
}
