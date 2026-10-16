import SwiftUI

/// La lettura dei dati sul telefono è fallita: lo si dice, invece di mostrare una schermata che non si aggiorna più.
struct ReadFailedView: View {
    var body: some View {
        ContentUnavailableView(
            "Non riesco a leggere i dati",
            systemImage: "exclamationmark.triangle",
            description: Text("I dati sul telefono non si aprono. Chiudi e riapri l'app."))
    }
}
