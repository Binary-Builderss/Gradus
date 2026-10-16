import Domain
import Foundation
import GRDB
import Testing

@testable import Gradus

@MainActor
struct ExerciseModelTests {
    private let top = Sample.top
    private let backoff = Sample.backoff

    private func session(mesocycle: UUID = Sample.mesocycle) -> (SessionContent, SlotContent) {
        let topBlock = BlockContent(
            id: top, role: "top", technique: "none", restS: 180, tut: [], refBlockId: nil,
            prescription: Prescription(sets: 2, repsMin: 5, repsMax: 5, method: .buf, value: 2))
        let backoffBlock = BlockContent(
            id: backoff, role: "backoff", technique: "drop", restS: 120, tut: [], refBlockId: top,
            prescription: Prescription(sets: 1, repsMin: 8, repsMax: 10, refPct: 85))
        let slot = SlotContent(id: Sample.slot, exerciseName: "Panca piana", coachNotes: nil, blocks: [topBlock, backoffBlock])
        let group = GroupContent(id: Sample.group, kind: "single", restBetweenS: 0, restAfterRoundS: 0, slots: [slot])
        let content = SessionContent(
            sessionID: Sample.session, mesocycleID: mesocycle, athleteID: Sample.athlete, deloadWeeks: [4], name: "Spinta",
            coachNotes: nil, groups: [group], loggedCounts: [:])
        return (content, slot)
    }

    private func make(week: Int = 2) throws -> (ExerciseModel, ExecutionStore, AppDatabase) {
        let database = try AppDatabase.inMemory()
        let store = ExecutionStore(database: database)
        let (content, slot) = session()
        return (ExerciseModel(session: content, slot: slot, week: week, store: store, debounce: .milliseconds(20)), store, database)
    }

    private func logged(_ store: ExecutionStore) async throws -> [LoggedSet] {
        try await store.loggedSets(mesocycleID: Sample.mesocycle, sessionID: Sample.session)
    }

    @Test("i campi partono vuoti: nessun valore precompilato, una riga per serie prescritta")
    func startsEmpty() async throws {
        let (model, _, _) = try make()
        await model.load()
        #expect(model.setCounts[top] == 2)
        #expect(model.setCounts[backoff] == 1)
        #expect(model.drafts.values.allSatisfy { $0.segments == [SegmentDraft()] && $0.effort == nil })
        #expect(model.references.isEmpty)
    }

    @Test("scrivendo si salva da solo, senza pulsanti, dopo il debounce")
    func autosaves() async throws {
        let (model, store, _) = try make()
        await model.load()
        let key = SetKey(block: top, idx: 0)
        model.setLoad(key, segment: 0, "100")
        model.setReps(key, segment: 0, "5")
        try await Task.sleep(for: .milliseconds(150))
        let sets = try await logged(store)
        #expect(sets.count == 1)
        #expect(sets[0].segments == [Segment(loadKg: 100, reps: 5)])
    }

    @Test("flush salva subito quello che è in attesa (uscendo dalla schermata)")
    func flushSavesNow() async throws {
        let (model, store, _) = try make()
        await model.load()
        model.setLoad(SetKey(block: top, idx: 1), segment: 0, "82,5")
        await model.flush()
        #expect(try await logged(store).first?.segments == [Segment(loadKg: 82.5, reps: nil)])
    }

    @Test("svuotare i campi cancella la serie")
    func clearingDeletes() async throws {
        let (model, store, _) = try make()
        await model.load()
        let key = SetKey(block: top, idx: 0)
        model.setLoad(key, segment: 0, "100")
        await model.flush()
        #expect(try await logged(store).count == 1)
        model.setLoad(key, segment: 0, "")
        await model.flush()
        #expect(try await logged(store).isEmpty)
    }

