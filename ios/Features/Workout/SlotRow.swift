import Domain
import GRDB
import SwiftUI

struct SlotRow: View {
    let slot: SlotContent
    let completion: Completion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(slot.exerciseName).font(.headline)
                Spacer()
                switch completion {
                case .complete: Label("Completo", systemImage: "checkmark.circle.fill").labelStyle(.iconOnly).foregroundStyle(.green)
                case .partial: Text("In corso").font(.footnote).foregroundStyle(.orange)
                case .empty: EmptyView()
                }
            }
            if let notes = slot.coachNotes, !notes.isEmpty {
                Text(notes).font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(slot.blocks) { block in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(blockTitle(block)).font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        if let prescription = block.prescription {
                            // In notazione da palestra («3×8–10 · BUF 2»); VoiceOver legge la versione a parole.
                            Text(prescription.shortText).font(.body.weight(.semibold).monospacedDigit())
                                .accessibilityLabel(prescription.text)
                        } else {
                            Text("Nessuna prescrizione").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if let rest = block.restS, rest > 0 {
                        Text("Recupero \(RestText.format(seconds: rest))").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func blockTitle(_ block: BlockContent) -> String {
        [Labels.role(block.role), Labels.technique(block.technique)].compactMap { $0 }.joined(separator: " · ")
    }
}
