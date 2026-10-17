import Domain
import SwiftUI

/// Barra in basso, in vetro: tempo residuo, −15 s, +15 s, Salta. Galleggia sopra la schermata e si vede in tutta
/// l'app finché c'è un timer.
struct RestTimerBar: View {
    @Environment(\.palette) private var palette
    let timer: RestTimerModel
    /// Dentro l'accessorio della tab bar (iOS 26.1+) il vetro e i margini li mette il sistema.
    var inAccessory = false

    var body: some View {
        if let state = timer.state {
            HStack(spacing: Theme.Space.m) {
                VStack(alignment: .leading, spacing: 0) {
                    TimelineView(.periodic(from: .now, by: 0.5)) { context in
                        Text(RestTimerState.clock(state.remainingSeconds(at: context.date)))
                            .font(.title2.monospacedDigit().weight(.semibold))
                    }
                    Text(state.title).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button("−15 s") { timer.adjust(bySeconds: -15) }
                Button("+15 s") { timer.adjust(bySeconds: 15) }
                Button("Salta") { timer.skip() }.bold()
            }
            .frame(minHeight: 44)
            .buttonStyle(.plain)
            .foregroundStyle(palette.accent)
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.s)
            .modifier(FloatingGlass(enabled: !inAccessory))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Timer di recupero")
        }
    }
}
