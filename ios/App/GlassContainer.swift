import SwiftUI

/// Raggruppa più elementi di vetro (da iOS 26 si fondono tra loro); sotto è solo il contenuto.
struct GlassContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer { content }
        } else {
            content
        }
    }
}
