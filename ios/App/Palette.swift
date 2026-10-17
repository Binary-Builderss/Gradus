import Domain
import SwiftUI

/// I colori in uso: quelli standard di Gradus (dal catalogo, con variante scura) con sopra quelli scelti dal coach.
/// Il coach sceglie colori chiari: in tema scuro si applica solo il colore principale, il resto resta lo standard scuro.
struct Palette: Equatable {
    var background: Color
    var surface: Color
    var ink: Color
    var hairline: Color
    /// Testo sopra i riempimenti nel colore principale.
    var onPrimary: Color
    /// Il colore principale del coach; nil = quello standard (`AccentColor`).
    var primary: Color?

    /// Il colore delle azioni e delle selezioni: quello del coach o l'`AccentColor` di Gradus.
    var accent: Color { primary ?? .accentColor }

    static let standard = Palette(
        background: Color("Background"), surface: Color("Surface"), ink: Color("Ink"), hairline: Color("Hairline"),
        onPrimary: .white, primary: nil)

    init(background: Color, surface: Color, ink: Color, hairline: Color, onPrimary: Color, primary: Color?) {
        self.background = background
        self.surface = surface
        self.ink = ink
        self.hairline = hairline
        self.onPrimary = onPrimary
        self.primary = primary
    }

    init(_ brand: BrandPalette, scheme: ColorScheme) {
        self = .standard
        if let primary = brand.primary {
            self.primary = Color(primary)
            onPrimary = Color(brand.onPrimary ?? primary.readableText)
        }
        guard scheme == .light else { return }
        if let value = brand.background { background = Color(value) }
        if let value = brand.surface { surface = Color(value) }
        if let value = brand.foreground { ink = Color(value) }
        if let value = brand.border { hairline = Color(value) }
    }
}

extension Color {
    init(_ rgb: RGB) {
        self.init(red: Double(rgb.red) / 255, green: Double(rgb.green) / 255, blue: Double(rgb.blue) / 255)
    }
}

extension EnvironmentValues {
    @Entry var palette = Palette.standard
}

extension View {
    /// Mette nell'ambiente la palette del marchio del coach (o quella standard) e il colore principale come tinta.
    func brandStyle(_ branding: Branding) -> some View {
        modifier(BrandStyle(palette: branding.palette))
    }
}

private struct BrandStyle: ViewModifier {
    let palette: BrandPalette
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let resolved = Palette(palette, scheme: scheme)
        content
            .environment(\.palette, resolved)
            .tint(resolved.primary)
    }
}
