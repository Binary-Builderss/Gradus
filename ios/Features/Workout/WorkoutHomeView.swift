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
    @State private var states: [UUID: Completion] = [:]
    @State private var readFailed = false
    /// Le sedute aperte (al massimo una). Lo muove anche la guida, che apre le sedute da sola.
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let snapshot, let mesocycle = snapshot.mesocycle {
                    program(snapshot, mesocycle)
                } else if readFailed {
                    ReadFailedView()
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
        .onChange(of: environment.tour.current) { _, step in followTour(step) }
        .task {
            let id = userID
            let ok = await environment.database.watch({ db in try ProgramQueries.home(db, athleteID: id) }) { value in
                snapshot = value
                if week == nil, let m = value.mesocycle {
                    week = MesocycleCalendar.currentWeek(startDate: m.startDate, weeks: m.weeks, today: .now)
                }
            }
            if !ok { readFailed = true }
        }
    }

    private func program(_ snapshot: HomeSnapshot, _ mesocycle: MesocycleRecord) -> some View {
        let selected = min(max(week ?? 1, 1), mesocycle.weeks)
        let next = snapshot.sessions.first { (states[$0.id] ?? .empty) != .complete }?.id
        return programCards(snapshot, mesocycle, selected: selected, next: next)
        .background(Theme.background)
        .navigationDestination(for: UUID.self) { id in
            if let session = snapshot.sessions.first(where: { $0.id == id }) {
                SessionDetailView(environment: environment, sessionID: id, title: session.name, week: selected)
            }
        }
        .task(id: selected) {
            let (id, w) = (mesocycle.id, selected)
            let ok = await environment.database.watch({ db in try ProgramQueries.sessionStates(db, mesocycleID: id, week: w) }) { states = $0 }
            if !ok { readFailed = true }
        }
    }

    /// Schede su fondo chiaro; la prossima seduta è piena di colore e le settimane galleggiano in vetro in alto.
    private func programCards(_ snapshot: HomeSnapshot, _ mesocycle: MesocycleRecord, selected: Int, next: UUID?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    MesocycleHeader(mesocycle: mesocycle, coach: snapshot.coachName, selected: selected)
                        .tourTarget("home-program")
                    if let notes = mesocycle.coachNotes, !notes.isEmpty {
                        Text(notes).font(.callout).foregroundStyle(.secondary)
                    }
                }
                .card()
                Text("Sedute").font(.headline).padding(.top, Theme.Space.s)
                ForEach(snapshot.sessions) { session in
                    let isNext = session.id == next
                    NavigationLink(value: session.id) {
                        SessionRowContent(session: session, state: states[session.id] ?? .empty, isNext: isNext, filled: isNext)
                            .card(fill: isNext ? Color.accentColor : Theme.surface)
                            .tourTarget("home-sessions", if: session.id == snapshot.sessions.first?.id)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Space.m)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            WeekPicker(weeks: mesocycle.weeks, deload: Set(mesocycle.deloadWeeks), selected: selected, onSelect: { week = $0 })
                .tourTarget("home-weeks")
                .padding(.horizontal, Theme.Space.m)
                .padding(.bottom, Theme.Space.s)
        }
    }

    /// La guida tiene aperta la seduta del suo passo; negli altri passi (e quando finisce) si torna all'elenco.
    private func followTour(_ step: TourStep?) {
        let sessions = snapshot?.sessions ?? []
        if let step, step.tab == .workout, let index = step.screen.sessionIndex, sessions.indices.contains(index) {
            if path != [sessions[index].id] { path = [sessions[index].id] }
        } else if !path.isEmpty {
            path = []
        }
    }

}

/// Le settimane del mesociclo, una per chip; quelle di scarico hanno un segno. Galleggia in vetro sopra le schede.
private struct WeekPicker: View {
    let weeks: Int
    let deload: Set<Int>
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassContainer {
                    HStack(spacing: Theme.Space.s) {
                        ForEach(1...max(weeks, 1), id: \.self) { w in
                            chip(w)
                        }
                    }
                    .padding(Theme.Space.xs)
                }
            }
            .scrollIndicators(.hidden)
            .glass(.capsule)
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
            .onChange(of: selected) { _, new in withAnimation { proxy.scrollTo(new, anchor: .center) } }
        }
    }

    private func chip(_ w: Int) -> some View {
        let isSelected = w == selected
        return Button {
            onSelect(w)
        } label: {
            Text(deload.contains(w) ? "S\(w) ↓" : "S\(w)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Theme.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(isSelected ? Color.accentColor : .clear, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .id(w)
        .accessibilityLabel(deload.contains(w) ? "Settimana \(w), scarico" : "Settimana \(w)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MesocycleHeader: View {
    let mesocycle: MesocycleRecord
    let coach: String?
    let selected: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mesocycle.name).font(.title2.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            if !MesocycleCalendar.hasStarted(startDate: mesocycle.startDate, today: .now) {
                Text("Inizia il \(MesocycleCalendar.label(startDate: mesocycle.startDate))")
                    .font(.subheadline).foregroundStyle(.orange)
            }
            if mesocycle.deloadWeeks.contains(selected) {
                Label("Settimana di scarico", systemImage: "arrow.down.right.circle")
                    .font(.subheadline).foregroundStyle(.orange)
            }
        }
    }

    private var subtitle: String {
        let weeks = mesocycle.weeks == 1 ? "1 settimana" : "\(mesocycle.weeks) settimane"
        return [weeks, coach.map { "con \($0)" }].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Una seduta nell'elenco. `isNext`: la prima non completata (la «prossima»); `filled`: sta su un fondo colorato.
private struct SessionRowContent: View {
    let session: SessionSummary
    let state: Completion
    let isNext: Bool
    let filled: Bool

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                if isNext {
                    Text("Prossima").font(.footnote.weight(.semibold)).foregroundStyle(filled ? .white.opacity(0.85) : Color.accentColor)
                }
                Text(session.name).font(.title3.bold())
                HStack(spacing: 6) {
                    Text(session.exerciseCount == 1 ? "1 esercizio" : "\(session.exerciseCount) esercizi")
                        .font(.subheadline).foregroundStyle(filled ? .white.opacity(0.85) : .secondary)
                    switch state {
                    case .complete: Label("Completa", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(filled ? .white : .green)
                    case .partial: Text("Iniziata").font(.subheadline).foregroundStyle(filled ? .white : .orange)
                    case .empty: EmptyView()
                    }
                }
            }
            if filled {
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
            }
        }
        .foregroundStyle(filled ? .white : Theme.ink)
        .padding(.vertical, 2)
    }
}
