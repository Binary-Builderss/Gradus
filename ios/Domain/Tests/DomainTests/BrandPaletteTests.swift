import Testing

@testable import Domain

struct BrandPaletteTests {
    @Test("«#RRGGBB» si legge con o senza cancelletto e in qualsiasi maiuscola")
    func parsesHex() {
        #expect(RGB(hex: "#0D54F3") == RGB(red: 0x0D, green: 0x54, blue: 0xF3))
        #expect(RGB(hex: "0d54f3") == RGB(red: 0x0D, green: 0x54, blue: 0xF3))
        #expect(RGB(hex: " #FFFFFF ") == RGB(red: 255, green: 255, blue: 255))
    }

    @Test("un valore non valido non è un colore")
    func rejectsInvalid() {
        for bad in ["", "#FFF", "#GGGGGG", "#0D54F3AA", "rosso", "##0D54F3", "+12345"] { #expect(RGB(hex: bad) == nil, "\(bad)") }
    }

    @Test("le chiavi assenti o non valide restano lo standard")
    func missingKeysStayStandard() {
        let palette = BrandPalette(colors: ["primary": "#112233", "surface": "boh", "altro": "#000000"])
        #expect(palette.primary == RGB(red: 0x11, green: 0x22, blue: 0x33))
        #expect(palette.surface == nil)
        #expect(palette.background == nil)
        #expect(BrandPalette(colors: [:]) == .standard)
    }

    @Test("sul colore principale il testo è bianco o nero, quello che si legge meglio")
    func readableText() {
        let white = RGB(red: 255, green: 255, blue: 255)
        let black = RGB(red: 0, green: 0, blue: 0)
        #expect(RGB(hex: "#0D54F3")?.readableText == white)  // il blu di Gradus
        #expect(RGB(hex: "#FFD60A")?.readableText == black)  // un giallo
        #expect(RGB(hex: "#000000")?.readableText == white)
        #expect(RGB(hex: "#FFFFFF")?.readableText == black)
        #expect(white.contrast(with: black) > 20.9)
    }

    @Test("tutte e sette le chiavi del sito")
    func allKeys() {
        let palette = BrandPalette(colors: [
            "primary": "#010101", "on_primary": "#020202", "background": "#030303", "foreground": "#040404",
            "surface": "#050505", "muted_foreground": "#060606", "border": "#070707",
        ])
        #expect(palette.onPrimary?.red == 2)
        #expect(palette.background?.red == 3)
        #expect(palette.foreground?.red == 4)
        #expect(palette.surface?.red == 5)
        #expect(palette.mutedForeground?.red == 6)
        #expect(palette.border?.red == 7)
    }
}
