import Foundation
import Testing

@testable import Domain

struct RestTimerTests {
    @Test("esercizio da solo: il recupero del blocco; senza valore, niente")
    func single() {
        #expect(RestPlan.seconds(groupSize: 1, position: 0, blockRestS: 180, restBetweenS: 30, restAfterRoundS: 90) == 180)
        #expect(RestPlan.seconds(groupSize: 1, position: 0, blockRestS: nil, restBetweenS: 30, restAfterRoundS: 90) == 0)
    }

    @Test("gruppo: tra un esercizio e l'altro rest_between_s, dopo l'ultimo rest_after_round_s (il recupero del blocco non conta)")
    func group() {
        #expect(RestPlan.seconds(groupSize: 3, position: 0, blockRestS: 180, restBetweenS: 15, restAfterRoundS: 90) == 15)
        #expect(RestPlan.seconds(groupSize: 3, position: 1, blockRestS: 180, restBetweenS: 15, restAfterRoundS: 90) == 15)
        #expect(RestPlan.seconds(groupSize: 3, position: 2, blockRestS: 180, restBetweenS: 15, restAfterRoundS: 90) == 90)
        #expect(RestPlan.seconds(groupSize: 2, position: 0, blockRestS: nil, restBetweenS: 0, restAfterRoundS: 60) == 0)
    }

    @Test("il pulsante non compare con durata 0, né sull'ultima serie della seduta")
    func button() {
        #expect(RestPlan.showsButton(seconds: 90, isLastSetOfSession: false))
        #expect(!RestPlan.showsButton(seconds: 0, isLastSetOfSession: false))
        #expect(!RestPlan.showsButton(seconds: 90, isLastSetOfSession: true))
    }

    @Test("il residuo si calcola dall'orario di fine, anche dopo un lungo background")
    func remaining() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let timer = RestTimerState(startingAt: start, seconds: 90, title: "Panca")
        #expect(timer.remainingSeconds(at: start) == 90)
        #expect(timer.remainingSeconds(at: start.addingTimeInterval(30.2)) == 60)
        #expect(timer.remainingSeconds(at: start.addingTimeInterval(89.9)) == 1)
        #expect(!timer.isFinished(at: start.addingTimeInterval(89.9)))
        #expect(timer.isFinished(at: start.addingTimeInterval(90)))
        #expect(timer.remainingSeconds(at: start.addingTimeInterval(3600)) == 0)  // mai negativo
    }

    @Test("±15 s sposta la fine; sotto zero è finito")
    func adjust() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let timer = RestTimerState(startingAt: start, seconds: 90, title: "Panca")
        #expect(timer.adjusted(bySeconds: 15).remainingSeconds(at: start) == 105)
        #expect(timer.adjusted(bySeconds: -15).remainingSeconds(at: start) == 75)
        #expect(timer.adjusted(bySeconds: -15).adjusted(bySeconds: -90).isFinished(at: start))
    }

    @Test("si salva e si ricarica identico (sopravvive alla chiusura dell'app)")
    func codable() throws {
        let timer = RestTimerState(endDate: Date(timeIntervalSince1970: 1_000_090), title: "Panca · serie 2")
        let data = try JSONEncoder().encode(timer)
        #expect(try JSONDecoder().decode(RestTimerState.self, from: data) == timer)
    }

    @Test("orologio")
    func clock() {
        #expect(RestTimerState.clock(90) == "1:30")
        #expect(RestTimerState.clock(5) == "0:05")
        #expect(RestTimerState.clock(0) == "0:00")
    }
}
