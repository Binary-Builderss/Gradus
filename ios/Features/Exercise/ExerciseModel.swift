import Domain
import Foundation
import Observation

struct SegmentDraft: Equatable {
    var load = ""
    var reps = ""
}

struct SetDraft: Equatable {
    var segments = [SegmentDraft()]
    var effort: Effort?

    /// La serie ha qualcosa di scritto, quindi è registrata (si salva da sola).
    var hasData: Bool {
        effort != nil || segments.contains { !$0.load.trimmingCharacters(in: .whitespaces).isEmpty || !$0.reps.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

struct SetKey: Hashable, Sendable {
    var block: UUID
    var idx: Int
}

/// Lo stato della schermata esercizio. Ogni modifica si salva da sola nel database locale (debounce di 300 ms mentre
/// si digita): niente «Salva», niente «Fatto». I campi partono vuoti: kg, ripetizioni e sforzo li scrive solo l'atleta.
@MainActor
@Observable
final class ExerciseModel {
    static let debounce: Duration = .milliseconds(300)

    let session: SessionContent
    let slot: SlotContent
    let week: Int
    private(set) var drafts: [SetKey: SetDraft] = [:]
    private(set) var setCounts: [UUID: Int] = [:]
    private(set) var references: [SetKey: String] = [:]
    private(set) var loaded = false

    private let store: ExecutionStore
    private let onSaved: @MainActor () -> Void
    private let debounce: Duration
    private var currentWeekLogs: [LoggedSet] = []
    private var pending: [SetKey: Task<Void, Never>] = [:]

    init(
        session: SessionContent, slot: SlotContent, week: Int, store: ExecutionStore,
        debounce: Duration = ExerciseModel.debounce,
        onSaved: @escaping @MainActor () -> Void = {}
    ) {
        self.session = session
        self.slot = slot
        self.week = week
        self.store = store
        self.debounce = debounce
        self.onSaved = onSaved
    }

    // MARK: Caricamento

    func load() async {
        guard !loaded else { return }
        let logs = (try? await store.loggedSets(mesocycleID: session.mesocycleID, sessionID: session.sessionID)) ?? []
        currentWeekLogs = logs.filter { $0.week == week }
        for block in slot.blocks {
            let mine = currentWeekLogs.filter { $0.blockID == block.id }
            setCounts[block.id] = max(block.prescribedSets, (mine.map(\.setIdx).max() ?? -1) + 1, 1)
            for idx in 0..<(setCounts[block.id] ?? 0) {
                let key = SetKey(block: block.id, idx: idx)
                if let logged = mine.first(where: { $0.setIdx == idx }) {
                    drafts[key] = Self.draft(from: logged)
                } else {
                    drafts[key] = SetDraft()
                }
            }
        }
        let refs = PreviousWeek.references(
            mesocycleID: session.mesocycleID, sessionID: session.sessionID, week: week,
            deloadWeeks: Set(session.deloadWeeks), blockOrder: session.blockOrder, logs: logs)
        references = Dictionary(refs.map { (SetKey(block: $0.blockID, idx: $0.setIdx), $0.text) }, uniquingKeysWith: { a, _ in a })
        loaded = true
    }

    private static func draft(from logged: LoggedSet) -> SetDraft {
        var draft = SetDraft(segments: logged.segments.map {
            SegmentDraft(load: $0.loadKg.map(NumberInput.text) ?? "", reps: $0.reps.map(String.init) ?? "")
        }, effort: logged.effort)
        if draft.segments.isEmpty { draft.segments = [SegmentDraft()] }
        return draft
    }

    // MARK: Modifiche (ognuna programma il salvataggio)

    /// Il testo di un campo, da legare a un `TextField` con `$model[load: key, segment: i]`.
    subscript(load key: SetKey, segment index: Int) -> String {
        get { drafts[key]?.segments[safe: index]?.load ?? "" }
        set { setLoad(key, segment: index, newValue) }
    }

    subscript(reps key: SetKey, segment index: Int) -> String {
        get { drafts[key]?.segments[safe: index]?.reps ?? "" }
        set { setReps(key, segment: index, newValue) }
    }

    func setLoad(_ key: SetKey, segment: Int, _ text: String) {
        guard drafts[key]?.segments.indices.contains(segment) == true else { return }
        drafts[key]?.segments[segment].load = text
        changed(key)
    }

    func setReps(_ key: SetKey, segment: Int, _ text: String) {
        guard drafts[key]?.segments.indices.contains(segment) == true else { return }
        drafts[key]?.segments[segment].reps = text
        changed(key)
    }

    func setEffort(_ key: SetKey, _ effort: Effort?) {
        drafts[key]?.effort = effort
        changed(key)
    }

    /// Un segmento in più (drop, rest-pause, myo, cluster). Una riga vuota non è un dato: non si salva finché è vuota.
    func addSegment(_ key: SetKey) {
        drafts[key]?.segments.append(SegmentDraft())
    }

    func scale(for block: BlockContent) -> EffortScale {
        EffortOptions.scale(prescribed: block.prescription?.method)
    }

    // MARK: Salvataggio

    private func changed(_ key: SetKey) {
        pending[key]?.cancel()
        pending[key] = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await self.save(key)
        }
    }

    /// Salva subito quello che è in attesa (uscendo dalla schermata o mandando l'app in background).
    func flush() async {
        let keys = Array(pending.keys)
        for key in keys {
            pending[key]?.cancel()
            await save(key)
        }
    }

    private func save(_ key: SetKey) async {
        pending[key] = nil
        guard let draft = drafts[key] else { return }
        let edit = SetEdit(
            athleteID: session.athleteID, mesocycleID: session.mesocycleID, sessionID: session.sessionID, week: week,
            blockID: key.block, setIdx: key.idx,
            segments: draft.segments.map { Segment(loadKg: NumberInput.decimal($0.load), reps: NumberInput.integer($0.reps)) },
            effort: draft.effort)
        do {
            try await store.save(edit)
            onSaved()
        } catch {
            // Il database locale non dovrebbe mai rifiutare una scrittura: se succede, la modifica resta nel campo.
            assertionFailure("Salvataggio locale non riuscito: \(error)")
        }
    }

    // MARK: Timer di recupero

    private var group: GroupContent? { session.groups.first { $0.slots.contains { $0.id == slot.id } } }

    /// Il recupero dopo una serie di questo blocco: `rest_s` se l'esercizio è da solo; in un gruppo `rest_between_s`
    /// e, dopo l'ultimo esercizio del giro, `rest_after_round_s`.
    func restSeconds(for block: BlockContent) -> Int {
        let members = group?.slots ?? [slot]
        return RestPlan.seconds(
            groupSize: members.count, position: members.firstIndex { $0.id == slot.id } ?? 0, blockRestS: block.restS,
            restBetweenS: group?.restBetweenS ?? 0, restAfterRoundS: group?.restAfterRoundS ?? 0)
    }

    /// L'ultima serie della seduta: ultimo gruppo, ultimo esercizio, ultimo blocco, ultima serie.
    func isLastSetOfSession(_ key: SetKey) -> Bool {
        guard let lastGroup = session.groups.last, let lastSlot = lastGroup.slots.last, lastSlot.id == slot.id,
            slot.blocks.last?.id == key.block
        else { return false }
        return key.idx == (setCounts[key.block] ?? 1) - 1
    }

    func showsTimerButton(_ key: SetKey, block: BlockContent) -> Bool {
        RestPlan.showsButton(seconds: restSeconds(for: block), isLastSetOfSession: isLastSetOfSession(key))
    }

    /// Dove andare dopo aver avviato il timer: la serie successiva (scorrendo) o l'esercizio successivo del gruppo.
    enum Advance: Equatable {
        case set(SetKey)
        case slot(UUID, setIdx: Int)
        case none
    }

    func advance(after key: SetKey) -> Advance {
        let groups = session.groups
        guard let groupIndex = groups.firstIndex(where: { $0.slots.contains { $0.id == slot.id } }) else { return .none }
        let members = groups[groupIndex].slots
        let position = members.firstIndex { $0.id == slot.id } ?? 0
        let nextGroupStart: Advance =
            groupIndex + 1 < groups.count ? groups[groupIndex + 1].slots.first.map { .slot($0.id, setIdx: 0) } ?? .none : .none

        if members.count > 1 {
            // Superset e simili: si passa all'esercizio dopo; finito il giro si torna al primo con la serie dopo.
            if position + 1 < members.count { return .slot(members[position + 1].id, setIdx: key.idx) }
            let first = members[0]
            return (first.blocks.first?.prescribedSets ?? 0) > key.idx + 1 ? .slot(first.id, setIdx: key.idx + 1) : nextGroupStart
        }
        if key.idx + 1 < (setCounts[key.block] ?? 0) { return .set(SetKey(block: key.block, idx: key.idx + 1)) }
        if let at = slot.blocks.firstIndex(where: { $0.id == key.block }), at + 1 < slot.blocks.count {
            return .set(SetKey(block: slot.blocks[at + 1].id, idx: 0))
        }
        return nextGroupStart
    }

    func timerTitle(for key: SetKey) -> String { "\(slot.exerciseName) · serie \(key.idx + 1)" }

    // MARK: Indicazioni (testo, mai valori nei campi)

    /// «≈ 90 kg» per un back-off legato, appena il blocco di riferimento ha un carico registrato in questa seduta.
    func backoffTarget(for block: BlockContent) -> String? {
        guard let reference = block.refBlockId, let pct = block.prescription?.refPct,
            let top = BackOff.referenceLoad(of: currentSets(of: reference))
        else { return nil }
        return BackOff.text(forTarget: BackOff.targetLoad(topLoadKg: top, refPct: pct))
    }

    /// Le serie di un blocco in questa settimana: dalle bozze se il blocco è su questa schermata (si aggiorna mentre si
    /// scrive), altrimenti da quelle già registrate.
    private func currentSets(of blockID: UUID) -> [LoggedSet] {
        guard slot.blocks.contains(where: { $0.id == blockID }) else {
            return currentWeekLogs.filter { $0.blockID == blockID }
        }
        return drafts.filter { $0.key.block == blockID }.map { key, draft in
            LoggedSet(
                mesocycleID: session.mesocycleID, sessionID: session.sessionID, blockID: blockID, week: week, setIdx: key.idx,
                segments: draft.segments.map { Segment(loadKg: NumberInput.decimal($0.load), reps: NumberInput.integer($0.reps)) }
                    .filter { $0.loadKg != nil || $0.reps != nil },
                effort: draft.effort)
        }
    }
}
