import Foundation
import Testing

@testable import Gradus

final class FakeAuth: AuthClient, @unchecked Sendable {
    var stored: UUID?
    var signInResult: Result<UUID, Error> = .success(UUID())
    private(set) var signedInWith: (String, String)?
    private(set) var signedOut = false
    private(set) var resetEmail: String?
    var resetFails = false

    func currentUserID() async -> UUID? { stored }
    func signIn(email: String, password: String) async throws -> UUID {
        signedInWith = (email, password)
        return try signInResult.get()
    }
    func signOut() async throws { signedOut = true }
    func sendPasswordReset(email: String) async throws {
        if resetFails { throw URLError(.notConnectedToInternet) }
        resetEmail = email
    }
}

@MainActor
struct AuthModelTests {
    @Test("con una sessione salvata si entra subito")
    func restoreSignedIn() async {
        let client = FakeAuth()
        let id = UUID()
        client.stored = id
        let model = AuthModel(client: client)
        #expect(model.state == .loading)
        await model.restore()
        #expect(model.state == .signedIn(id))
    }

    @Test("senza sessione si chiede l'accesso")
    func restoreSignedOut() async {
        let model = AuthModel(client: FakeAuth())
        await model.restore()
        #expect(model.state == .signedOut)
    }

    @Test("accesso riuscito: l'email si ripulisce dagli spazi")
    func signIn() async {
        let client = FakeAuth()
        let id = UUID()
        client.signInResult = .success(id)
        let model = AuthModel(client: client)
        await model.signIn(email: "  marco@prova.dev ", password: "segreta")
        #expect(model.state == .signedIn(id))
        #expect(client.signedInWith?.0 == "marco@prova.dev")
        #expect(model.error == nil)
    }

    @Test("credenziali sbagliate: messaggio chiaro, si resta fuori")
    func wrongCredentials() async {
        struct Rejected: Error, CustomStringConvertible { var description: String { "AuthError: Invalid login credentials" } }
        let client = FakeAuth()
        client.signInResult = .failure(Rejected())
        let model = AuthModel(client: client)
        await model.signIn(email: "marco@prova.dev", password: "sbagliata")
        #expect(model.state == .loading)  // non è mai entrato
        #expect(model.error == .invalidCredentials)
        #expect(model.error?.message == "Email o password non corrette.")
    }

    @Test("rete assente: lo dice, non parla di credenziali")
    func network() async {
        let client = FakeAuth()
        client.signInResult = .failure(URLError(.notConnectedToInternet))
        let model = AuthModel(client: client)
        await model.signIn(email: "marco@prova.dev", password: "x")
        #expect(model.error == .network)
    }

    @Test("email o password vuote: non chiama il server")
    func empty() async {
        let client = FakeAuth()
        let model = AuthModel(client: client)
        await model.signIn(email: "", password: "x")
        await model.signIn(email: "a@b.it", password: "")
        #expect(client.signedInWith == nil)
        #expect(model.error == .invalidCredentials)
    }

    @Test("password dimenticata: manda il link e lo dice")
    func reset() async {
        let client = FakeAuth()
        let model = AuthModel(client: client)
        await model.sendPasswordReset(email: " marco@prova.dev ")
        #expect(client.resetEmail == "marco@prova.dev")
        #expect(model.resetSent)
    }

    @Test("uscita: svuota i dati locali e torna al login")
    func signOut() async {
        var cleared = false
        let client = FakeAuth()
        client.stored = UUID()
        let model = AuthModel(client: client, onSignOut: { cleared = true })
        await model.restore()
        await model.signOut()
        #expect(client.signedOut)
        #expect(cleared)
        #expect(model.state == .signedOut)
    }
}
