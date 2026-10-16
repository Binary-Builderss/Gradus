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

struct SyncStatusRow: View {
    let sync: SyncModel

    var body: some View {
        HStack {
            switch sync.state {
            case .syncing:
                ProgressView()
                Text("Sincronizzo…")
            case .failed:
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                Text("Non riesco a sincronizzare. Riprovo appena c'è rete.")
            case .idle:
                Image(systemName: "checkmark.circle").foregroundStyle(.green)
                if let last = sync.lastSync {
                    Text("Aggiornato \(last.formatted(.relative(presentation: .named)))")
                } else {
                    Text("Non ancora sincronizzato")
                }
            }
        }
        .font(.subheadline)
    }
}
