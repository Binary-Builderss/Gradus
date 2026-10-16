import Domain
import SwiftUI

/// L'esercizio di una seduta: una riga per serie, raggruppate per blocco. Regole (ios/CLAUDE.md): campi vuoti, salvataggio
/// automatico, nessun «Fatto», riferimento alla settimana precedente e carico del back-off come testo.
struct ExerciseView: View {
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
                ScrollViewReader { proxy in
                    List {
                        if let notes = slot.coachNotes, !notes.isEmpty {
                            Section { Text(notes).font(.callout).foregroundStyle(.secondary) }
                        }
                        ForEach(slot.blocks) { block in
                            BlockSection(
                                model: model, block: block, focused: $focused,
                                startTimer: { key in startTimer(model, block: block, key: key, proxy: proxy) })
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
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

private struct BlockSection: View {
    let model: ExerciseModel
    let block: BlockContent
    var focused: FocusState<Bool>.Binding
    let startTimer: (SetKey) -> Void

    var body: some View {
        Section {
            if let target = model.backoffTarget(for: block) {
                Label(target, systemImage: "scope").font(.subheadline.weight(.semibold))
            }
            ForEach(0..<(model.setCounts[block.id] ?? 0), id: \.self) { idx in
                SetRow(model: model, block: block, key: SetKey(block: block.id, idx: idx), focused: focused, startTimer: startTimer)
                    .id(SetKey(block: block.id, idx: idx))
            }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(block.prescription?.text ?? "Nessuna prescrizione per questa settimana")
                    .font(.footnote).textCase(nil)
                if let rest = block.restS, rest > 0 {
                    Text("Recupero \(RestText.format(seconds: rest))").font(.footnote).textCase(nil)
                }
            }
        }
    }

    private var title: String {
        [Labels.role(block.role), Labels.technique(block.technique)].compactMap { $0 }.joined(separator: " · ")
    }
}

private struct SetRow: View {
    let model: ExerciseModel
    let block: BlockContent
    let key: SetKey
    var focused: FocusState<Bool>.Binding
    let startTimer: (SetKey) -> Void

    var body: some View {
        let draft = model.drafts[key] ?? SetDraft()
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Serie \(key.idx + 1)").font(.subheadline.weight(.semibold))
                if let reference = model.references[key] {
                    Text(reference).font(.footnote).foregroundStyle(.secondary)
                }
            }
            ForEach(draft.segments.indices, id: \.self) { index in
                HStack(spacing: 10) {
                    field(
                        text: Binding(get: { model.drafts[key]?.segments[safe: index]?.load ?? "" }, set: { model.setLoad(key, segment: index, $0) }),
                        unit: "kg", keyboard: .decimalPad,
                        label: "Carico, serie \(key.idx + 1)\(draft.segments.count > 1 ? ", segmento \(index + 1)" : "")")
                    Text("×").foregroundStyle(.secondary)
                    field(
                        text: Binding(get: { model.drafts[key]?.segments[safe: index]?.reps ?? "" }, set: { model.setReps(key, segment: index, $0) }),
                        unit: "rip.", keyboard: .numberPad,
                        label: "Ripetizioni, serie \(key.idx + 1)\(draft.segments.count > 1 ? ", segmento \(index + 1)" : "")")
                }
            }
            if block.hasSegments {
                Button {
                    model.addSegment(key)
                } label: {
                    Label("Segmento", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless).font(.subheadline)
            }
            EffortRow(model: model, block: block, key: key)
            if model.showsTimerButton(key, block: block) {
                Button {
                    startTimer(key)
                } label: {
                    Label("Avvia timer", systemImage: "timer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Recupero di \(RestText.format(seconds: model.restSeconds(for: block)))")
            }
        }
        .padding(.vertical, 4)
    }

    private func field(text: Binding<String>, unit: String, keyboard: UIKeyboardType, label: String) -> some View {
        HStack(spacing: 6) {
            TextField("", text: text)  // vuoto: nessun valore (nemmeno grigio) finché l'atleta non scrive
                .keyboardType(keyboard)
                .multilineTextAlignment(.center)
                .font(.title3.monospacedDigit())
                .frame(minWidth: 64, maxWidth: 96, minHeight: 44)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .focused(focused)
                .accessibilityLabel(label)
            Text(unit).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// Lo sforzo percepito (facoltativo, una volta per serie): una riga di tasti interi sulla scala del coach. Un tocco
/// sceglie, un secondo tocco toglie; il mezzo punto (2,5) si sceglie con il tocco lungo sul tasto.
private struct EffortRow: View {
    let model: ExerciseModel
    let block: BlockContent
    let key: SetKey

    var body: some View {
        let scale = model.scale(for: block)
        let current = model.drafts[key]?.effort.flatMap { $0.scale == scale ? $0.value : nil }
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(EffortOptions.title(for: scale)).font(.footnote).foregroundStyle(.secondary)
                if let current { Text(NumberInput.text(current)).font(.footnote.weight(.semibold)) }
            }
            HStack(spacing: 8) {
                ForEach(EffortOptions.wholeValues(for: scale), id: \.self) { whole in
                    chip(whole: whole, scale: scale, current: current)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func chip(whole: Double, scale: EffortScale, current: Double?) -> some View {
        let half = EffortOptions.halfStep(above: whole, scale: scale)
        let shown = (half != nil && current == half) ? half! : whole  // il tasto mostra il mezzo punto se è quello scelto
        let selected = current == shown
        return Button {
            model.setEffort(key, selected ? nil : Effort(value: shown, scale: scale))
        } label: {
            Text(NumberInput.text(shown))
                .font(.body.monospacedDigit().weight(selected ? .bold : .regular))
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.borderless)
        .contextMenu {
            Button(NumberInput.text(whole)) { model.setEffort(key, Effort(value: whole, scale: scale)) }
            if let half { Button(NumberInput.text(half)) { model.setEffort(key, Effort(value: half, scale: scale)) } }
            if current != nil { Button("Togli lo sforzo", role: .destructive) { model.setEffort(key, nil) } }
        }
        .accessibilityLabel("Sforzo \(NumberInput.text(shown))")
        .accessibilityHint("Tocco lungo per il mezzo punto")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
