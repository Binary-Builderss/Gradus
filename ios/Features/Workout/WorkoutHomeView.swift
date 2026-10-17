import Domain
import GRDB
import SwiftUI

/// Allenamento (home): il mesociclo attivo, la settimana e le sedute. Sola lettura: l'atleta esegue, la programmazione
/// la scrive il coach. Legge solo dal database locale; tirando giù l'elenco si sincronizza.
struct WorkoutHomeView: View {
    @Environment(\.palette) private var palette
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
        .background(palette.background)
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
                NumbersHeader(
                    mesocycle: mesocycle, coach: environment.branding.branding.name ?? snapshot.coachName, selected: selected,
                    branding: environment.branding.branding)
                    .tourTarget("home-program")
                if let notes = mesocycle.coachNotes, !notes.isEmpty {
                    Text(notes).font(.callout).foregroundStyle(.secondary).padding(.horizontal, Theme.Space.xs)
                }
                Text("Sedute").font(.headline).padding(.top, Theme.Space.s)
                ForEach(Array(snapshot.sessions.enumerated()), id: \.element.id) { index, session in
                    let isNext = session.id == next
                    NavigationLink(value: session.id) {
                        SessionRowContent(
                            session: session, state: states[session.id] ?? .empty, isNext: isNext, filled: isNext,
                            number: index + 1
                        )
                        .card(fill: isNext ? palette.accent : palette.surface)
                            .tourTarget("home-sessions", if: session.id == snapshot.sessions.first?.id)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Space.m)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            StepsWeekPicker(weeks: mesocycle.weeks, deload: Set(mesocycle.deloadWeeks), selected: selected, onSelect: { week = $0 })
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
