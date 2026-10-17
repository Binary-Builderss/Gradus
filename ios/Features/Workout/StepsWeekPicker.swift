import SwiftUI

/// Le settimane come una scala che sale (il motivo della G di Gradus): la scelta è piena, quelle già passate (rispetto a
/// oggi, non alla scelta) sono grigie, le prossime vuote e quella in corso ha il contorno blu. Galleggia in vetro sopra
/// le schede; se le settimane non ci stanno (oltre 8-9 su un iPhone), la scala scorre di lato.
struct StepsWeekPicker: View {
    @Environment(\.palette) private var palette
    let weeks: Int
    let deload: Set<Int>
    let selected: Int
    /// La settimana di calendario in corso.
    let current: Int
    let onSelect: (Int) -> Void

    var body: some View {
        GlassContainer {
            ViewThatFits(in: .horizontal) {
                steps
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) { steps }
                        .onAppear { proxy.scrollTo(selected, anchor: .center) }
                        .onChange(of: selected) { _, w in withAnimation { proxy.scrollTo(w, anchor: .center) } }
                }
            }
        }
        .glass(.rect(cornerRadius: Theme.Radius.l))
    }

    private var steps: some View {
        HStack(alignment: .bottom, spacing: Theme.Space.xs) {
            ForEach(1...max(weeks, 1), id: \.self) { w in
                step(w).id(w)
            }
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.s)
    }

    private func step(_ w: Int) -> some View {
        let isSelected = w == selected
        let done = w < current
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
                    .overlay {
                        if !isSelected && !done {
                            RoundedRectangle(cornerRadius: 6).stroke(w == current ? palette.accent : palette.ink.opacity(0.25), lineWidth: w == current ? 2 : 1)
                        }
                    }
                    .frame(height: height)
            }
            // ponytail: 36 pt di larghezza minima così 8-9 settimane stanno su un iPhone senza scorrere; oltre, la scala scorre.
            .frame(minWidth: 36, maxWidth: .infinity, minHeight: 44, alignment: .bottom)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settimana \(w)\(deload.contains(w) ? ", scarico" : "")\(w == current ? ", in corso" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
