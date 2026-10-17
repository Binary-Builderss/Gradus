import Domain
import SwiftUI

struct BlockSection: View {
    @Environment(\.palette) private var palette
    let model: ExerciseModel
    let block: BlockContent
    /// Il primo blocco dell'esercizio: la guida ne evidenzia la prescrizione e la prima serie.
    let isTourFirst: Bool
    let tourTimerKey: SetKey?
    var focused: FocusState<Bool>.Binding
    let startTimer: (SetKey) -> Void

    var body: some View {
        Section {
            if let target = model.backoffTarget(for: block) {
                Label(target, systemImage: "scope").font(.subheadline.weight(.semibold))
            }
            ForEach(0..<(model.setCounts[block.id] ?? 0), id: \.self) { idx in
                SetRow(
                    model: model, block: block, key: SetKey(block: block.id, idx: idx), isTourFirst: isTourFirst && idx == 0,
                    isTourTimer: SetKey(block: block.id, idx: idx) == tourTimerKey, focused: focused, startTimer: startTimer)
                    .id(SetKey(block: block.id, idx: idx))
                    .listRowBackground(palette.surface)
            }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(block.prescription?.text ?? "Nessuna prescrizione per questa settimana")
                    .font(.footnote).textCase(nil)
                if let rest = block.restS, rest > 0 {
                    Text("Recupero \(RestText.format(seconds: rest))").font(.footnote).textCase(nil)
                }
            }
            .tourTarget("exercise-block", if: isTourFirst)
        }
    }

    private var title: String {
        [Labels.role(block.role), Labels.technique(block.technique)].compactMap { $0 }.joined(separator: " · ")
    }
}
