import SwiftUI

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
