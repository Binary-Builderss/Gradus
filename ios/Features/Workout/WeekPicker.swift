import Domain
import GRDB
import SwiftUI

/// Le settimane del mesociclo, una per chip; quelle di scarico hanno un segno. Galleggia in vetro sopra le schede.
struct WeekPicker: View {
    @Environment(\.palette) private var palette
    let weeks: Int
    let deload: Set<Int>
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassContainer {
                    HStack(spacing: Theme.Space.s) {
                        ForEach(1...max(weeks, 1), id: \.self) { w in
                            chip(w)
                        }
                    }
                    .padding(Theme.Space.xs)
                }
            }
            .scrollIndicators(.hidden)
            .glass(.capsule)
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
            .onChange(of: selected) { _, new in withAnimation { proxy.scrollTo(new, anchor: .center) } }
        }
    }

    private func chip(_ w: Int) -> some View {
        let isSelected = w == selected
        return Button {
            onSelect(w)
        } label: {
            Text(deload.contains(w) ? "S\(w) ↓" : "S\(w)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? palette.onPrimary : palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(isSelected ? palette.accent : .clear, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .id(w)
        .accessibilityLabel(deload.contains(w) ? "Settimana \(w), scarico" : "Settimana \(w)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
