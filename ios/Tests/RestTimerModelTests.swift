import Domain
import Foundation
import Testing

@testable import Gradus

/// Un orologio che si muove a comando, per simulare background e lunghe attese.
final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 2_000_000)
    var date: Date { lock.withLock { current } }
    func advance(_ seconds: TimeInterval) { lock.withLock { current = current.addingTimeInterval(seconds) } }
}

actor FakeNotifier: RestNotifier {
    private(set) var scheduled: [(date: Date, body: String)] = []
    private(set) var cancels = 0
    private(set) var authorizations = 0
    func requestAuthorizationIfNeeded() { authorizations += 1 }
    func schedule(at date: Date, title: String, body: String) { scheduled.append((date, body)) }
    func cancel() { cancels += 1 }
}

@MainActor
final class FakeFeedback: RestFeedback {
    private(set) var calls: [(sound: Bool, haptic: Bool)] = []
    func finished(sound: Bool, haptic: Bool) { calls.append((sound, haptic)) }
}

@MainActor
struct RestTimerModelTests {
    private func make(defaults: UserDefaults? = nil, clock: Clock = Clock()) -> (RestTimerModel, FakeNotifier, FakeFeedback, Clock, UserDefaults) {
        let defaults = defaults ?? UserDefaults(suiteName: "rest-timer-\(UUID())")!
        let notifier = FakeNotifier()
        let feedback = FakeFeedback()
        let model = RestTimerModel(defaults: defaults, notifier: notifier, feedback: feedback, now: { clock.date }, autoFinish: false)
        return (model, notifier, feedback, clock, defaults)
    }

    private func settle() async { try? await Task.sleep(for: .milliseconds(50)) }

    @Test("avvia: residuo dalla durata, notifica programmata all'orario di fine")
    func start() async {
        let (model, notifier, _, clock, _) = make()
        model.start(seconds: 90, title: "Panca piana · serie 1")
        await settle()
        #expect(model.remainingSeconds(at: clock.date) == 90)
        let scheduled = await notifier.scheduled
        #expect(scheduled.count == 1)
        #expect(scheduled[0].date == clock.date.addingTimeInterval(90))
        #expect(scheduled[0].body == "Panca piana · serie 1")
        #expect(await notifier.authorizations == 1)
    }

    @Test("durata 0: nessun timer")
    func zeroDuration() {
        let (model, _, _, _, _) = make()
        model.start(seconds: 0, title: "x")
        #expect(model.state == nil)
    }

    @Test("un nuovo avvio sostituisce il precedente: un solo timer, una sola notifica attiva")
    func replace() async {
        let (model, notifier, _, clock, _) = make()
        model.start(seconds: 90, title: "A")
        clock.advance(10)
        model.start(seconds: 60, title: "B")
        await settle()
        #expect(model.state?.title == "B")
        #expect(model.remainingSeconds(at: clock.date) == 60)
        #expect(await notifier.scheduled.last?.body == "B")  // stesso identificatore: sostituisce la precedente
    }

    @Test("+15 s e −15 s spostano la fine e riprogrammano la notifica")
    func adjust() async {
        let (model, notifier, _, clock, _) = make()
        model.start(seconds: 90, title: "A")
        model.adjust(bySeconds: 15)
        #expect(model.remainingSeconds(at: clock.date) == 105)
        model.adjust(bySeconds: -15)
        model.adjust(bySeconds: -15)
        #expect(model.remainingSeconds(at: clock.date) == 75)
        await settle()
        #expect(await notifier.scheduled.count == 4)
    }

    @Test("−15 s sotto zero chiude il timer, senza vibrare")
    func adjustBelowZero() async {
        let (model, notifier, feedback, clock, _) = make()
        model.start(seconds: 10, title: "A")
        clock.advance(2)
        model.adjust(bySeconds: -15)
        await settle()
        #expect(model.state == nil)
        #expect(feedback.calls.isEmpty)
        #expect(await notifier.cancels == 1)
    }

    @Test("Salta annulla la notifica e chiude senza avvisi")
    func skip() async {
        let (model, notifier, feedback, _, defaults) = make()
        model.start(seconds: 90, title: "A")
        model.skip()
        await settle()
        #expect(model.state == nil)
        #expect(await notifier.cancels == 1)
        #expect(feedback.calls.isEmpty)
        #expect(defaults.data(forKey: RestTimerModel.stateKey) == nil)
    }

    @Test("alla fine con l'app aperta: vibrazione e suono, secondo le impostazioni")
    func finishWithFeedback() async {
        let (model, _, feedback, clock, defaults) = make()
        defaults.set(false, forKey: RestTimerModel.soundKey)
        model.start(seconds: 30, title: "A")
        model.completeIfDue()
        #expect(model.state != nil)  // non ancora
        clock.advance(31)
        model.completeIfDue()
        #expect(model.state == nil)
        #expect(feedback.calls.count == 1)
        #expect(feedback.calls[0].sound == false)
        #expect(feedback.calls[0].haptic == true)
    }

    @Test("dopo un lungo background il residuo si ricalcola dall'orario di fine; se è scaduto la barra sparisce senza vibrare")
    func backgroundAndRestart() async {
        let clock = Clock()
        let (first, _, _, _, defaults) = make(clock: clock)
        first.start(seconds: 90, title: "Panca")
        // L'app viene chiusa e riaperta dopo 40 s: lo stato è nel disco.
        clock.advance(40)
        let (second, _, feedback, _, _) = make(defaults: defaults, clock: clock)
        #expect(second.remainingSeconds(at: clock.date) == 50)
        #expect(second.state?.title == "Panca")
        // Torna in primo piano dopo un'ora: il recupero è finito da un pezzo, l'ha detto la notifica.
        clock.advance(3600)
        second.refresh()
        #expect(second.state == nil)
        #expect(feedback.calls.isEmpty)
        let (third, _, _, _, _) = make(defaults: defaults, clock: clock)
        #expect(third.state == nil)  // e non risorge al riavvio
    }
}
