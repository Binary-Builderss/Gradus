import SwiftUI
import UserNotifications

@main
struct GradusApp: App {
    @State private var environment: AppEnvironment?

    init() {
        let environment = AppEnvironment.live()
        _environment = State(initialValue: environment)
        // Le notifiche (timer e promemoria dei macro) le gestisce un solo delegato, con le azioni «Sì» / «No»; l'ambiente
        // gli si dà subito, perché toccando una notifica l'app può partire proprio da lì.
        NotificationRouter.shared.environment = environment
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        SystemReminderNotifier.registerCategory()
    }

    var body: some Scene {
        WindowGroup {
            if let environment {
                RootView(environment: environment)
            } else {
                MissingConfigView()
            }
        }
    }
}
