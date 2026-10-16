import SwiftUI

/// Account: nome, email, coach e password.
struct AccountView: View {
    let environment: AppEnvironment
    let userID: UUID
    let model: ProfileModel
    @State private var editingName = false
    @State private var sending = false
    @State private var sentTo: String?
    @State private var failed = false

    var body: some View {
        List {
            Section {
                Button {
                    editingName = true
                } label: {
                    LabeledContent("Nome") {
                        HStack(spacing: 6) {
                            Text(model.snapshot.name ?? "Aggiungi").foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                    }
                }
                .foregroundStyle(.primary)
                LabeledContent("Email", value: model.snapshot.email ?? "–")
                LabeledContent("Coach", value: model.snapshot.coach ?? "Nessuno")
            } footer: {
                Text("Il nome è quello con cui il tuo coach ti vede.")
            }
            Section {
                Button {
                    Task { await sendReset() }
                } label: {
                    HStack {
                        Text("Cambia password")
                        if sending { Spacer(); ProgressView() }
                    }
                }
                .disabled(sending || model.snapshot.email == nil)
            } header: {
                Text("Password")
            } footer: {
                if let sentTo {
                    Text("Ti ho mandato un'email a \(sentTo): apri il link per scegliere una nuova password.")
                } else if failed {
                    Text("Non sono riuscito a mandare l'email. Controlla la rete e riprova.").foregroundStyle(.red)
                } else {
                    Text("Ti mandiamo un'email con il link per sceglierne una nuova.")
                }
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editingName) {
            NamePromptView(environment: environment, userID: userID, initial: model.snapshot.name ?? "", canSkip: false) {
                editingName = false
            }
        }
    }

    private func sendReset() async {
        guard let email = model.snapshot.email else { return }
        sending = true
        sentTo = nil
        failed = false
        await environment.auth.sendPasswordReset(email: email)
        if environment.auth.error == nil { sentTo = email } else { failed = true }
        sending = false
    }
}
