import Foundation
import Testing

@testable import Domain

struct PreviousWeekFormatTests {
    private func ref(_ week: Int, _ segments: [Segment], _ effort: Effort? = nil) -> PreviousWeekReference {
        PreviousWeekReference(blockID: UUID(), setIdx: 0, week: week, segments: segments, effort: effort)
    }

    @Test("serie con sforzo: «Sett. 3: 100 × 5 · BUF 1»")
    func withEffort() {
        let r = ref(3, [Segment(loadKg: 100, reps: 5)], Effort(value: 1, scale: .buf))
        #expect(r.text == "Sett. 3: 100 × 5 · BUF 1")
    }

    @Test("drop set: i segmenti separati da «+»")
    func drop() {
        let r = ref(3, [Segment(loadKg: 100, reps: 8), Segment(loadKg: 75, reps: 6)])
        #expect(r.text == "Sett. 3: 100 × 8 + 75 × 6")
    }

    @Test("decimali all'italiana, RPE con mezzo punto")
    func decimals() {
        let r = ref(2, [Segment(loadKg: 102.5, reps: 5)], Effort(value: 8.5, scale: .rpe))
        #expect(r.text == "Sett. 2: 102,5 × 5 · RPE 8,5")
    }

    @Test("sforzo 0 si scrive: a cedimento è un dato")
    func zeroEffort() {
        let r = ref(2, [Segment(loadKg: 80, reps: 10)], Effort(value: 0, scale: .buf))
        #expect(r.text == "Sett. 2: 80 × 10 · BUF 0")
    }

    @Test("solo sforzo, nessun carico")
    func effortOnly() {
        #expect(ref(2, [], Effort(value: 2, scale: .buf)).text == "Sett. 2: BUF 2")
    }

    @Test("carico o ripetizioni mancanti: un trattino, mai un numero inventato")
    func missingValues() {
        let r = ref(4, [Segment(loadKg: nil, reps: 12), Segment(loadKg: 20, reps: nil)])
        #expect(r.text == "Sett. 4: – × 12 + 20 × –")
    }
}
