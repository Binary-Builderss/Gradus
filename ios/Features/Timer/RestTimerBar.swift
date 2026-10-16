import Domain
import SwiftUI

/// Barra fissa in basso: tempo residuo, −15 s, +15 s, Salta. Si vede in tutta l'app finché c'è un timer.
struct RestTimerBar: View {
    let timer: RestTimerModel

    var body: some View {
        if let state = timer.state {
            HStack(spacing: 12) {
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
                Button("Salta") { timer.skip() }.fontWeight(.semibold)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Timer di recupero")
        }
    }
}
