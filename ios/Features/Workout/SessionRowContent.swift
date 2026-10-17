import Domain
import GRDB
import SwiftUI

/// Una seduta nell'elenco. `isNext`: la prima non completata (la «prossima»); `filled`: sta su un fondo colorato.
struct SessionRowContent: View {
    @Environment(\.palette) private var palette
    let session: SessionSummary
    let state: Completion
    let isNext: Bool
    let filled: Bool

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                if isNext {
                    Text("Prossima").font(.footnote.weight(.semibold)).foregroundStyle(filled ? palette.onPrimary.opacity(0.85) : palette.accent)
                }
                Text(session.name).font(.title3.bold())
                HStack(spacing: 6) {
                    Text(session.exerciseCount == 1 ? "1 esercizio" : "\(session.exerciseCount) esercizi")
                        .font(.subheadline).foregroundStyle(filled ? palette.onPrimary.opacity(0.85) : .secondary)
                    switch state {
                    case .complete: Label("Completa", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(filled ? palette.onPrimary : .green)
                    case .partial: Text("Iniziata").font(.subheadline).foregroundStyle(filled ? palette.onPrimary : .orange)
                    case .empty: EmptyView()
                    }
                }
            }
            if filled {
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.onPrimary.opacity(0.85))
            }
        }
        .foregroundStyle(filled ? palette.onPrimary : palette.ink)
        .padding(.vertical, 2)
    }
}
