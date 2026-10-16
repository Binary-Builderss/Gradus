import SwiftUI

/// Solo per chi sviluppa: manca l'indirizzo del server. Un'app consegnata non la mostra mai.
struct MissingConfigView: View {
    var body: some View {
        ContentUnavailableView(
            "Configurazione mancante",
            systemImage: "gearshape.2",
            description: Text(
                "Copia ios/Config/Secrets.example.xcconfig in Secrets.xcconfig e inserisci l'indirizzo e la chiave pubblica di Supabase.")
        )
    }
}
