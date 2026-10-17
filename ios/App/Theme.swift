import SwiftUI

/// Le misure dell'app. I colori sono nella `Palette` (ambiente `\.palette`): quelli standard stanno nel catalogo, con
/// variante scura, e i nomi ricalcano le chiavi di `coach_branding`.
enum Theme {

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
