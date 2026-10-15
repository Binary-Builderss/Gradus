import GRDB
import SwiftUI

private struct ProfileSnapshot: Equatable {
    var name: String?
    var email: String?
    var coach: String?
}

/// Profilo: chi sei, il coach collegato, lo stato della sincronizzazione ed esci.
struct ProfileView: View {
    let environment: AppEnvironment
    let userID: UUID
    @State private var snapshot = ProfileSnapshot()
    @State private var confirmingSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("Nome", value: snapshot.name ?? "–")
                    LabeledContent("Email", value: snapshot.email ?? "–")
                    LabeledContent("Coach", value: snapshot.coach ?? "Nessuno")
                }
                Section("Sincronizzazione") {
                    SyncStatusRow(sync: environment.sync)
                    Button("Sincronizza ora") { Task { await environment.sync.sync() } }
                        .disabled(environment.sync.state == .syncing)
                }
                Section {
                    Button("Esci", role: .destructive) { confirmingSignOut = true }
                }
            }
            .navigationTitle("Profilo")
            .confirmationDialog(
                "Uscire dall'account?", isPresented: $confirmingSignOut, titleVisibility: .visible
            ) {
                Button("Esci", role: .destructive) { Task { await environment.auth.signOut() } }
            } message: {
                Text("I dati salvati sul telefono vengono tolti. Li ritrovi accedendo di nuovo.")
            }
        }
        .task {
            let id = userID
            let observation = ValueObservation.tracking { db -> ProfileSnapshot in
                let me = try ProfileRecord.fetchOne(db, key: id)
                let link = try CoachLinkRecord
                    .filter(Column("athlete_id") == id && Column("status") == "active").fetchOne(db)
                let coach = try link.flatMap { try ProfileRecord.fetchOne(db, key: $0.coachId) }
                return ProfileSnapshot(name: me?.fullName, email: me?.email, coach: coach?.displayName)
            }
            do {
                for try await value in observation.values(in: environment.database.writer) { snapshot = value }
            } catch {}
        }
    }
}

private struct SyncStatusRow: View {
    let sync: SyncModel

    var body: some View {
        HStack {
            switch sync.state {
            case .syncing:
                ProgressView()
                Text("Sincronizzo…")
            case .failed:
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                Text("Non riesco a sincronizzare. Riprovo appena c'è rete.")
            case .idle:
                Image(systemName: "checkmark.circle").foregroundStyle(.green)
                if let last = sync.lastSync {
                    Text("Aggiornato \(last.formatted(.relative(presentation: .named)))")
                } else {
                    Text("Non ancora sincronizzato")
                }
            }
        }
        .font(.subheadline)
    }
}
