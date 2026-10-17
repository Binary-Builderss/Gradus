import Domain
import Foundation
import Observation
import UserNotifications

/// Cosa fa l'atleta toccando il promemoria o le sue azioni.
enum ReminderAction: Equatable, Sendable {
    /// «Sì»: ha rispettato i macro. Si registra senza aprire l'app.
    case yes
    /// «No»: non li ha rispettati. Si registra e l'app chiede se vuole inserire quanto ha assunto.
    case no
    /// Tocco sulla notifica: si apre il giorno.
    case open
}

/// Le notifiche locali del promemoria, dietro un confine: i test usano un finto.
protocol ReminderNotifier: Sendable {
    /// Chiede il permesso la prima volta; dice se le notifiche sono consentite.
    func authorizeIfNeeded() async -> Bool
    /// Sostituisce tutti i promemoria programmati con questi.
    func replace(with items: [MacroReminder.Item]) async
}

struct SystemReminderNotifier: ReminderNotifier {
    static let prefix = "macro-evening-"
    static let category = "MACRO_EVENING"
    static let yesAction = "MACRO_YES"
    static let noAction = "MACRO_NO"

    /// Le azioni «Sì» (in background, senza aprire l'app) e «No» (apre l'app per chiedere se inserire i numeri).
    static func registerCategory() {
        let yes = UNNotificationAction(identifier: yesAction, title: "Sì", options: [])
        let no = UNNotificationAction(identifier: noAction, title: "No", options: [.foreground])
        let category = UNNotificationCategory(identifier: category, actions: [yes, no], intentIdentifiers: [], options: [])
        let center = UNUserNotificationCenter.current()
        Task {
            var categories = await center.notificationCategories()
            categories.update(with: category)
            center.setNotificationCategories(categories)
        }
    }

    func authorizeIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied: return false
        default: return true
        }
    }

    func replace(with items: [MacroReminder.Item]) async {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)
        for item in items {
            let content = UNMutableNotificationContent()
            content.title = "I tuoi macro di oggi"
            content.body = "Hai rispettato i macro di oggi?"
            content.sound = .default
            content.categoryIdentifier = Self.category
            content.userInfo = ["day": item.day]
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: Self.prefix + item.day, content: content, trigger: trigger))
        }
    }
}

/// Cosa l'app deve mostrare dopo un promemoria: aprire un giorno, o chiedere se inserire i numeri.
@MainActor
@Observable
final class MacroReminderCoordinator {
    /// Dopo «No»: l'app chiede se l'atleta vuole inserire quanto ha assunto in quel giorno.
    var askManualEntry: String?
    /// Dopo il tocco sulla notifica: apre il giorno.
    var openDay: String?
}

/// Il promemoria serale dei macro, personalizzabile (acceso o spento, e l'orario). Si riprogramma a ogni apertura
/// dell'app, dopo ogni modifica e dopo ogni registrazione: i giorni già registrati non ricevono la notifica.
@MainActor
final class MacroReminderCenter {
    static let enabledKey = "macroReminderEnabled"
    static let minutesKey = "macroReminderMinutes"

    let coordinator: MacroReminderCoordinator
    private let database: AppDatabase
    private let remote: any RemoteAPI
    private let notifier: any ReminderNotifier
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private(set) var userID: UUID?

    init(
        database: AppDatabase, remote: any RemoteAPI, notifier: any ReminderNotifier = SystemReminderNotifier(),
        coordinator: MacroReminderCoordinator = MacroReminderCoordinator(), defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }, calendar: Calendar = .current
    ) {
        self.database = database
        self.remote = remote
        self.notifier = notifier
        self.coordinator = coordinator
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
    }

    // MARK: Impostazioni

    /// Acceso di default (dopo il consenso), alle 22:00.
    var enabled: Bool { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }
    var minutes: Int { MacroReminder.clamp(defaults.object(forKey: Self.minutesKey) as? Int ?? MacroReminder.defaultMinutes) }

    func setEnabled(_ value: Bool) async {
        defaults.set(value, forKey: Self.enabledKey)
        await refresh()
    }

    func setMinutes(_ value: Int) async {
        defaults.set(MacroReminder.clamp(value), forKey: Self.minutesKey)
        await refresh()
    }

    // MARK: Programmazione

    /// Da chiamare quando si sa chi è collegato (accesso) e a ogni uscita (`nil`: si toglie tutto).
    func setUser(_ id: UUID?) async {
        userID = id
        await refresh()
    }

    /// Riprogramma: niente senza consenso, a promemoria spento o senza permesso; altrimenti i prossimi giorni non registrati.
    func refresh() async {
        guard let userID, enabled, let state = try? await readState(userID), state.consent, await notifier.authorizeIfNeeded() else {
            await notifier.replace(with: [])
            return
        }
        await notifier.replace(
            with: MacroReminder.plan(now: now(), minutes: minutes, registeredDays: state.registered, calendar: calendar))
    }

    private func readState(_ userID: UUID) async throws -> (consent: Bool, registered: Set<String>) {
        let today = now()
        let calendar = calendar
        return try await database.writer.read { db in
            let snapshot = try NutritionStore.snapshot(db, athleteID: userID, today: today, calendar: calendar)
            return (snapshot.consent, Set(snapshot.days.filter { $0.status != nil }.map(\.day)))
        }
    }

    // MARK: Risposte al promemoria

    /// «Sì» registra la giornata come rispettata; «No» come non rispettata e chiede se inserire i numeri; il tocco apre il
    /// giorno. Senza consenso o fuori dai 14 giorni non si scrive nulla.
    func handle(_ action: ReminderAction, day: String) async {
        switch action {
        case .open:
            coordinator.openDay = day
        case .yes, .no:
            guard let userID else { return }
            let status: MacroDayStatus = action == .yes ? .respected : .notRespected
            let store = NutritionStore(database: database, remote: remote)
            do {
                try await store.save(DayEdit(athleteID: userID, day: day, status: status, intake: MacroIntake()), today: now(), calendar: calendar)
            } catch {
                if action == .no { coordinator.askManualEntry = day }  // l'app dirà perché non ha salvato
                return
            }
            if action == .no { coordinator.askManualEntry = day }
            await refresh()
        }
    }
}

/// Riceve i tocchi sulle notifiche (anche con l'app chiusa) e li passa al promemoria.
@MainActor
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()
    var environment: AppEnvironment?

    /// Con l'app aperta si vedono sia il promemoria dei macro sia la fine del recupero; il suono del timer lo suona
    /// l'app (`SystemRestFeedback`, secondo le Preferenze), quindi qui solo il banner.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let id = notification.request.identifier
        if id.hasPrefix(SystemReminderNotifier.prefix) { return [.banner, .sound] }
        return id == SystemRestNotifier.id ? [.banner, .list] : []
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let request = response.notification.request
        guard request.identifier.hasPrefix(SystemReminderNotifier.prefix), let day = request.content.userInfo["day"] as? String
        else { return }
        let action: ReminderAction
        switch response.actionIdentifier {
        case SystemReminderNotifier.yesAction: action = .yes
        case SystemReminderNotifier.noAction: action = .no
        default: action = .open
        }
        await MainActor.run {
            Task { await self.environment?.resolveReminder(action, day: day) }
        }
    }
}
