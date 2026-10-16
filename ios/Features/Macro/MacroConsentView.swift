import Domain
import SwiftUI

/// Il consenso a registrare i macro e a condividerli con il coach. Sono dati sulla salute: si chiede in modo esplicito e si
/// può ritirare quando vuoi dal Profilo (i giorni registrati vengono cancellati).
struct MacroConsentView: View {
    let environment: AppEnvironment
    let userID: UUID
    let onClose: () -> Void
    @State private var working = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("I tuoi macro").font(.title.bold())
                VStack(alignment: .leading, spacing: 10) {
                    Label("Registri ogni giorno se hai rispettato i macro, e se vuoi quanto hai assunto.", systemImage: "checkmark.circle")
                    Label("Li vede il tuo coach, nessun altro.", systemImage: "person.2")
                    Label("Escono dal telefono solo i totali del giorno, mai i singoli alimenti.", systemImage: "lock")
                    Label("Puoi ritirare il consenso quando vuoi dal Profilo: i giorni registrati vengono cancellati.", systemImage: "arrow.uturn.backward")
                }
                .font(.subheadline)
                Text("Sono dati sulla tua salute: li trattiamo solo con il tuo consenso esplicito.").font(.footnote).foregroundStyle(.secondary)
                if failed {
                    Text("Non sono riuscito a salvare il consenso. Controlla la rete e riprova.").font(.callout).foregroundStyle(.red)
                }
                Button {
                    Task { await grant() }
                } label: {
                    Text("Acconsento").fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(working)
                Button("Non ora") { onClose() }.frame(maxWidth: .infinity)
                Spacer()
            }
            .padding(24)
        }
    }

    private func grant() async {
        working = true
        failed = false
        do {
            try await NutritionStore(database: environment.database, remote: environment.remote).grantConsent(userID: userID)
            onClose()
        } catch {
            failed = true
        }
        working = false
    }
}
