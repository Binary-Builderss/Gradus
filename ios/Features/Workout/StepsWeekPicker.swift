import SwiftUI

/// Le settimane come una scala che sale (il motivo della G di Gradus): la scelta è piena, le precedenti sono grigie, le
/// successive vuote. Galleggia in vetro sopra le schede.
struct StepsWeekPicker: View {
    @Environment(\.palette) private var palette
    let weeks: Int
    let deload: Set<Int>
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        GlassContainer {
            HStack(alignment: .bottom, spacing: Theme.Space.xs) {
                ForEach(1...max(weeks, 1), id: \.self) { w in
                    step(w)
                }
            }
            .padding(.horizontal, Theme.Space.m)
            .padding(.vertical, Theme.Space.s)
        }
        .glass(.rect(cornerRadius: Theme.Radius.l))
    }

    private func step(_ w: Int) -> some View {
        let isSelected = w == selected
        let done = w < selected
        let height = 12 + 30 * Double(w) / Double(max(weeks, 1))
        return Button {
            onSelect(w)
        } label: {
            VStack(spacing: 2) {
                Text(deload.contains(w) ? "\(w)↓" : "\(w)")
                    .font(.footnote.weight(isSelected ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(isSelected ? palette.accent : Color.secondary)
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? palette.accent : done ? palette.ink.opacity(0.25) : Color.clear)
                    .overlay { if !isSelected && !done { RoundedRectangle(cornerRadius: 6).stroke(palette.ink.opacity(0.25)) } }
                    .frame(height: height)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .bottom)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(deload.contains(w) ? "Settimana \(w), scarico" : "Settimana \(w)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
