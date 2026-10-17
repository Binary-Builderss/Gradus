import SwiftUI

/// Accesso con email e password. Gli account atleta li crea il coach: l'invito arriva per email e da lì si sceglie la
/// password; qui si entra con quella.
struct LoginView: View {
    @Environment(\.palette) private var palette
    @Bindable var auth: AuthModel
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?
    /// «Password dimenticata?» senza email: si spiega cosa serve invece di tenere il pulsante spento.
    @State private var resetNeedsEmail = false

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Image("Logo").resizable().scaledToFit().frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                    Text("Gradus Atleta").font(.largeTitle.bold())
                    Text("Accedi con l'account che ti ha dato il tuo coach.").foregroundStyle(.secondary)
                }
                .padding(.top, 48)

                VStack(alignment: .leading, spacing: 14) {
                    LabeledField(title: "Email") {
                        TextField("nome@esempio.it", text: $email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focus, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focus = .password }
                    }
                    LabeledField(title: "Password") {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .focused($focus, equals: .password)
                            .submitLabel(.go)
                            .onSubmit(submit)
                    }
                }

                if let error = auth.error {
                    Text(error.message).font(.callout).foregroundStyle(.red).accessibilityIdentifier("login-error")
                }
                if resetNeedsEmail {
                    Text("Scrivi qui sopra l'email del tuo account, poi tocca di nuovo «Password dimenticata?».")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if auth.resetSent {
                    Text("Se l'indirizzo è registrato, tra poco ricevi un'email con il link per scegliere una nuova password.")
                        .font(.callout).foregroundStyle(.secondary)
                }

                Button(action: submit) {
                    HStack {
                        if auth.isWorking { ProgressView().tint(.white) }
                        Text("Accedi").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .modifier(ProminentActionStyle())
                .disabled(auth.isWorking)

                Button("Password dimenticata?") {
                    if email.trimmingCharacters(in: .whitespaces).isEmpty {
                        resetNeedsEmail = true
                        focus = .email
                    } else {
                        resetNeedsEmail = false
                        Task { await auth.sendPasswordReset(email: email) }
                    }
                }
                .font(.callout)
                .disabled(auth.isWorking)

                Text("Hai ricevuto un invito dal tuo coach? Apri il link nell'email, scegli la password e poi accedi qui.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 480)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(palette.background)
    }

    private func submit() {
        focus = nil
        Task { await auth.signIn(email: email, password: password) }
    }
}
