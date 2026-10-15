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
                        if scenePhase == .active { await environment.sync.sync() }
                    }
            }
        }
        .task { await auth.restore() }
    }
}

struct MainTabs: View {
    let environment: AppEnvironment
    let userID: UUID

    var body: some View {
        AccountGate(environment: environment, userID: userID) {
            TabView {
                WorkoutHomeView(environment: environment, userID: userID)
                    .tabItem { Label("Allenamento", systemImage: "figure.strengthtraining.traditional") }
                ProfileView(environment: environment, userID: userID)
                    .tabItem { Label("Profilo", systemImage: "person.crop.circle") }
            }
        }
    }
}
