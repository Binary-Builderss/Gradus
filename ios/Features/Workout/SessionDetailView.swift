import Domain
import GRDB
import SwiftUI

/// Una seduta in una settimana: gruppi, esercizi e prescrizione di ogni blocco, come li ha scritti il coach.
/// Il tempo di esecuzione (TUT) non si mostra ancora: l'ordine dei quattro valori è una decisione aperta.
struct SessionDetailView: View {
    @Environment(\.palette) private var palette
    let environment: AppEnvironment
    let sessionID: UUID
    let title: String
    let week: Int
    @State private var content: SessionContent?
    @State private var open: OpenSlot?
    @State private var readFailed = false

    /// L'esercizio aperto, e la serie a cui scorrere (dopo «Avvia timer» in un gruppo si passa al successivo).
    struct OpenSlot: Hashable {
        var slotID: UUID
        var setIdx: Int?
    }

    var body: some View {
        ScrollView {
            if let content {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    if let notes = content.coachNotes, !notes.isEmpty {
                        Text(notes).font(.callout).foregroundStyle(.secondary).padding(.horizontal, Theme.Space.xs)
                    }
                    ForEach(content.groups) { group in
                        GroupCard(
                            group: group, header: groupHeader(group), content: content,
                            firstSlotID: content.groups.first?.slots.first?.id,
                            onOpen: { open = OpenSlot(slotID: $0, setIdx: nil) })
                    }
                    if content.groups.isEmpty {
                        Text("Questa seduta non ha ancora esercizi.").foregroundStyle(.secondary)
                    }
                }
                .padding(Theme.Space.m)
            } else if readFailed {
                ReadFailedView()
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.top, Theme.Space.xl)
            }
        }
        .background(palette.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $open) { target in
            if let content, let slot = content.groups.flatMap(\.slots).first(where: { $0.id == target.slotID }) {
                ExerciseView(
                    environment: environment, session: content, slot: slot, week: week, startSetIdx: target.setIdx,
                    goTo: { id, idx in open = OpenSlot(slotID: id, setIdx: idx) }
                )
                .id(target)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("Settimana \(week)")
                .font(.footnote.weight(.semibold)).foregroundStyle(palette.ink)
                .padding(.horizontal, Theme.Space.m).frame(minHeight: 32)
                .glass(.capsule)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Space.m).padding(.bottom, Theme.Space.xs)
        }
        .onChange(of: environment.tour.current?.screen) { _, _ in followTour() }
        .task {
            let (id, w) = (sessionID, week)
            let ok = await environment.database.watch({ db in try ProgramQueries.session(db, id: id, week: w) }) { value in
                content = value
                followTour()
            }
            if !ok { readFailed = true }
        }
    }

    /// La guida apre il primo esercizio nei suoi passi sull'esercizio e lo richiude negli altri.
    private func followTour() {
        switch environment.tour.current?.screen {
        case .exercise:
            if open == nil, let first = content?.groups.flatMap(\.slots).first { open = OpenSlot(slotID: first.id, setIdx: nil) }
        case .session:
            if open != nil { open = nil }
        default: break
        }
    }

    private func groupHeader(_ group: GroupContent) -> String {
        let kind = Labels.groupKind(group.kind)
        guard group.slots.count > 1 || kind != nil else { return "" }
        let rest = group.restAfterRoundS > 0 ? "recupero a fine giro \(RestText.format(seconds: group.restAfterRoundS))" : nil
        return [kind, rest].compactMap { $0 }.joined(separator: " · ")
    }
}
