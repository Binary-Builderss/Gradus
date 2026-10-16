import GRDB

extension AppDatabase {
    /// Segue una lettura del database locale e passa ogni valore a `update`. Ritorna `false` se la lettura è fallita
    /// (non se il compito è stato annullato): chi chiama lo fa vedere invece di restare fermo in silenzio.
    @MainActor
    func watch<T: Sendable>(_ read: @escaping @Sendable (Database) throws -> T, update: (T) -> Void) async -> Bool {
        do {
            for try await value in ValueObservation.tracking(read).values(in: writer) { update(value) }
            return true
        } catch is CancellationError {
            return true
        } catch {
            return false
        }
    }
}
