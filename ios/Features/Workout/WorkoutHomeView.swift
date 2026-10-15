import SwiftUI

/// Allenamento (home): per ora solo lo stato vuoto. Mesociclo attivo, selettore settimana × seduta e lista dei
/// gruppi arrivano con la sincronizzazione.
struct WorkoutHomeView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "workout.empty.title",
                systemImage: "figure.strengthtraining.traditional",
                description: Text("workout.empty.description")
            )
            .navigationTitle("tab.workout")
        }
    }
}

#Preview {
    WorkoutHomeView()
}
