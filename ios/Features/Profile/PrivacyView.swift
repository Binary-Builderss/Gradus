import Domain
import GRDB
import SwiftUI

/// Privacy: il consenso a condividere i macro con il coach, e il modo di ritirarlo.
struct PrivacyView: View {
    let environment: AppEnvironment
    let userID: UUID
    @State private var consent: Bool?
    @State private var confirming = false
    @State private var working = false
    @State private var failed = false
    @State private var readFailed = false

    var body: some View {
        List {
            Section {
                switch consent {
                case true?:
                    Label("Condividi i tuoi macro con il coach", systemImage: "checkmark.shield.fill").foregroundStyle(.green)
                    Button("Ritira il consenso", role: .destructive) { confirming = true }.disabled(working)
                case false?:
                    Label("Non condividi i macro con il coach", systemImage: "shield.slash")
                    Text("Puoi dare il consenso dalla scheda Macro.").font(.footnote).foregroundStyle(.secondary)
                case nil:
                    if readFailed {
                        Text("Non riesco a leggere i dati sul telefono. Chiudi e riapri l'app.").foregroundStyle(.red)
                    } else {
                        ProgressView()
                    }
                }
            } header: {
                Text("Macro")
            } footer: {
                Text("Sono dati sulla tua salute: li vede solo il tuo coach e solo con il tuo consenso. Ritirandolo, i giorni che hai registrato vengono cancellati.")
            }
            if failed {
                Section { Text("Non sono riuscito a ritirare il consenso. Controlla la rete e riprova.").foregroundStyle(.red) }
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Ritirare il consenso?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Ritira e cancella i giorni", role: .destructive) { Task { await withdraw() } }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("I giorni di macro che hai registrato vengono cancellati e il coach non li vede più. Gli obiettivi restano.")
        }
        .task {
            let id = userID
            readFailed = await !environment.database.watch({ db in try NutritionStore.hasConsent(db, userID: id) }) { consent = $0 }
        }
    }

    private func withdraw() async {
        working = true
        failed = false
        do {
            try await NutritionStore(database: environment.database, remote: environment.remote).withdrawConsent(userID: userID)
            await environment.reminders.refresh()
        } catch {
            failed = true
        }
        working = false
    }
}
