import Foundation
import Testing

@testable import Domain

struct ExecutionRulesTests {
    @Test("gli id derivati sono stabili, validi e diversi per chiave")
    func deterministicIDs() {
        let session = UUID(uuidString: "20000000-0000-4000-8000-000000000001")!
        let a = DeterministicID.workout(sessionID: session, week: 3)
        #expect(a == DeterministicID.workout(sessionID: session, week: 3))
        #expect(a != DeterministicID.workout(sessionID: session, week: 4))
        let bytes = a.uuid
        #expect(bytes.6 >> 4 == 5)  // versione 5
        #expect(bytes.8 >> 6 == 0b10)  // variante RFC 4122
        let log = DeterministicID.setLog(workoutID: a, blockID: session, setIdx: 0)
        #expect(log != DeterministicID.setLog(workoutID: a, blockID: session, setIdx: 1))
        #expect(DeterministicID.segment(setLogID: log, segIdx: 0) != DeterministicID.segment(setLogID: log, segIdx: 1))
    }

    @Test("UUID v5 coincide con l'implementazione di riferimento (RFC 4122, namespace DNS)")
    func knownVector() {
        // uuid5(NAMESPACE_DNS, "python.org") = 886313e1-3b8a-5372-9b90-0c9aee199e5d
        let dns = UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8")!
        #expect(DeterministicID.v5(namespace: dns, name: "python.org").uuidString == "886313E1-3B8A-5372-9B90-0C9AEE199E5D")
    }

    @Test("stato: vuoto, parziale, completo")
    func completion() {
        #expect(Completion(logged: 0, prescribed: 3) == .empty)
        #expect(Completion(logged: 2, prescribed: 3) == .partial)
        #expect(Completion(logged: 3, prescribed: 3) == .complete)
        #expect(Completion(logged: 4, prescribed: 3) == .complete)
        #expect(Completion.combined([.complete, .complete]) == .complete)
        #expect(Completion.combined([.complete, .empty]) == .partial)
        #expect(Completion.combined([.empty, .empty]) == .empty)
        #expect(Completion.combined([]) == .empty)
    }

    @Test("scale dello sforzo: quella del coach (RPE), altrimenti ripetizioni in riserva; tasti interi e mezzo punto")
    func effort() {
        #expect(EffortOptions.scale(prescribed: .rpe) == .rpe)
        #expect(EffortOptions.scale(prescribed: .buf) == .buf)
        #expect(EffortOptions.scale(prescribed: .load) == .buf)
        #expect(EffortOptions.scale(prescribed: nil) == .buf)
        #expect(EffortOptions.wholeValues(for: .buf) == [0, 1, 2, 3, 4, 5])
        #expect(EffortOptions.wholeValues(for: .rpe) == [6, 7, 8, 9, 10])
        #expect(EffortOptions.halfStep(above: 2, scale: .buf) == 2.5)
        #expect(EffortOptions.halfStep(above: 4, scale: .buf) == 4.5)
        #expect(EffortOptions.halfStep(above: 5, scale: .buf) == nil)  // 5,5 non esiste
        #expect(EffortOptions.halfStep(above: 9, scale: .rpe) == 9.5)
        #expect(EffortOptions.halfStep(above: 10, scale: .rpe) == nil)
    }

    @Test("conferma di eliminazione: l'email scritta a mano, senza badare a maiuscole e spazi")
    func deleteConfirmation() {
        #expect(DeleteConfirmation.matches("  Marco@Example.com ", email: "marco@example.com"))
        #expect(!DeleteConfirmation.matches("marco@example.co", email: "marco@example.com"))
        #expect(!DeleteConfirmation.matches("", email: ""))  // senza email nota non si conferma mai
    }

    @Test("numeri: virgola o punto, vuoto e testo non validi")
    func numbers() {
        #expect(NumberInput.decimal("82,5") == 82.5)
        #expect(NumberInput.decimal(" 100 ") == 100)
        #expect(NumberInput.decimal("") == nil)
        #expect(NumberInput.decimal("abc") == nil)
        #expect(NumberInput.decimal("-5") == nil)
        #expect(NumberInput.integer("8") == 8)
        #expect(NumberInput.integer("8,5") == nil)
        #expect(NumberInput.text(82.5) == "82,5")
    }
}

struct ProfileNameTests {
    @Test("il nome si ripulisce: spazi in eccesso via, vuoto non valido, tetto di lunghezza")
    func normalized() {
        #expect(ProfileName.normalized("  Marco   Rossi ") == "Marco Rossi")
        #expect(ProfileName.normalized("Anna\nMaria") == "Anna Maria")
        #expect(ProfileName.normalized("   ") == nil)
        #expect(ProfileName.normalized("") == nil)
        #expect(ProfileName.normalized(String(repeating: "a", count: 200))?.count == 80)
    }
}
