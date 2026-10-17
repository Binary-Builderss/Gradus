import Foundation
import Observation

/// Il marchio del coach, letto dal database locale: l'interfaccia lo segue da qui e si aggiorna quando cambia.
@MainActor
@Observable
final class BrandingModel {
    private(set) var branding = Branding.standard

    func watch(database: AppDatabase) async {
        _ = await database.watch({ db in try BrandingStore.current(db) }) { branding = $0 }
    }
}
