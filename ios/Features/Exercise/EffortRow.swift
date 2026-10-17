import Domain
import SwiftUI

/// Lo sforzo percepito (facoltativo, una volta per serie): una riga di tasti interi sulla scala del coach. Un tocco
/// sceglie, un secondo tocco toglie; il mezzo punto (2,5) si sceglie con il tocco lungo sul tasto.
struct EffortRow: View {
    @Environment(\.palette) private var palette
    let model: ExerciseModel
    let block: BlockContent
    let key: SetKey

    var body: some View {
        let scale = model.scale(for: block)
        let current = model.drafts[key]?.effort.flatMap { $0.scale == scale ? $0.value : nil }
        // La scala è scritta una volta nell'intestazione del blocco: qui solo i tasti.
        HStack(spacing: 8) {
            ForEach(EffortOptions.wholeValues(for: scale), id: \.self) { whole in
                chip(whole: whole, scale: scale, current: current)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(EffortOptions.title(for: scale))
    }

    private func chip(whole: Double, scale: EffortScale, current: Double?) -> some View {
        let half = EffortOptions.halfStep(above: whole, scale: scale)
        let shown = (half != nil && current == half) ? half! : whole  // il tasto mostra il mezzo punto se è quello scelto
        let selected = current == shown
        return Button {
            model.setEffort(key, selected ? nil : Effort(value: shown, scale: scale))
        } label: {
            Text(NumberInput.text(shown))
                .font(.body.monospacedDigit().weight(selected ? .bold : .regular))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? palette.onPrimary : Color.primary)
                .background(selected ? palette.accent : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.borderless)
        .contextMenu {
            Button(NumberInput.text(whole)) { model.setEffort(key, Effort(value: whole, scale: scale)) }
            if let half { Button(NumberInput.text(half)) { model.setEffort(key, Effort(value: half, scale: scale)) } }
            if current != nil { Button("Togli lo sforzo", role: .destructive) { model.setEffort(key, nil) } }
        }
        .accessibilityLabel("\(EffortOptions.title(for: scale)) \(NumberInput.text(shown))")
        .accessibilityHint("Tocco lungo per il mezzo punto")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
