import SwiftUI

/// Colori e misure dell'app. I colori stanno nel catalogo (con variante scura); i nomi ricalcano le chiavi di
/// `coach_branding` (`background`, `foreground`, `surface`, `border`), così la palette del coach si potrà sostituire
/// senza rinominare niente.
enum Theme {
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let ink = Color("Ink")
    static let hairline = Color("Hairline")

    /// Griglia da 8 pt.
    enum Space {
        static let xs = 4.0
        static let s = 8.0
        static let m = 16.0
        static let l = 24.0
        static let xl = 32.0
    }

    enum Radius {
        static let s = 8.0
        static let m = 12.0
        static let l = 16.0
    }
}

extension View {
    /// Una scheda: superficie bianca (o scura) con un filo di contorno, senza ombra.
    func card(padding: Double = Theme.Space.m, fill: Color = Theme.surface) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: Theme.Radius.l))
            .overlay { RoundedRectangle(cornerRadius: Theme.Radius.l).stroke(Theme.hairline) }
    }
}
