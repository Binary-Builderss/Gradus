import Domain
import SwiftUI

/// L'esercizio di una seduta: una riga per serie, raggruppate per blocco. Regole (ios/CLAUDE.md): campi vuoti, salvataggio
/// automatico, nessun «Fatto», riferimento alla settimana precedente e carico del back-off come testo.
struct ExerciseView: View {
    let environment: AppEnvironment
    let session: SessionContent
    let slot: SlotContent
    let week: Int
    @State private var model: ExerciseModel?
    @AppStorage("effortScale") private var preferredScale = EffortScale.buf.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if let model, model.loaded {
                List {
                    if let notes = slot.coachNotes, !notes.isEmpty {
                        Section { Text(notes).font(.callout).foregroundStyle(.secondary) }
                    }
                    ForEach(slot.blocks) { block in
                        BlockSection(model: model, block: block, focused: $focused)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
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
                preferredScale: EffortScale(rawValue: preferredScale) ?? .buf,
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

private struct BlockSection: View {
    let model: ExerciseModel
    let block: BlockContent
    var focused: FocusState<Bool>.Binding

    var body: some View {
        Section {
            if let target = model.backoffTarget(for: block) {
                Label(target, systemImage: "scope").font(.subheadline.weight(.semibold))
            }
            ForEach(0..<(model.setCounts[block.id] ?? 0), id: \.self) { idx in
                SetRow(model: model, block: block, key: SetKey(block: block.id, idx: idx), focused: focused)
            }
            Button {
                model.addSet(to: block.id)
            } label: {
                Label("Aggiungi serie", systemImage: "plus")
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
            HStack {
                if block.hasSegments {
                    Button {
                        model.addSegment(key)
                    } label: {
                        Label("Segmento", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless).font(.subheadline)
                }
                Spacer()
                EffortMenu(model: model, block: block, key: key)
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

private struct EffortMenu: View {
    let model: ExerciseModel
    let block: BlockContent
    let key: SetKey

    var body: some View {
        let scale = model.scale(for: block)
        let current = model.drafts[key]?.effort
        Menu {
            Button("Nessuno") { model.setEffort(key, nil) }
            ForEach(EffortOptions.values(for: scale), id: \.self) { value in
                Button(Self.text(Effort(value: value, scale: scale))) { model.setEffort(key, Effort(value: value, scale: scale)) }
            }
        } label: {
            Text(current.map(Self.text) ?? "Sforzo \(scale.rawValue)")
                .font(.subheadline)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.secondary.opacity(0.12), in: Capsule())
        }
        .accessibilityLabel("Sforzo percepito, serie \(key.idx + 1)")
    }

    private static func text(_ effort: Effort) -> String { "\(effort.scale.rawValue) \(NumberInput.text(effort.value))" }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
