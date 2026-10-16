import SwiftUI

/// Il tasto principale: vetro colorato da iOS 26, «borderedProminent» sotto.
struct ProminentActionStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}
