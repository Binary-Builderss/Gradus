import SwiftUI

extension View {
    /// Una scheda: superficie (bianca o scura, o del coach) con un filo di contorno, senza ombra. `fill` la colora.
    func card(padding: Double = Theme.Space.m, fill: Color? = nil) -> some View {
        modifier(CardStyle(padding: padding, fill: fill))
    }
}

private struct CardStyle: ViewModifier {
    let padding: Double
    let fill: Color?
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill ?? palette.surface, in: .rect(cornerRadius: Theme.Radius.l))
            .overlay { RoundedRectangle(cornerRadius: Theme.Radius.l).stroke(palette.hairline) }
    }
}
