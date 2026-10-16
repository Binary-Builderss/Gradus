import Domain
import GRDB
import SwiftUI

/// Il profilo dell'utente (nel database locale): disattivato? manca il nome?
@MainActor
@Observable
final class AccountStatus {
    private(set) var disabled = false
    /// Il nome si chiede quando il profilo è già arrivato sul telefono e il nome è vuoto (l'invito del coach non lo aveva).
    private(set) var needsName = false

    func watch(database: AppDatabase, userID: UUID) async {
        // Se la lettura fallisce resta lo stato di prima: l'avviso lo dà già la schermata che legge gli stessi dati.
        _ = await database.watch(
            { db -> [Bool] in
                guard let profile = try ProfileRecord.fetchOne(db, key: userID) else { return [false, false] }
                return [profile.disabledAt != nil, ProfileName.normalized(profile.fullName ?? "") == nil]
            }
        ) { flags in
            disabled = flags[0]
            needsName = flags[1]
        }
    }
}
