import SwiftUI

/// Accesso o sezioni dell'app. Check e Progressi arrivano nelle fasi successive.
struct RootView: View {
    let environment: AppEnvironment
    @State private var auth: AuthModel
    @Environment(\.scenePhase) private var scenePhase

    init(environment: AppEnvironment) {
        self.environment = environment
        _auth = State(initialValue: environment.auth)
    }

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                ProgressView()
            case .signedOut:
                LoginView(auth: auth)
            case .signedIn(let userID):
                MainTabs(environment: environment, userID: userID)
                    // Si sincronizza all'accesso e ogni volta che l'app torna in primo piano.
                    .task(id: scenePhase) {
                        if scenePhase == .active {
                            environment.restTimer.refresh()
                            await environment.reminders.setUser(userID)
                            await environment.sync.sync()
                            await environment.reminders.refresh()
                        }
                    }
            }
        }
        .task { await auth.restore() }
    }
}
