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

extension View {
    /// Liquid Glass da iOS 26 (con il colore `tint` se c'è); sotto, un materiale sfocato (o il colore pieno).
    /// Va sul livello dei controlli che galleggiano sopra i contenuti, mai sulle schede dei contenuti.
    @ViewBuilder
    func glass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26, *) {
            let base = tint.map { Glass.regular.tint($0) } ?? Glass.regular
            self.glassEffect(interactive ? base.interactive() : base, in: shape)
        } else if let tint {
            self.background(tint, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }
}

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

/// Un tasto secondario su un fondo normale: vetro da iOS 26, «bordered» sotto.
struct SecondaryActionStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

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
