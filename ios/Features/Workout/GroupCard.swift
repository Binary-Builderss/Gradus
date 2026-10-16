import Domain
import GRDB
import SwiftUI

/// Un gruppo di esercizi (un esercizio solo, o un superset): una scheda con una riga per esercizio.
struct GroupCard: View {
    let group: GroupContent
    let header: String
    let content: SessionContent
    let firstSlotID: UUID?
    let onOpen: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if !header.isEmpty {
                Text(header).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                    .padding(.horizontal, Theme.Space.xs)
            }
            VStack(spacing: 0) {
                ForEach(group.slots) { slot in
                    if slot.id != group.slots.first?.id { Divider() }
                    row(slot)
                }
            }
            .card()
        }
    }

    private func row(_ slot: SlotContent) -> some View {
        Button {
            onOpen(slot.id)
        } label: {
            HStack(alignment: .top) {
                SlotRow(slot: slot, completion: content.completion(of: slot))
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    .padding(.top, Theme.Space.s)
            }
            .padding(.vertical, Theme.Space.s)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .tourTarget("session-exercise", if: slot.id == firstSlotID)
    }
}
