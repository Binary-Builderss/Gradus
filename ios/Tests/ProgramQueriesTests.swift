import Domain
import Foundation
import GRDB
import Testing

@testable import Gradus

struct ProgramQueriesTests {
    private func synced(status: String = "active") async throws -> AppDatabase {
        let remote = FakeRemote()
        Sample.populate(remote, status: status)
        let database = try AppDatabase.inMemory()
        _ = try await SyncEngine(remote: remote, database: database).sync()
        return database
    }

    @Test("la home: mesociclo attivo, coach e sedute con il numero di esercizi")
    func home() async throws {
        let database = try await synced()
        let home = try await database.writer.read { try ProgramQueries.home($0, athleteID: Sample.athlete) }
        #expect(home.mesocycle?.name == "Ipertrofia 1")
        #expect(home.athleteName == "Marco Rossi")
        #expect(home.coachName == "Giulia Coach")
        #expect(home.sessions.map(\.name) == ["Spinta", "Tirata"])
        #expect(home.sessions.map(\.exerciseCount) == [2, 0])
    }

    @Test("senza un mesociclo attivo non c'è nulla da mostrare (concluso o bozza non contano)")
    func noActive() async throws {
        for status in ["completed", "draft"] {
            let database = try await synced(status: status)
            let home = try await database.writer.read { try ProgramQueries.home($0, athleteID: Sample.athlete) }
            #expect(home.mesocycle == nil)
            #expect(home.sessions.isEmpty)
        }
    }

    @Test("una seduta in una settimana: gruppi, esercizi e prescrizione di ogni blocco")
    func sessionContent() async throws {
        let database = try await synced()
        let content = try await database.writer.read { try ProgramQueries.session($0, id: Sample.session, week: 1) }
        let group = try #require(content?.groups.first)
        #expect(group.kind == "superset")
        #expect(group.restAfterRoundS == 90)
        #expect(group.slots.map(\.exerciseName) == ["Panca piana", "Croci ai cavi"])
        #expect(group.slots[0].coachNotes == "Gomiti stretti")
        let blocks = group.slots[0].blocks
        #expect(blocks.map(\.role) == ["top", "backoff"])
        #expect(blocks[0].restS == 180)
        #expect(blocks[0].prescription?.text == "1 serie da 5 ripetizioni, 3 ripetizioni in riserva")
        #expect(blocks[1].prescription?.text == "2 serie da 8-10 ripetizioni, 85% del carico del top set")
        #expect(group.slots[1].blocks.isEmpty)
    }

    @Test("la prescrizione cambia con la settimana; senza prescrizione lo dice")
    func otherWeek() async throws {
        let database = try await synced()
        let week2 = try await database.writer.read { try ProgramQueries.session($0, id: Sample.session, week: 2) }
        #expect(week2?.groups[0].slots[0].blocks[0].prescription?.text == "1 serie da 5 ripetizioni, 2 ripetizioni in riserva")
        #expect(week2?.groups[0].slots[0].blocks[1].prescription == nil)
    }

    @Test("una seduta che non esiste (o eliminata) non dà nulla")
    func missing() async throws {
        let database = try await synced()
        let none = try await database.writer.read { try ProgramQueries.session($0, id: UUID(), week: 1) }
        #expect(none == nil)
    }
}
