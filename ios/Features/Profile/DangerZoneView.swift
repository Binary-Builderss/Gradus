import Domain
import SwiftUI

/// Disattivare (reversibile) o eliminare (definitivo) l'account. Stesse regole del sito.
struct DangerZoneView: View {
    let environment: AppEnvironment
    let userID: UUID
    let model: ProfileModel
    @State private var confirmingDisable = false
    @State private var confirmingDelete = false
    @State private var typed = ""
    @State private var working = false
    @State private var message: String?

    private var store: AccountStore { AccountStore(database: environment.database, remote: environment.remote) }
    private var email: String { model.snapshot.email ?? "" }

    var body: some View {
        List {
            Section {
                Button("Disattiva l'account") { confirmingDisable = true }
                    .disabled(working)
            } header: {
                Text("Disattiva")
            } footer: {
                Text("I tuoi dati restano al sicuro e puoi riattivare l'account quando vuoi. Intanto non vedi i programmi.")
            }
            Section {
                Button("Elimina l'account", role: .destructive) {
                    typed = ""
                    confirmingDelete = true
                }
                .disabled(working)
            } header: {
                Text("Elimina")
            } footer: {
                Text("È definitivo: l'account e le tue serie registrate vengono cancellati. I programmi scritti dal tuo coach restano al coach.")
            }
            if let message {
                Section { Text(message).font(.callout).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Disattiva o elimina")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Disattivare l'account?", isPresented: $confirmingDisable, titleVisibility: .visible) {
            Button("Disattiva") { Task { await disable() } }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Potrai riattivarlo in qualsiasi momento: i dati non vengono toccati.")
        }
        .alert("Eliminare l'account?", isPresented: $confirmingDelete) {
            TextField("Scrivi la tua email", text: $typed)
                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.emailAddress)
            Button("Elimina per sempre", role: .destructive) { Task { await delete() } }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Non si può annullare. Per confermare scrivi la tua email: \(email)")
        }
    }

    private func disable() async {
        working = true
        message = nil
        do {
            try await store.disable(userID: userID)  // il cancello dell'account mostra subito la schermata «Account disattivato»
        } catch {
            message = "Non sono riuscito a disattivare l'account. Controlla la rete e riprova."
        }
        working = false
    }

    private func delete() async {
        working = true
        message = nil
        do {
            try await store.delete(typed: typed, email: email)
            await environment.auth.signOut()  // l'utente non esiste più: si svuota il telefono e si torna all'accesso
        } catch AccountDeletionError.confirmMismatch {
            message = "L'email scritta non coincide con quella dell'account."
        } catch AccountDeletionError.subscriptionActive {
            message = "Hai un abbonamento attivo: disdicilo dal sito prima di eliminare l'account."
        } catch {
            message = "Non sono riuscito a eliminare l'account. Controlla la rete e riprova."
        }
        working = false
    }
}
