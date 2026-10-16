import Foundation
import Testing

@testable import Domain

/// Gli stessi casi del test pgTAP generato da `fixtures/nutrition_target_cases.json`.
struct NutritionTargetFixtureTests {
    struct File: Decodable { var cases: [Case] }

    struct Case: Decodable {
        var name: String
        var input: Input
        var expected: Expected
    }

    struct Input: Decodable {
        var plans: [Plan]
        var day: String
    }

    struct Plan: Decodable {
        var validFrom: String
        var kcal: Int
        var deleted: Bool?

        enum CodingKeys: String, CodingKey {
            case validFrom = "valid_from"
            case kcal, deleted
        }
    }

    struct Expected: Decodable { var kcal: Int? }

    @Test("obiettivo in vigore: tutti i casi della fixture condivisa con SQL")
    func fixtureCases() throws {
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: Fixtures.url("nutrition_target_cases.json")))
        #expect(file.cases.count >= 10)
        for c in file.cases {
            let plans = c.input.plans.map { p in
                MacroPlan(
                    id: UUID(), validFrom: p.validFrom, deleted: p.deleted ?? false,
                    targets: MacroTargets(kcal: p.kcal, proteinG: 150, carbsG: 250, fatG: 70))
            }
            #expect(Nutrition.planInForce(plans, on: c.input.day)?.targets.kcal == c.expected.kcal, "\(c.name)")
        }
    }
}
