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

enum MainTab: Hashable {
    case workout, macro, profile
}

struct MainTabs: View {
    let environment: AppEnvironment
    let userID: UUID
    @State private var selection: MainTab = .workout

    var body: some View {
        let coordinator = environment.reminders.coordinator
        AccountGate(environment: environment, userID: userID) {
            TabView(selection: $selection) {
                WorkoutHomeView(environment: environment, userID: userID)
                    .tabItem { Label("Allenamento", systemImage: "figure.strengthtraining.traditional") }
                    .tag(MainTab.workout)
                MacroView(environment: environment, userID: userID)
                    .tabItem { Label("Macro", systemImage: "fork.knife") }
                    .tag(MainTab.macro)
                ProfileView(environment: environment, userID: userID)
                    .tabItem { Label("Profilo", systemImage: "person.crop.circle") }
                    .tag(MainTab.profile)
            }
            // Un promemoria dei macro toccato porta alla scheda Macro.
            .onChange(of: coordinator.openDay) { _, day in if day != nil { selection = .macro } }
            .onChange(of: coordinator.askManualEntry) { _, day in if day != nil { selection = .macro } }
            // Un solo timer per tutta l'app: resta visibile mentre si passa da una schermata all'altra.
            .safeAreaInset(edge: .bottom, spacing: 0) { RestTimerBar(timer: environment.restTimer) }
        }
    }
}
