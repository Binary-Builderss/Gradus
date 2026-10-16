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

    var body: some View {
        List {
            if let content {
                if let notes = content.coachNotes, !notes.isEmpty {
                    Section { Text(notes).font(.callout).foregroundStyle(.secondary) }
                }
                ForEach(content.groups) { group in
                    Section {
                        ForEach(group.slots) { slot in
                            NavigationLink {
                                ExerciseView(environment: environment, session: content, slot: slot, week: week)
                            } label: {
                                SlotRow(slot: slot, completion: content.completion(of: slot))
                            }
                        }
                    } header: {
                        Text(groupHeader(group))
                    }
                }
                if content.groups.isEmpty {
                    Text("Questa seduta non ha ancora esercizi.").foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("Settimana \(week)")
                .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 6)
                .background(.bar)
        }
        .task {
            let (id, w) = (sessionID, week)
            let observation = ValueObservation.tracking { db in try ProgramQueries.session(db, id: id, week: w) }
            do {
                for try await value in observation.values(in: environment.database.writer) { content = value }
            } catch {}
        }
    }

    private func groupHeader(_ group: GroupContent) -> String {
        let kind = Labels.groupKind(group.kind)
        guard group.slots.count > 1 || kind != nil else { return "" }
        let rest = group.restAfterRoundS > 0 ? "recupero a fine giro \(RestText.format(seconds: group.restAfterRoundS))" : nil
        return [kind, rest].compactMap { $0 }.joined(separator: " · ")
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
