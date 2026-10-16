import Domain
import GRDB
import SwiftUI

private struct ProfileSnapshot: Equatable {
    var name: String?
    var email: String?
    var coach: String?
    var unsent = 0
}

/// Profilo: chi sei, il coach collegato, lo stato della sincronizzazione ed esci.
struct ProfileView: View {
    let environment: AppEnvironment
    let userID: UUID
    @State private var snapshot = ProfileSnapshot()
    @State private var confirmingSignOut = false
    @State private var unsentAtSignOut = 0
    @State private var checkingSignOut = false
    @State private var editingName = false
    @AppStorage("effortScale") private var effortScale = EffortScale.buf.rawValue
    @AppStorage(RestTimerModel.soundKey) private var timerSound = true
    @AppStorage(RestTimerModel.hapticKey) private var timerHaptic = true

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Button {
                        editingName = true
                    } label: {
                        LabeledContent("Nome") {
                            HStack(spacing: 6) {
                                Text(snapshot.name ?? "Aggiungi").foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    LabeledContent("Email", value: snapshot.email ?? "–")
                    LabeledContent("Coach", value: snapshot.coach ?? "Nessuno")
                }
                Section("Impostazioni") {
                    Picker("Scala dello sforzo", selection: $effortScale) {
                        Text("Ripetizioni in riserva (BUF)").tag(EffortScale.buf.rawValue)
                        Text("RPE").tag(EffortScale.rpe.rawValue)
                    }
                    Toggle("Suono a fine recupero", isOn: $timerSound)
                    Toggle("Vibrazione a fine recupero", isOn: $timerHaptic)
                }
                Section("Sincronizzazione") {
                    SyncStatusRow(sync: environment.sync)
                    if snapshot.unsent > 0 {
                        Label(
                            snapshot.unsent == 1 ? "1 serie da inviare" : "\(snapshot.unsent) serie da inviare",
                            systemImage: "arrow.up.circle"
                        )
                        .font(.subheadline).foregroundStyle(.orange)
                    }
                    Button("Sincronizza ora") { Task { await environment.sync.sync() } }
                        .disabled(environment.sync.state == .syncing)
                }
                Section {
                    Button("Esci", role: .destructive) { Task { await beginSignOut() } }
                        .disabled(checkingSignOut)
                }
            }
            .navigationTitle("Profilo")
            .sheet(isPresented: $editingName) {
                NamePromptView(environment: environment, userID: userID, initial: snapshot.name ?? "", canSkip: false) {
                    editingName = false
                }
            }
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
        .task {
            let id = userID
            let observation = ValueObservation.tracking { db -> ProfileSnapshot in
                let me = try ProfileRecord.fetchOne(db, key: id)
                let link = try CoachLinkRecord
                    .filter(Column("athlete_id") == id && Column("status") == "active").fetchOne(db)
                let coach = try link.flatMap { try ProfileRecord.fetchOne(db, key: $0.coachId) }
                return ProfileSnapshot(
                    name: me?.fullName, email: me?.email, coach: coach?.displayName, unsent: try ExecutionStore.unsentSets(db))
            }
            do {
                for try await value in observation.values(in: environment.database.writer) { snapshot = value }
            } catch {}
        }
    }
}

extension ProfileView {
    /// Uscire non deve far perdere serie: prima si prova a inviarle, e se non si riesce lo si dice.
    fileprivate func beginSignOut() async {
        checkingSignOut = true
        defer { checkingSignOut = false }
        unsentAtSignOut = await environment.sync.flushBeforeSignOut()
        confirmingSignOut = true
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
