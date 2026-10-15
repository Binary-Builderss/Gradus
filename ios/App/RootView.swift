import SwiftUI

/// Le sezioni dell'app (tab bar). Check e Progressi arrivano nelle fasi successive.
struct RootView: View {
    var body: some View {
        TabView {
            WorkoutHomeView()
                .tabItem { Label("tab.workout", systemImage: "figure.strengthtraining.traditional") }
            ProfileView()
                .tabItem { Label("tab.profile", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    RootView()
}
