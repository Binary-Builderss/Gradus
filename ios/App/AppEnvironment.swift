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
                try? database.erase()
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

    /// L'ambiente vero dell'app, oppure nil se manca la configurazione.
    static func live() -> AppEnvironment? {
        guard let config = AppConfig.current else { return nil }
        let database = (try? AppDatabase.onDisk()) ?? (try! AppDatabase.inMemory())
        return AppEnvironment(config: config, database: database)
    }
}