    @Test("il riferimento alla settimana precedente è testo nell'intestazione della serie, mai nei campi")
    func previousWeekReference() async throws {
        let (_, store, database) = try make()
        try await store.save(
            SetEdit(
                athleteID: Sample.athlete, mesocycleID: Sample.mesocycle, sessionID: Sample.session, week: 1, blockID: top,
                setIdx: 0, segments: [Segment(loadKg: 100, reps: 5)], effort: Effort(value: 1, scale: .buf)))
        let (content, slot) = session()
        let model = ExerciseModel(session: content, slot: slot, week: 2, store: ExecutionStore(database: database))
        await model.load()
        #expect(model.references[SetKey(block: top, idx: 0)] == "Sett. 1: 100 × 5 · BUF 1")
        #expect(model.references[SetKey(block: top, idx: 1)] == nil)
        #expect(model.drafts[SetKey(block: top, idx: 0)] == SetDraft())  // il campo resta vuoto
    }

    @Test("settimana 1: nessun riferimento")
    func weekOneHasNoReference() async throws {
        let (model, _, _) = try make(week: 1)
        await model.load()
        #expect(model.references.isEmpty)
    }

    @Test("il carico del back-off compare appena il top set ha un carico, e segue quello che si scrive")
    func backoffTarget() async throws {
        let (model, _, _) = try make()
        await model.load()
        let backoffBlock = model.slot.blocks[1]
        #expect(model.backoffTarget(for: backoffBlock) == nil)
        model.setReps(SetKey(block: top, idx: 0), segment: 0, "5")  // senza carico non basta
        #expect(model.backoffTarget(for: backoffBlock) == nil)
        model.setLoad(SetKey(block: top, idx: 0), segment: 0, "100")
        #expect(model.backoffTarget(for: backoffBlock) == "≈ 85 kg")
        model.setLoad(SetKey(block: top, idx: 1), segment: 0, "105")  // la serie registrata per ultima
        #expect(model.backoffTarget(for: backoffBlock) == "≈ 90 kg")  // 89,25 → 90 (2,5 kg)
        #expect(model.drafts[SetKey(block: backoff, idx: 0)] == SetDraft())  // mai scritto nei campi
        await model.flush()
    }

    @Test("un drop set aggiunge segmenti; i segmenti si salvano uno per riga")
    func dropSegments() async throws {
        let (model, store, _) = try make()
        await model.load()
        let key = SetKey(block: backoff, idx: 0)
        model.setLoad(key, segment: 0, "80")
        model.setReps(key, segment: 0, "8")
        model.addSegment(key)
        model.setLoad(key, segment: 1, "60")
        model.setReps(key, segment: 1, "6")
        await model.flush()
        #expect(try await logged(store).first?.segments == [Segment(loadKg: 80, reps: 8), Segment(loadKg: 60, reps: 6)])
    }

    @Test("lo sforzo si salva nella scala scelta: BUF se la prescrizione è BUF")
    func effortScale() async throws {
        let (model, store, _) = try make()
        await model.load()
        #expect(model.scale(for: model.slot.blocks[0]) == .buf)
        model.setEffort(SetKey(block: top, idx: 0), Effort(value: 2.5, scale: .buf))
        await model.flush()
        #expect(try await logged(store).first?.effort == Effort(value: 2.5, scale: .buf))
    }

    @Test("riaprendo la schermata le serie registrate tornano nei campi")
    func reopen() async throws {
        let (model, store, _) = try make()
        await model.load()
        model.setLoad(SetKey(block: top, idx: 0), segment: 0, "100")
        model.setReps(SetKey(block: top, idx: 0), segment: 0, "5")
        await model.flush()
        let (content, slot) = session()
        let again = ExerciseModel(session: content, slot: slot, week: 2, store: store)
        await again.load()
        #expect(again.drafts[SetKey(block: top, idx: 0)]?.segments == [SegmentDraft(load: "100", reps: "5")])
    }

    @Test("stati: esercizio vuoto, parziale, completo")
    func completion() {
        let (content, slot) = session()
        #expect(slot.completion(logged: [:]) == .empty)
        #expect(slot.completion(logged: [top: 2]) == .partial)
        #expect(slot.completion(logged: [top: 2, backoff: 1]) == .complete)
        _ = content
    }

