import Foundation
import Supabase

/// Costruisce e tiene insieme le parti dell'app: database locale, accesso, sincronizzazione. Nessuna View chiama la
/// rete: leggono dal database locale e si fanno sincronizzare da qui.
@MainActor
final class AppEnvironment {
    let config: AppConfig
    let database: AppDatabase
    let auth: AuthModel
    let sync: SyncModel
    let remote: any RemoteAPI

    init(config: AppConfig, database: AppDatabase) {
        self.config = config
        self.database = database
        let client = SupabaseClient(
            supabaseURL: config.supabaseURL, supabaseKey: config.supabaseAnonKey,
            options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true)))
        let remote = SupabaseRemote(client: client)
        let syncModel = SyncModel(engine: SyncEngine(remote: remote, database: database))
        self.remote = remote
        self.sync = syncModel
        self.auth = AuthModel(
            client: SupabaseAuthClient(client: client, resetRedirect: config.siteURL.appending(path: "nuova-password")),
            onSignOut: {
                // I dati sul telefono sono di chi era collegato: all'uscita si svuotano.
                try? database.erase()
                syncModel.reset()
            })
    }

    /// L'ambiente vero dell'app, oppure nil se manca la configurazione.
    static func live() -> AppEnvironment? {
        guard let config = AppConfig.current else { return nil }
        let database = (try? AppDatabase.onDisk()) ?? (try! AppDatabase.inMemory())
        return AppEnvironment(config: config, database: database)
    }
}
