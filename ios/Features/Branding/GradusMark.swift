import SwiftUI

/// La G a scalini di Gradus, in un solo colore (quello del testo che la circonda, o `foregroundStyle`).
struct GradusMark: View {
    var height = 28.0

    var body: some View {
        Image("Mark").resizable().scaledToFit().frame(height: height).accessibilityHidden(true)
    }
}
