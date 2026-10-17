import Domain
import SwiftUI

/// Gli esercizi di una seduta, uno per pagina: si passa al successivo scorrendo di lato, senza tornare all'elenco.
/// In alto il nome, «2 di 5» e, se il coach l'ha collegato, il video. Dopo «Avvia timer» in un gruppo si scorre da soli
/// all'esercizio dopo, alla serie giusta.
struct ExercisePager: View {
    @Environment(\.palette) private var palette
    let environment: AppEnvironment
    let session: SessionContent
    let week: Int
    @State private var selection: UUID
    /// A quale serie scorrere aprendo una pagina (dopo «Avvia timer» in un gruppo).
    @State private var startSet: [UUID: Int]

    init(environment: AppEnvironment, session: SessionContent, week: Int, start: SessionDetailView.OpenSlot) {
        self.environment = environment
        self.session = session
        self.week = week
        _selection = State(initialValue: start.slotID)
        _startSet = State(initialValue: start.setIdx.map { [start.slotID: $0] } ?? [:])
    }

    private var slots: [SlotContent] { session.groups.flatMap(\.slots) }

    var body: some View {
        let current = slots.firstIndex { $0.id == selection } ?? 0
        TabView(selection: $selection) {
            ForEach(slots) { slot in
                ExerciseView(
                    environment: environment, session: session, slot: slot, week: week, startSetIdx: startSet[slot.id],
                    goTo: { id, idx in
                        startSet[id] = idx
                        withAnimation { selection = id }
                    },
                    isCurrent: slot.id == selection
                )
                // Una nuova serie di partenza ricrea la pagina, così scorre fin lì anche se era già caricata.
                .id(SessionDetailView.OpenSlot(slotID: slot.id, setIdx: startSet[slot.id]))
                .tag(slot.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(palette.background)
        .navigationTitle(slots[safe: current]?.exerciseName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(slots[safe: current]?.exerciseName ?? "").font(.headline).lineLimit(1)
                    if slots.count > 1 {
                        Text("\(current + 1) di \(slots.count)").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityHint(slots.count > 1 ? "Scorri di lato per gli altri esercizi" : "")
            }
            if let url = slots[safe: current]?.videoURL {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: url) {
                        Label("Video dell'esercizio", systemImage: "play.rectangle")
                    }
                }
            }
        }
    }
}
