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
            // La guida cambia scheda da sola, e parte la prima volta (si rivede dal Profilo).
            .onChange(of: environment.tour.current?.id) { _, _ in
                if let tab = environment.tour.current?.tab { selection = tab }
            }
            .overlay { TourOverlay(tour: environment.tour) }
            .task {
                guard !environment.tour.hasSeen else { return }
                // Prima si aspetta che arrivino i dati (fino a 12 s), così la guida sa se c'è un programma da mostrare.
                for _ in 0..<40 where environment.sync.lastSync == nil { try? await Task.sleep(for: .milliseconds(300)) }
                try? await Task.sleep(for: .milliseconds(600))
                if !environment.tour.hasSeen, !environment.tour.isActive { await environment.startTour(userID: userID) }
            }
            // Un promemoria dei macro toccato porta alla scheda Macro.
            .onChange(of: coordinator.openDay) { _, day in if day != nil { selection = .macro } }
            .onChange(of: coordinator.askManualEntry) { _, day in if day != nil { selection = .macro } }
            // Un solo timer per tutta l'app: resta visibile mentre si passa da una schermata all'altra.
            .modifier(TimerAccessory(timer: environment.restTimer))
        }
    }
}
