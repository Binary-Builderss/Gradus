import Foundation
import Testing

@testable import Domain

struct BackOffTests {
    private let mesocycle = UUID(), session = UUID(), block = UUID()

    private func set(_ idx: Int, _ segments: [Segment]) -> LoggedSet {
        LoggedSet(
            mesocycleID: mesocycle, sessionID: session, blockID: block, week: 2, setIdx: idx, segments: segments,
            effort: nil)
    }

    @Test("il top set è la serie registrata per ultima")
    func lastSet() {
        let sets = [
            set(0, [Segment(loadKg: 100, reps: 5)]),
            set(1, [Segment(loadKg: 102.5, reps: 3)]),
        ]
        #expect(BackOff.referenceLoad(of: sets) == 102.5)
    }

    @Test("l'ordine delle serie in ingresso non conta")
    func unordered() {
        let sets = [set(1, [Segment(loadKg: 90, reps: 5)]), set(0, [Segment(loadKg: 100, reps: 5)])]
        #expect(BackOff.referenceLoad(of: sets) == 90)
    }

    @Test("drop set: il primo segmento, il più pesante")
    func dropSet() {
        let sets = [set(0, [Segment(loadKg: 100, reps: 8), Segment(loadKg: 75, reps: 6)])]
        #expect(BackOff.referenceLoad(of: sets) == 100)
    }

    @Test("una serie senza carico (solo ripetizioni) si salta: vale l'ultima con un carico")
    func skipsSetsWithoutLoad() {
        let sets = [set(0, [Segment(loadKg: 100, reps: 5)]), set(1, [Segment(loadKg: nil, reps: 5)])]
        #expect(BackOff.referenceLoad(of: sets) == 100)
    }

    @Test("nessun dato nel blocco di riferimento: nessun target")
    func noData() {
        #expect(BackOff.referenceLoad(of: []) == nil)
        #expect(BackOff.referenceLoad(of: [set(0, [Segment(loadKg: nil, reps: 5)])]) == nil)
    }

    @Test("il testo del riquadro: «≈ 90 kg», decimali all'italiana")
    func text() {
        #expect(BackOff.text(forTarget: 90) == "≈ 90 kg")
        #expect(BackOff.text(forTarget: 82.5) == "≈ 82,5 kg")
    }
}
