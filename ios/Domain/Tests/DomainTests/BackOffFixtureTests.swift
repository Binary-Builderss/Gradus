import Foundation
import Testing

@testable import Domain

/// Gli stessi casi del test pgTAP generato da `fixtures/backoff_cases.json`.
struct BackOffFixtureTests {
    struct File: Decodable { var cases: [Case] }

    struct Case: Decodable {
        var name: String
        var input: Input
        var expected: Expected
    }

    struct Input: Decodable {
        var topLoadKg: Double
        var refPct: Double

        enum CodingKeys: String, CodingKey {
            case topLoadKg = "top_load_kg"
            case refPct = "ref_pct"
        }
    }

    struct Expected: Decodable {
        var targetKg: Double

        enum CodingKeys: String, CodingKey { case targetKg = "target_kg" }
    }

    static let cases: [Case] = {
        let data = try! Data(contentsOf: Fixtures.url("backoff_cases.json"))
        return try! JSONDecoder().decode(File.self, from: data).cases
    }()

    @Test("fixture condivise: carico target del back-off", arguments: cases)
    func fixture(_ c: Case) {
        let target = BackOff.targetLoad(topLoadKg: c.input.topLoadKg, refPct: c.input.refPct)
        #expect(target == c.expected.targetKg, "\(c.name)")
    }
}

extension BackOffFixtureTests.Case: CustomTestStringConvertible {
    var testDescription: String { name }
}
