import Foundation
import Observation

/// Lo stato della sincronizzazione, visibile nel Profilo. Non blocca mai l'interfaccia: i dati si leggono dal
/// database locale e la sincronizzazione parte in sottofondo (avvio, ritorno in primo piano, tirando giù l'elenco).
@MainActor
@Observable
final class SyncModel {
    enum State: Equatable {
        case idle
        case syncing
        case failed
    }

    private(set) var state: State = .idle
    private(set) var lastSync: Date?
    private let engine: SyncEngine
    private let defaults: UserDefaults
    private static let lastSyncKey = "lastSync"

    init(engine: SyncEngine, defaults: UserDefaults = .standard) {
        self.engine = engine
        self.defaults = defaults
        self.lastSync = defaults.object(forKey: Self.lastSyncKey) as? Date
    }

    func sync() async {
        guard state != .syncing else { return }
        state = .syncing
        do {
            _ = try await engine.sync()
            lastSync = Date()
            defaults.set(lastSync, forKey: Self.lastSyncKey)
            state = .idle
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed
        }
    }

    private var requested = false

    /// Chiede una sincronizzazione senza aspettarla (dopo un salvataggio): si accorpano le richieste ravvicinate e,
    /// se ne è in corso una, ne parte un'altra appena finisce, così l'ultima modifica va sempre via.
    func requestSync() {
        guard !requested else { return }
        requested = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            requested = false
            while state == .syncing { try? await Task.sleep(for: .milliseconds(300)) }
            await sync()
        }
    }

    /// All'uscita dall'account la data dell'ultima sincronizzazione non vale più.
    func reset() {
        lastSync = nil
        state = .idle
        defaults.removeObject(forKey: Self.lastSyncKey)
    }
}
