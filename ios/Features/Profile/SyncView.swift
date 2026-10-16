import SwiftUI

/// Stato della sincronizzazione e delle serie ancora da inviare.
struct SyncView: View {
    let environment: AppEnvironment
    let model: ProfileModel

    var body: some View {
        List {
            Section {
                SyncStatusRow(sync: environment.sync)
                if model.snapshot.unsent > 0 {
                    Label(
                        model.snapshot.unsent == 1 ? "1 serie da inviare" : "\(model.snapshot.unsent) serie da inviare",
                        systemImage: "arrow.up.circle"
                    )
                    .font(.subheadline).foregroundStyle(.orange)
                }
                Button("Sincronizza ora") { Task { await environment.sync.sync() } }
                    .disabled(environment.sync.state == .syncing)
            } footer: {
                Text("L'app funziona anche senza rete: le serie si salvano sul telefono e partono appena c'è connessione.")
            }
        }
        .navigationTitle("Sincronizzazione")
        .navigationBarTitleDisplayMode(.inline)
    }
}
