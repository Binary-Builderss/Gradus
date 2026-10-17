import Foundation

/// Un colore `#RRGGBB`.
public struct RGB: Equatable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// «#0D54F3» (con o senza «#», maiuscole o minuscole); altro → nil. Come `normalizeHex` del sito, senza la forma corta.
    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, text.allSatisfy(\.isHexDigit), let value = UInt32(text, radix: 16) else { return nil }
        self.init(red: UInt8(value >> 16 & 0xFF), green: UInt8(value >> 8 & 0xFF), blue: UInt8(value & 0xFF))
    }
}

extension RGB {
    /// Luminanza relativa (WCAG), da 0 (nero) a 1 (bianco).
    public var luminance: Double {
        func channel(_ value: UInt8) -> Double {
            let s = Double(value) / 255
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// Rapporto di contrasto WCAG con un altro colore (da 1 a 21).
    public func contrast(with other: RGB) -> Double {
        let (hi, lo) = (max(luminance, other.luminance), min(luminance, other.luminance))
        return (hi + 0.05) / (lo + 0.05)
    }

    /// Bianco o nero, quello che si legge meglio sopra questo colore (per il testo sui tasti pieni quando il coach
    /// sceglie solo il colore principale).
    public var readableText: RGB {
        let white = RGB(red: 255, green: 255, blue: 255)
        let black = RGB(red: 0, green: 0, blue: 0)
        return contrast(with: white) >= contrast(with: black) ? white : black
    }
}

/// I colori scelti dal coach (`coach_branding.colors`): solo le chiavi presenti e valide, il resto resta lo standard di
/// Gradus. Il server già toglie le chiavi che il piano del coach non permette (livello 1: solo `primary`).
public struct BrandPalette: Equatable, Sendable {
    public var primary: RGB?
    public var onPrimary: RGB?
    public var background: RGB?
    public var foreground: RGB?
    public var surface: RGB?
    public var mutedForeground: RGB?
    public var border: RGB?

    public static let standard = BrandPalette()

    public init() {}

    public init(colors: [String: String]) {
        primary = colors["primary"].flatMap(RGB.init(hex:))
        onPrimary = colors["on_primary"].flatMap(RGB.init(hex:))
        background = colors["background"].flatMap(RGB.init(hex:))
        foreground = colors["foreground"].flatMap(RGB.init(hex:))
        surface = colors["surface"].flatMap(RGB.init(hex:))
        mutedForeground = colors["muted_foreground"].flatMap(RGB.init(hex:))
        border = colors["border"].flatMap(RGB.init(hex:))
    }
}
