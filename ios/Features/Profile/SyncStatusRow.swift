import SwiftUI

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
