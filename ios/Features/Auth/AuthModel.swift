import Foundation
import Observation
import Supabase

/// L'accesso, dietro un confine: i test usano un finto, l'app supabase-swift.
protocol AuthClient: Sendable {
    /// L'utente con la sessione salvata, se c'è (resta valida anche senza rete).
    func currentUserID() async -> UUID?
    func signIn(email: String, password: String) async throws -> UUID
    func signOut() async throws
    func sendPasswordReset(email: String) async throws
}

struct SupabaseAuthClient: AuthClient {
    let client: SupabaseClient
    /// Dove porta il link dell'email: la pagina del sito dove si sceglie la nuova password.
    let resetRedirect: URL

    func currentUserID() async -> UUID? {
        try? await client.auth.session.user.id
    }

    func signIn(email: String, password: String) async throws -> UUID {
        try await client.auth.signIn(email: email, password: password).user.id
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: resetRedirect)
    }
}

enum SignInError: Equatable {
    case invalidCredentials
    case network
    case other

    init(_ error: Error) {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain { self = .network; return }
        let text = "\(error)".lowercased()
        self = text.contains("invalid") && (text.contains("credentials") || text.contains("login")) ? .invalidCredentials : .other
    }

    var message: String {
        switch self {
        case .invalidCredentials: "Email o password non corrette."
        case .network: "Connessione non riuscita. Controlla la rete e riprova."
        case .other: "Qualcosa non ha funzionato. Riprova tra poco."
        }
    }
}

@MainActor
@Observable
final class AuthModel {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(UUID)
    }

    private(set) var state: State = .loading
    private(set) var isWorking = false
    private(set) var error: SignInError?
    private(set) var resetSent = false

    private let client: any AuthClient
    /// Chiamato all'uscita, per svuotare i dati locali dell'utente.
    private let onSignOut: @MainActor () -> Void

    init(client: any AuthClient, onSignOut: @escaping @MainActor () -> Void = {}) {
        self.client = client
        self.onSignOut = onSignOut
    }

    /// All'avvio: se c'è una sessione salvata si entra subito, anche offline.
    /// Chi è collegato, anche prima che `restore()` sia finito (serve quando l'app parte da una notifica).
    func resolveUserID() async -> UUID? {
        if case .signedIn(let id) = state { return id }
        return await client.currentUserID()
    }

    func restore() async {
        if let id = await client.currentUserID() { state = .signedIn(id) } else { state = .signedOut }
    }

    func signIn(email: String, password: String) async {
        let email = email.trimmingCharacters(in: .whitespaces)
        guard !email.isEmpty, !password.isEmpty else {
            error = .invalidCredentials
            return
        }
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            state = .signedIn(try await client.signIn(email: email, password: password))
        } catch {
            self.error = SignInError(error)
        }
    }

    func sendPasswordReset(email: String) async {
        let email = email.trimmingCharacters(in: .whitespaces)
        guard !email.isEmpty else { return }
        isWorking = true
        error = nil
        resetSent = false
        defer { isWorking = false }
        do {
            try await client.sendPasswordReset(email: email)
            resetSent = true
        } catch {
            self.error = SignInError(error)
        }
    }

    func signOut() async {
        try? await client.signOut()
        onSignOut()
        error = nil
        resetSent = false
        state = .signedOut
    }
}
