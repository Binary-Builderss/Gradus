import Domain
import Foundation
import GRDB

/// Disattivare, riattivare o eliminare il proprio account. Disattivare è reversibile (i dati restano); eliminare è
/// definitivo e chiede l'email scritta a mano, come sul sito.
struct AccountStore: Sendable {
    let database: AppDatabase
    let remote: any RemoteAPI

    func disable(userID: UUID) async throws { try await setDisabled(true, userID: userID) }
    func reactivate(userID: UUID) async throws { try await setDisabled(false, userID: userID) }

    /// Prima sul server, poi sul telefono (così la schermata cambia subito, senza aspettare la sincronizzazione).
    private func setDisabled(_ disabled: Bool, userID: UUID) async throws {
        try await remote.setAccountDisabled(userID: userID, disabled: disabled)
        let stamp = disabled ? ExecutionStore.timestamp(Date()) : nil
        try await database.writer.write { db in
            if var profile = try ProfileRecord.fetchOne(db, key: userID) {
                profile.disabledAt = stamp
                try profile.update(db)
            }
        }
    }

    /// Elimina l'account. Se `typed` non è l'email dell'account non parte nemmeno la richiesta.
    func delete(typed: String, email: String) async throws {
        guard DeleteConfirmation.matches(typed, email: email) else { throw AccountDeletionError.confirmMismatch }
        try await remote.deleteAccount(confirm: typed)
    }
}
