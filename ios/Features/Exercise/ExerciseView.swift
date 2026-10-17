import Domain
import SwiftUI

/// L'esercizio di una seduta: una riga per serie, raggruppate per blocco. Regole (ios/CLAUDE.md): campi vuoti, salvataggio
/// automatico, nessun «Fatto», riferimento alla settimana precedente e carico del back-off come testo.
struct ExerciseView: View {
    @Environment(\.palette) private var palette
    let environment: AppEnvironment
    let session: SessionContent
    let slot: SlotContent
    let week: Int
    /// A quale serie scorrere aprendo l'esercizio (dopo «Avvia timer» in un gruppo).
    var startSetIdx: Int?
    /// Passa all'esercizio successivo del gruppo, alla serie indicata.
    var goTo: (UUID, Int) -> Void = { _, _ in }
    @State private var model: ExerciseModel?
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if let model, model.loaded {
                // La guida evidenzia il primo «Avvia timer» che c'è (non sempre sulla prima serie).
                let timerKey = slot.blocks.lazy.flatMap { block in
                    (0..<(model.setCounts[block.id] ?? 0)).lazy.map { (block, SetKey(block: block.id, idx: $0)) }
                }.first { model.showsTimerButton($0.1, block: $0.0) }?.1
                ScrollViewReader { proxy in
                    List {
                        if let notes = slot.coachNotes, !notes.isEmpty {
                            Section { Text(notes).font(.callout).foregroundStyle(.secondary) }
                        }
                        ForEach(slot.blocks) { block in
                            BlockSection(
                                model: model, block: block, isTourFirst: block.id == slot.blocks.first?.id, tourTimerKey: timerKey, focused: $focused,
                                startTimer: { key in startTimer(model, block: block, key: key, proxy: proxy) })
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollContentBackground(.hidden)
                    .background(palette.background)
                    .onAppear {
                        if let startSetIdx, let first = slot.blocks.first {
                            proxy.scrollTo(SetKey(block: first.id, idx: startSetIdx), anchor: .center)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(slot.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Chiudi tastiera") { focused = false }
            }
        }
        .task {
            let model = ExerciseModel(
                session: session, slot: slot, week: week, store: ExecutionStore(database: environment.database),
                onSaved: { environment.sync.requestSync() })
            self.model = model
            await model.load()
        }
        .onDisappear { Task { await model?.flush() } }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { await model?.flush() } }
        }
    }
}

extension ExerciseView {
    /// «Avvia timer»: parte il recupero e si scorre alla serie successiva (o all'esercizio dopo, nei gruppi). Non salva
    /// né conferma niente: una serie vuota resta vuota.
    fileprivate func startTimer(_ model: ExerciseModel, block: BlockContent, key: SetKey, proxy: ScrollViewProxy) {
        environment.restTimer.start(seconds: model.restSeconds(for: block), title: model.timerTitle(for: key))
        focused = false
        switch model.advance(after: key) {
        case .set(let next): withAnimation { proxy.scrollTo(next, anchor: .center) }
        case .slot(let id, let idx): goTo(id, idx)
        case .none: break
        }
    }
}
