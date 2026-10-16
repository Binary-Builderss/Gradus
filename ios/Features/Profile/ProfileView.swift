import Domain
import SwiftUI

/// Profilo: chi sei e le sezioni, ognuna in una schermata sua. In fondo le cose delicate (disattivare o eliminare
/// l'account) e l'uscita.
struct ProfileView: View {
    let environment: AppEnvironment
    let userID: UUID
    @State private var model = ProfileModel()
    @State private var confirmingSignOut = false
    @State private var unsentAtSignOut = 0
    @State private var checkingSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.snapshot.name ?? model.snapshot.email ?? "–").font(.title3.bold())
                        if model.snapshot.name != nil, let email = model.snapshot.email {
                            Text(email).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    NavigationLink {
                        AccountView(environment: environment, userID: userID, model: model)
                    } label: {
                        Label("Account", systemImage: "person.crop.circle")
                    }
                    NavigationLink {
                        PreferencesView()
                    } label: {
                        Label("Preferenze", systemImage: "slider.horizontal.3")
                    }
                    NavigationLink {
                        PrivacyView(environment: environment, userID: userID)
                    } label: {
                        Label("Privacy", systemImage: "hand.raised")
                    }
                    NavigationLink {
                        SyncView(environment: environment, model: model)
                    } label: {
                        HStack {
                            Label("Sincronizzazione", systemImage: "arrow.triangle.2.circlepath")
                            if model.snapshot.unsent > 0 {
                                Spacer()
                                Text("\(model.snapshot.unsent)").font(.footnote.weight(.semibold)).foregroundStyle(.orange)
                            }
                        }
                    }
                    NavigationLink {
                        AboutView(environment: environment)
                    } label: {
                        Label("Assistenza e informazioni", systemImage: "questionmark.circle")
                    }
                }
                Section {
                    NavigationLink {
                        DangerZoneView(environment: environment, userID: userID, model: model)
                    } label: {
                        Label("Disattiva o elimina l'account", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                    Button("Esci", role: .destructive) { Task { await beginSignOut() } }
                        .disabled(checkingSignOut)
                }
            }
            .navigationTitle("Profilo")
            .confirmationDialog(
                unsentAtSignOut > 0
                    ? (unsentAtSignOut == 1 ? "Hai 1 serie non ancora inviata" : "Hai \(unsentAtSignOut) serie non ancora inviate")
                    : "Uscire dall'account?",
                isPresented: $confirmingSignOut, titleVisibility: .visible
            ) {
                Button(unsentAtSignOut > 0 ? "Esci e perdi le serie" : "Esci", role: .destructive) {
                    Task { await environment.auth.signOut() }
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                if unsentAtSignOut > 0 {
                    Text("Non sono riuscito a inviarle al server (forse manca la rete). Se esci le perdi: aspetta di avere connessione e riprova.")
                } else {
                    Text("I dati salvati sul telefono vengono tolti. Li ritrovi accedendo di nuovo.")
                }
            }
        }
        .task { await model.watch(database: environment.database, userID: userID) }
    }

    /// Uscire non deve far perdere serie: prima si prova a inviarle, e se non si riesce lo si dice.
    private func beginSignOut() async {
        checkingSignOut = true
        defer { checkingSignOut = false }
        unsentAtSignOut = await environment.sync.flushBeforeSignOut()
        confirmingSignOut = true
    }
}
