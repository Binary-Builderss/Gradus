import GRDB
import SwiftUI

/// Se il profilo dell'utente (nel database locale) risulta disattivato.
@MainActor
@Observable
final class AccountStatus {
    private(set) var disabled = false

    func watch(database: AppDatabase, userID: UUID) async {
        let observation = ValueObservation.tracking { db in
            try ProfileRecord.fetchOne(db, key: userID)?.disabledAt != nil
        }
        do {
            for try await value in observation.values(in: database.writer) { disabled = value }
        } catch {}
    }
}

/// Un account disattivato non vede l'app: solo la schermata per riattivarlo o uscire (come sul web).
struct AccountGate<Content: View>: View {
    let environment: AppEnvironment
    let userID: UUID
    @ViewBuilder var content: Content
    @State private var status = AccountStatus()

    var body: some View {
        Group {
            if status.disabled {
                DisabledAccountView(environment: environment, userID: userID)
            } else {
                content
            }
        }
        .task { await status.watch(database: environment.database, userID: userID) }
    }
}

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
                        try await environment.remote.reactivateAccount(userID: userID)
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
