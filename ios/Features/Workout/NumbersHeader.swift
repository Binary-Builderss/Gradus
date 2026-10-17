import Domain
import SwiftUI

/// Intestazione della home: la settimana in cifre grandi, il mesociclo e chi lo ha scritto. Sul blu notte di Gradus, o sul
/// colore principale del coach se ha la personalizzazione.
struct NumbersHeader: View {
    @Environment(\.palette) private var palette
    let mesocycle: MesocycleRecord
    let coach: String?
    let selected: Int
    let branding: Branding

    private static let navy = Color(red: 0.118, green: 0.149, blue: 0.188)

    var body: some View {
        let text = palette.primary == nil ? Color.white : palette.onPrimary
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            CoachBadge(branding: branding).foregroundStyle(text.opacity(0.85))
            Text(mesocycle.name).font(.title2.bold())
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                Text("\(selected)").font(.system(size: 72, weight: .heavy).monospacedDigit())
                VStack(alignment: .leading, spacing: 2) {
                    Text("settimana di \(mesocycle.weeks)").font(.headline)
                    if let coach { Text("con \(coach)").font(.subheadline).opacity(0.75) }
                    if mesocycle.deloadWeeks.contains(selected) {
                        Label("Scarico", systemImage: "arrow.down.right.circle").font(.subheadline)
                    }
                }
            }
        }
        .foregroundStyle(text)
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.primary ?? Self.navy, in: .rect(cornerRadius: Theme.Radius.l))
        .accessibilityElement(children: .combine)
    }
}
