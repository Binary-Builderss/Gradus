import Domain
import SwiftUI

/// Barra in basso, in vetro: tempo residuo, per cosa si recupera, −15 s, +15 s, Salta, e sotto una linea blu che si
/// svuota. Galleggia sopra la schermata e si vede in tutta l'app finché c'è un timer.
struct RestTimerBar: View {
    @Environment(\.palette) private var palette
    let timer: RestTimerModel
    /// Dentro l'accessorio della tab bar (iOS 26.1+) il vetro e i margini li mette il sistema.
    var inAccessory = false

    var body: some View {
        if let state = timer.state {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                HStack(spacing: Theme.Space.m) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(RestTimerState.clock(state.remainingSeconds(at: context.date)))
                            .font(.title2.monospacedDigit().weight(.semibold))
                        Text(state.title).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    // Icone al posto di «−15 s» / «+15 s»: lasciano spazio al nome dell'esercizio.
                    Button("Togli 15 secondi", systemImage: "gobackward.15") { timer.adjust(bySeconds: -15) }
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    Button("Aggiungi 15 secondi", systemImage: "goforward.15") { timer.adjust(bySeconds: 15) }
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    Button("Salta") { timer.skip() }.bold().frame(minHeight: 44)
                }
                .font(.title3)
                .overlay(alignment: .bottom) {
                    // La linea che si svuota mentre passa il recupero.
                    ProgressView(value: state.remainingFraction(at: context.date))
                        .tint(palette.accent)
                        .animation(.linear(duration: 0.5), value: state.remainingFraction(at: context.date))
                        .offset(y: inAccessory ? 2 : Theme.Space.xs)
                        .accessibilityHidden(true)
                }
            }
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

