import Domain
import GRDB
import SwiftUI

/// Una seduta in una settimana: gruppi, esercizi e prescrizione di ogni blocco, come li ha scritti il coach.
/// Il tempo di esecuzione (TUT) non si mostra ancora: l'ordine dei quattro valori è una decisione aperta.
struct SessionDetailView: View {
    let environment: AppEnvironment
    let sessionID: UUID
    let title: String
    let week: Int
    @State private var content: SessionContent?
    @State private var open: OpenSlot?

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
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.top, Theme.Space.xl)
            }
        }
        .background(Theme.background)
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
                .font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink)
                .padding(.horizontal, Theme.Space.m).frame(minHeight: 32)
                .glass(.capsule)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Space.m).padding(.bottom, Theme.Space.xs)
        }
        .onChange(of: environment.tour.current?.screen) { _, _ in followTour() }
        .task {
            let (id, w) = (sessionID, week)
            let observation = ValueObservation.tracking { db in try ProgramQueries.session(db, id: id, week: w) }
            do {
                for try await value in observation.values(in: environment.database.writer) {
                    content = value
                    followTour()
                }
            } catch {}
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

/// Un gruppo di esercizi (un esercizio solo, o un superset): una scheda con una riga per esercizio.
private struct GroupCard: View {
    let group: GroupContent
    let header: String
    let content: SessionContent
    let firstSlotID: UUID?
    let onOpen: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if !header.isEmpty {
                Text(header).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                    .padding(.horizontal, Theme.Space.xs)
            }
            VStack(spacing: 0) {
                ForEach(group.slots) { slot in
                    if slot.id != group.slots.first?.id { Divider() }
                    row(slot)
                }
            }
            .card()
        }
    }

    private func row(_ slot: SlotContent) -> some View {
        Button {
            onOpen(slot.id)
        } label: {
            HStack(alignment: .top) {
                SlotRow(slot: slot, completion: content.completion(of: slot))
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    .padding(.top, Theme.Space.s)
            }
            .padding(.vertical, Theme.Space.s)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .tourTarget("session-exercise", if: slot.id == firstSlotID)
    }
}

private struct SlotRow: View {
    let slot: SlotContent
    let completion: Completion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(slot.exerciseName).font(.headline)
                Spacer()
                switch completion {
                case .complete: Label("Completo", systemImage: "checkmark.circle.fill").labelStyle(.iconOnly).foregroundStyle(.green)
                case .partial: Text("In corso").font(.footnote).foregroundStyle(.orange)
                case .empty: EmptyView()
                }
            }
            if let notes = slot.coachNotes, !notes.isEmpty {
                Text(notes).font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(slot.blocks) { block in
                VStack(alignment: .leading, spacing: 2) {
                    Text(blockTitle(block)).font(.subheadline.weight(.semibold))
                    Text(block.prescription?.text ?? "Nessuna prescrizione per questa settimana")
                        .font(.subheadline)
                        .foregroundStyle(block.prescription == nil ? .secondary : .primary)
                    if let rest = block.restS, rest > 0 {
                        Text("Recupero \(RestText.format(seconds: rest))").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func blockTitle(_ block: BlockContent) -> String {
        [Labels.role(block.role), Labels.technique(block.technique)].compactMap { $0 }.joined(separator: " · ")
    }
}

/// I nomi che il coach usa sul web, per riconoscersi tra coach e atleta.
enum Labels {
    static func role(_ role: String) -> String {
        switch role {
        case "warmup": "Riscaldamento"
        case "top": "Top set"
        case "backoff": "Back-off"
        default: "Serie"
        }
    }

    static func technique(_ technique: String) -> String? {
        switch technique {
        case "drop": "Drop set"
        case "rest_pause": "Rest-pause"
        case "myo": "Myo-reps"
        case "cluster": "Cluster"
        default: nil
        }
    }

    static func groupKind(_ kind: String) -> String? {
        switch kind {
        case "superset": "Superset"
        case "giant": "Giant set"
        case "circuit": "Circuito"
        case "jumpset": "Jump set"
        default: nil
        }
    }
}
