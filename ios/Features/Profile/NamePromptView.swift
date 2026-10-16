import Domain
import SwiftUI

/// «Come ti chiami?»: il nome con cui il coach ti vede. Si chiede al primo accesso se l'invito non lo aveva, e si
/// cambia dal Profilo. Senza rete non si dà per salvato: lo dice e si può riprovare.
struct NamePromptView: View {
    let environment: AppEnvironment
    let userID: UUID
    let initial: String
    /// Al primo accesso si può rimandare (il coach vedrà l'email); dal Profilo no.
    let canSkip: Bool
    let onDone: () -> Void
    @State private var name: String
    @State private var working = false
    @State private var message: String?
    @FocusState private var focused: Bool

    init(environment: AppEnvironment, userID: UUID, initial: String, canSkip: Bool, onDone: @escaping () -> Void) {
        self.environment = environment
        self.userID = userID
        self.initial = initial
        self.canSkip = canSkip
        self.onDone = onDone
        _name = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Come ti chiami?").font(.title.bold())
            Text("È il nome con cui il tuo coach ti vede.").foregroundStyle(.secondary)
            TextField("Nome e cognome", text: $name)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .padding(12)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .onSubmit { Task { await save() } }
            if let message { Text(message).font(.callout).foregroundStyle(.red) }
            Button {
                Task { await save() }
            } label: {
                Text("Continua").fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(working || ProfileName.normalized(name) == nil)
            if canSkip {
                Button("Più tardi") { onDone() }.frame(maxWidth: .infinity)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { focused = true }
    }

    private func save() async {
        guard !working, ProfileName.normalized(name) != nil else { return }
        working = true
        message = nil
        do {
            try await ProfileStore(database: environment.database, remote: environment.remote).setName(name, userID: userID)
            onDone()
        } catch {
            message = "Non sono riuscito a salvare il nome. Controlla la rete e riprova."
        }
        working = false
    }
}
