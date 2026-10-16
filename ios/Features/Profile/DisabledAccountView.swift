import Domain
import GRDB
import SwiftUI

struct DisabledAccountView: View {
    let environment: AppEnvironment
    let userID: UUID
    @State private var working = false
    @State private var failed = false

    var body: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                "Account disattivato",
                systemImage: "pause.circle",
                description: Text("Hai disattivato il tuo account. I tuoi dati sono al sicuro: riattivalo per tornare ad allenarti."))
            if failed {
                Text("Non sono riuscito a riattivarlo. Controlla la rete e riprova.").font(.callout).foregroundStyle(.red)
            }
            Button {
                Task {
                    working = true
                    failed = false
                    do {
                        try await AccountStore(database: environment.database, remote: environment.remote).reactivate(userID: userID)
                        await environment.sync.sync()
                    } catch { failed = true }
                    working = false
                }
            } label: {
                Text("Riattiva l'account").fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(working)
            Button("Esci") { Task { await environment.auth.signOut() } }
        }
        .padding(24)
    }
}
