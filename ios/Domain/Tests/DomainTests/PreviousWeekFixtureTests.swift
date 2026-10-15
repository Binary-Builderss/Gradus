import Foundation
import Testing

@testable import Domain

/// Gli stessi casi del test pgTAP generato da `fixtures/previous_week_cases.json` (vedi fixtures/README.md).
struct PreviousWeekFixtureTests {
    struct File: Decodable { var cases: [Case] }

    struct Case: Decodable {
        var name: String
        var input: Input
        var expected: [Expected]
    }

    struct Input: Decodable {
        var weeks: Int
        var deloadWeeks: [Int]
        var blocks: [String]
        var week: Int
        var logs: [Log]
        var otherSessionLogs: [Log]?
        var previousMesocycleLogs: [Log]?

        enum CodingKeys: String, CodingKey {
            case weeks, blocks, week, logs
            case deloadWeeks = "deload_weeks"
            case otherSessionLogs = "other_session_logs"
            case previousMesocycleLogs = "previous_mesocycle_logs"
        }
    }

    struct Log: Decodable {
        var week: Int
        var block: String
        var setIdx: Int
        var segments: [Segment]
        var effort: Effort?

        enum CodingKeys: String, CodingKey {
            case week, block, segments, effort
            case setIdx = "set_idx"
        }
    }

    struct Expected: Decodable {
        var block: String
        var setIdx: Int
        var week: Int
        var segments: [Segment]
        var effort: Effort?

        enum CodingKeys: String, CodingKey {
            case block, week, segments, effort
            case setIdx = "set_idx"
        }
    }

    static let cases: [Case] = {
        let url = Fixtures.url("previous_week_cases.json")
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(File.self, from: data).cases
    }()

    @Test("fixture condivise: riferimento alla settimana precedente", arguments: cases)
    func fixture(_ c: Case) {
        let mesocycle = UUID(), previousMesocycle = UUID()
        let session = UUID(), otherSession = UUID(), previousSession = UUID()
        let blockIDs = Dictionary(uniqueKeysWithValues: c.input.blocks.map { ($0, UUID()) })

        func logged(_ logs: [Log]?, mesocycle: UUID, session: UUID) -> [LoggedSet] {
            (logs ?? []).map {
                LoggedSet(
                    mesocycleID: mesocycle, sessionID: session, blockID: blockIDs[$0.block]!, week: $0.week,
                    setIdx: $0.setIdx, segments: $0.segments, effort: $0.effort)
            }
        }
        // Tutte le serie dell'atleta insieme, come nel database locale: la regola deve scegliere da sola.
        let all =
            logged(c.input.logs, mesocycle: mesocycle, session: session)
            + logged(c.input.otherSessionLogs, mesocycle: mesocycle, session: otherSession)
            + logged(c.input.previousMesocycleLogs, mesocycle: previousMesocycle, session: previousSession)

        let result = PreviousWeek.references(
            mesocycleID: mesocycle, sessionID: session, week: c.input.week,
            deloadWeeks: Set(c.input.deloadWeeks), blockOrder: c.input.blocks.map { blockIDs[$0]! }, logs: all)

        let expected = c.expected.map {
            PreviousWeekReference(
                blockID: blockIDs[$0.block]!, setIdx: $0.setIdx, week: $0.week, segments: $0.segments,
                effort: $0.effort)
        }
        #expect(result == expected, "\(c.name)")
    }
}

extension PreviousWeekFixtureTests.Case: CustomTestStringConvertible {
    var testDescription: String { name }
}
