import Domain
import GRDB
import SwiftUI

/// Allenamento (home): il mesociclo attivo, la settimana e le sedute. Sola lettura: l'atleta esegue, la programmazione
/// la scrive il coach. Legge solo dal database locale; tirando giù l'elenco si sincronizza.
struct WorkoutHomeView: View {
    let environment: AppEnvironment
    let userID: UUID
    @State private var snapshot: HomeSnapshot?
    @State private var week: Int?

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot, let mesocycle = snapshot.mesocycle {
                    program(snapshot, mesocycle)
                } else if snapshot == nil || environment.sync.state == .syncing && environment.sync.lastSync == nil {
                    ProgressView("Carico il tuo programma…")
                } else {
                    ContentUnavailableView(
                        "Nessun programma attivo",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Quando il tuo coach attiva un mesociclo lo trovi qui, anche senza rete."))
                }
            }
            .navigationTitle("Allenamento")
            .refreshable { await environment.sync.sync() }
        }
        .task {
            let id = userID
            let observation = ValueObservation.tracking { db in try ProgramQueries.home(db, athleteID: id) }
            do {
                for try await value in observation.values(in: environment.database.writer) {
                    snapshot = value
                    if week == nil, let m = value.mesocycle {
                        week = MesocycleCalendar.currentWeek(startDate: m.startDate, weeks: m.weeks, today: .now)
                    }
                }
            } catch {}
        }
    }

    private func program(_ snapshot: HomeSnapshot, _ mesocycle: MesocycleRecord) -> some View {
        let selected = min(max(week ?? 1, 1), mesocycle.weeks)
        return List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mesocycle.name).font(.title3.bold())
                    Text(subtitle(mesocycle, coach: snapshot.coachName)).font(.subheadline).foregroundStyle(.secondary)
                    if !MesocycleCalendar.hasStarted(startDate: mesocycle.startDate, today: .now) {
                        Text("Inizia il \(MesocycleCalendar.label(startDate: mesocycle.startDate))")
                            .font(.subheadline).foregroundStyle(.orange)
                    }
                }
                WeekPicker(weeks: mesocycle.weeks, deload: Set(mesocycle.deloadWeeks), selected: Binding(get: { selected }, set: { week = $0 }))
                if mesocycle.deloadWeeks.contains(selected) {
                    Label("Settimana di scarico", systemImage: "arrow.down.right.circle")
                        .font(.subheadline).foregroundStyle(.orange)
                }
                if let notes = mesocycle.coachNotes, !notes.isEmpty {
                    Text(notes).font(.callout).foregroundStyle(.secondary)
                }
            }
            Section("Sedute") {
                ForEach(snapshot.sessions) { session in
                    NavigationLink {
                        SessionDetailView(environment: environment, sessionID: session.id, title: session.name, week: selected)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.name).font(.headline)
                            Text(session.exerciseCount == 1 ? "1 esercizio" : "\(session.exerciseCount) esercizi")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func subtitle(_ m: MesocycleRecord, coach: String?) -> String {
        let weeks = m.weeks == 1 ? "1 settimana" : "\(m.weeks) settimane"
        return [weeks, coach.map { "con \($0)" }].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Le settimane del mesociclo, una per chip; quelle di scarico hanno un segno.
private struct WeekPicker: View {
    let weeks: Int
    let deload: Set<Int>
    @Binding var selected: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...max(weeks, 1), id: \.self) { w in
                        Button {
                            selected = w
                        } label: {
                            Text(deload.contains(w) ? "S\(w) ↓" : "S\(w)")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(w == selected ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
                                .foregroundStyle(w == selected ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .id(w)
                        .accessibilityLabel(deload.contains(w) ? "Settimana \(w), scarico" : "Settimana \(w)")
                        .accessibilityAddTraits(w == selected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
        }
    }
}
