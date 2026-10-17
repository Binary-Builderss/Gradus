import SwiftUI

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
            // Il marchio del coach (colori, logo, nome) arriva dal database locale e cambia l'aspetto di tutta l'app.
            .brandStyle(environment.branding.branding)
            .task { await environment.branding.watch(database: environment.database) }
        }
    }
}
