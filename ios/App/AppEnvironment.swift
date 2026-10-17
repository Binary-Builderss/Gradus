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
    let restTimer: RestTimerModel
    let reminders: MacroReminderCenter
    let tour = TourModel()
    let branding = BrandingModel()

    init(config: AppConfig, database: AppDatabase) {
        self.config = config
        self.database = database
        let client = SupabaseClient(
            supabaseURL: config.supabaseURL, supabaseKey: config.supabaseAnonKey,
            options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true)))
        let remote = SupabaseRemote(client: client)
        let timer = RestTimerModel()
        self.restTimer = timer
        let reminderCenter = MacroReminderCenter(database: database, remote: remote)
        self.reminders = reminderCenter
        let syncModel = SyncModel(engine: SyncEngine(remote: remote, database: database))
        self.remote = remote
        self.sync = syncModel
        self.auth = AuthModel(
            client: SupabaseAuthClient(client: client, resetRedirect: config.siteURL.appending(path: "nuova-password")),
            onSignOut: {
                // I dati sul telefono sono di chi era collegato: all'uscita si svuotano.
                AppEnvironment.eraseOnSignOut(database)
                syncModel.reset()
                timer.skip()
                Task { await reminderCenter.setUser(nil) }
            })
    }

    /// Fa partire la guida sul programma che c'è (le sue sedute); senza un mesociclo attivo salta i passi che lo mostrano.
    func startTour(userID: UUID) async {
        let program = try? await database.writer.read { db -> TourProgram? in
            let home = try ProgramQueries.home(db, athleteID: userID)
            guard home.mesocycle != nil else { return nil }
            return TourProgram(sessionNames: home.sessions.map(\.name), firstHasExercises: (home.sessions.first?.exerciseCount ?? 0) > 0)
        }
        tour.start(program: program ?? nil)
    }

    /// Una risposta al promemoria dei macro, anche se l'app si è appena aperta dalla notifica.
    func resolveReminder(_ action: ReminderAction, day: String) async {
        if let id = await auth.resolveUserID(), reminders.userID != id { await reminders.setUser(id) }
        await reminders.handle(action, day: day)
        sync.requestSync()
    }

    /// Segnato quando lo svuotamento all'uscita non è riuscito: all'avvio dopo si rifà prima di aprire i dati.
    static let pendingEraseKey = "pendingErase"

    /// Svuota i dati dell'utente che esce. Se non ci riesce (due tentativi) lo segna: sono dati di un altro, non devono
    /// restare per il prossimo che entra.
    static func eraseOnSignOut(_ database: AppDatabase, defaults: UserDefaults = .standard) {
        for _ in 0..<2 {
            if (try? database.erase()) != nil { return }
        }
        defaults.set(true, forKey: pendingEraseKey)
    }

    /// Il database da usare: quello su disco, dopo aver finito un'uscita rimasta a metà. Se non si apre o non si riesce a
    /// svuotare, uno vuoto in memoria (meglio nessun dato che quelli di un altro).
    static func openDatabase(
        onDisk: () throws -> AppDatabase = AppDatabase.onDisk, defaults: UserDefaults = .standard
    ) throws -> AppDatabase {
        guard let database = try? onDisk() else { return try AppDatabase.inMemory() }
        if defaults.bool(forKey: pendingEraseKey) {
            guard (try? database.erase()) != nil else { return try AppDatabase.inMemory() }
            defaults.removeObject(forKey: pendingEraseKey)
        }
        return database
    }

    /// L'ambiente vero dell'app, oppure nil se manca la configurazione o non si riesce ad aprire nessun database.
    static func live() -> AppEnvironment? {
        guard let config = AppConfig.current, let database = try? openDatabase() else { return nil }
        return AppEnvironment(config: config, database: database)
    }
}
