import Domain
import Testing

@testable import Gradus

/// L'app si compone e vede il pacchetto Domain: la prima settimana non ha mai un riferimento.
struct AppTests {
    @Test("l'app collega il pacchetto Domain")
    func domainIsLinked() {
        let none = PreviousWeek.references(
            mesocycleID: .init(), sessionID: .init(), week: 1, deloadWeeks: [], blockOrder: [], logs: [])
        #expect(none.isEmpty)
    }

    @Test("la vista radice si crea")
    @MainActor
    func rootView() {
        _ = RootView()
    }
}
