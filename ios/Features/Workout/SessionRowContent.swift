import Domain
import GRDB
import SwiftUI

/// Una seduta nell'elenco. `isNext`: la prima non completata (la «prossima»); `filled`: sta su un fondo colorato.
struct SessionRowContent: View {
    let session: SessionSummary
    let state: Completion
    let isNext: Bool
    let filled: Bool

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                if isNext {
                    Text("Prossima").font(.footnote.weight(.semibold)).foregroundStyle(filled ? .white.opacity(0.85) : Color.accentColor)
                }
                Text(session.name).font(.title3.bold())
                HStack(spacing: 6) {
                    Text(session.exerciseCount == 1 ? "1 esercizio" : "\(session.exerciseCount) esercizi")
                        .font(.subheadline).foregroundStyle(filled ? .white.opacity(0.85) : .secondary)
                    switch state {
                    case .complete: Label("Completa", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(filled ? .white : .green)
                    case .partial: Text("Iniziata").font(.subheadline).foregroundStyle(filled ? .white : .orange)
                    case .empty: EmptyView()
                    }
                }
            }
            if filled {
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
            }
        }
        .foregroundStyle(filled ? .white : Theme.ink)
        .padding(.vertical, 2)
    }
}
