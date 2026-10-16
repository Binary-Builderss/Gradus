import Domain
import SwiftUI

/// Il timer sopra la tab bar: da iOS 26.1 è il suo accessorio (come il lettore di Musica), prima una barra in vetro che
/// galleggia sopra le schede.
struct TimerAccessory: ViewModifier {
    let timer: RestTimerModel

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: timer.state != nil) { RestTimerBar(timer: timer, inAccessory: true) }
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) { RestTimerBar(timer: timer) }
        }
    }
}