    // MARK: Timer di recupero

    private func group(of members: [SlotContent], between: Int = 15, afterRound: Int = 90, kind: String = "superset") -> GroupContent {
        GroupContent(id: UUID(), kind: kind, restBetweenS: between, restAfterRoundS: afterRound, slots: members)
    }

    private func slotWith(sets: Int, rest: Int?) -> SlotContent {
        let block = BlockContent(
            id: UUID(), role: "working", technique: "none", restS: rest, tut: [], refBlockId: nil,
            prescription: Prescription(sets: sets))
        return SlotContent(id: UUID(), exerciseName: "Esercizio", coachNotes: nil, blocks: [block])
    }

    private func model(for slot: SlotContent, in groups: [GroupContent]) throws -> ExerciseModel {
        let content = SessionContent(
            sessionID: Sample.session, mesocycleID: Sample.mesocycle, athleteID: Sample.athlete, deloadWeeks: [],
            name: "S", coachNotes: nil, groups: groups, loggedCounts: [:])
        return ExerciseModel(session: content, slot: slot, week: 1, store: ExecutionStore(database: try AppDatabase.inMemory()))
    }

    @Test("esercizio da solo: recupero del blocco, scorre alla serie dopo; ultima serie della seduta senza pulsante")
    func singleExerciseTimer() async throws {
        let a = slotWith(sets: 3, rest: 120)
        let model = try model(for: a, in: [group(of: [a], kind: "single")])
        await model.load()
        let block = a.blocks[0]
        #expect(model.restSeconds(for: block) == 120)
        #expect(model.showsTimerButton(SetKey(block: block.id, idx: 0), block: block))
        #expect(model.advance(after: SetKey(block: block.id, idx: 0)) == .set(SetKey(block: block.id, idx: 1)))
        #expect(!model.showsTimerButton(SetKey(block: block.id, idx: 2), block: block))  // l'ultima della seduta
    }

    @Test("recupero 0: il pulsante non compare")
    func noRestNoButton() async throws {
        let a = slotWith(sets: 3, rest: nil)
        let model = try model(for: a, in: [group(of: [a], kind: "single")])
        await model.load()
        #expect(!model.showsTimerButton(SetKey(block: a.blocks[0].id, idx: 0), block: a.blocks[0]))
    }

    @Test("superset: tra gli esercizi rest_between_s e si passa al successivo; dopo l'ultimo rest_after_round_s e si torna al primo alla serie dopo")
    func supersetTimer() async throws {
        let a = slotWith(sets: 2, rest: 999), b = slotWith(sets: 2, rest: 999)
        let groups = [group(of: [a, b])]
        let first = try model(for: a, in: groups), second = try model(for: b, in: groups)
        await first.load()
        await second.load()
        #expect(first.restSeconds(for: a.blocks[0]) == 15)
        #expect(first.advance(after: SetKey(block: a.blocks[0].id, idx: 0)) == .slot(b.id, setIdx: 0))
        #expect(second.restSeconds(for: b.blocks[0]) == 90)
        #expect(second.advance(after: SetKey(block: b.blocks[0].id, idx: 0)) == .slot(a.id, setIdx: 1))
        // Ultimo giro, ultimo esercizio, ultima seduta: niente pulsante.
        #expect(!second.showsTimerButton(SetKey(block: b.blocks[0].id, idx: 1), block: b.blocks[0]))
        #expect(second.showsTimerButton(SetKey(block: b.blocks[0].id, idx: 0), block: b.blocks[0]))
    }

    @Test("finito un gruppo si passa al primo esercizio del gruppo dopo")
    func nextGroup() async throws {
        let a = slotWith(sets: 1, rest: 60), b = slotWith(sets: 3, rest: 60)
        let groups = [group(of: [a], kind: "single"), group(of: [b], kind: "single")]
        let model = try model(for: a, in: groups)
        await model.load()
        #expect(model.advance(after: SetKey(block: a.blocks[0].id, idx: 0)) == .slot(b.id, setIdx: 0))
    }
}
