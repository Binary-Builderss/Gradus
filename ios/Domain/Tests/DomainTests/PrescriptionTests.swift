import Foundation
import Testing

@testable import Domain

struct PrescriptionTests {
    @Test("serie, ripetizioni e sforzo: «3 serie da 8-10 ripetizioni, 2 ripetizioni in riserva»")
    func full() {
        let p = Prescription(sets: 3, repsMin: 8, repsMax: 10, method: .buf, value: 2)
        #expect(p.text == "3 serie da 8-10 ripetizioni, 2 ripetizioni in riserva")
    }

    @Test("un solo numero di ripetizioni; solo serie")
    func simple() {
        #expect(Prescription(sets: 1, repsMin: 5, repsMax: 5, method: .buf, value: 3).text == "1 serie da 5 ripetizioni, 3 ripetizioni in riserva")
        #expect(Prescription(sets: 4).text == "4 serie")
        #expect(Prescription(sets: 3, repsMin: 12).text == "3 serie da 12 ripetizioni")
    }

    @Test("BUF 0 è a cedimento, BUF 1 è singolare")
    func buf() {
        #expect(Prescription(sets: 2, method: .buf, value: 0).text == "2 serie, a cedimento")
        #expect(Prescription(sets: 2, method: .buf, value: 1).text == "2 serie, 1 ripetizione in riserva")
    }

    @Test("le altre misure dello sforzo")
    func methods() {
        #expect(Prescription(sets: 3, repsMin: 6, repsMax: 8, method: .rpe, value: 8.5).text == "3 serie da 6-8 ripetizioni, sforzo 8,5 su 10")
        #expect(Prescription(sets: 3, method: .load, value: 62.5).text == "3 serie, 62,5 kg")
        #expect(Prescription(sets: 3, method: .pct1RM, value: 75).text == "3 serie, 75% del massimale")
        #expect(Prescription(sets: 3, method: .rm, value: 8).text == "3 serie, carico da 8RM")
    }

    @Test("back-off: percentuale del top set")
    func backoff() {
        let p = Prescription(sets: 2, repsMin: 8, repsMax: 10, refPct: 85)
        #expect(p.text == "2 serie da 8-10 ripetizioni, 85% del carico del top set")
    }
}

struct MesocycleCalendarTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    @Test("giorno di inizio = settimana 1, dopo 7 giorni la 2")
    func weeks() {
        #expect(MesocycleCalendar.currentWeek(startDate: "2026-10-05", weeks: 6, today: day(2026, 10, 5, hour: 7), calendar: calendar) == 1)
        #expect(MesocycleCalendar.currentWeek(startDate: "2026-10-05", weeks: 6, today: day(2026, 10, 11, hour: 23), calendar: calendar) == 1)
        #expect(MesocycleCalendar.currentWeek(startDate: "2026-10-05", weeks: 6, today: day(2026, 10, 12), calendar: calendar) == 2)
        #expect(MesocycleCalendar.currentWeek(startDate: "2026-10-05", weeks: 6, today: day(2026, 11, 9), calendar: calendar) == 6)
    }

    @Test("prima dell'inizio è la 1, dopo la fine è l'ultima")
    func clamps() {
        #expect(MesocycleCalendar.currentWeek(startDate: "2026-10-05", weeks: 6, today: day(2026, 9, 1), calendar: calendar) == 1)
        #expect(MesocycleCalendar.currentWeek(startDate: "2026-10-05", weeks: 6, today: day(2027, 3, 1), calendar: calendar) == 6)
        #expect(MesocycleCalendar.hasStarted(startDate: "2026-10-05", today: day(2026, 10, 4), calendar: calendar) == false)
        #expect(MesocycleCalendar.hasStarted(startDate: "2026-10-05", today: day(2026, 10, 5, hour: 0), calendar: calendar))
    }

    @Test("un cambio d'ora non sposta la settimana")
    func daylightSaving() {
        // L'ora legale finisce il 25 ottobre 2026: tra il 19 e il 26 ci sono 7 giorni di calendario ma 169 ore.
        #expect(MesocycleCalendar.currentWeek(startDate: "2026-10-19", weeks: 6, today: day(2026, 10, 26, hour: 0), calendar: calendar) == 2)
    }

    @Test("data malformata: settimana 1, nessun errore")
    func malformed() {
        #expect(MesocycleCalendar.currentWeek(startDate: "boh", weeks: 6, today: Date(), calendar: calendar) == 1)
    }
}

struct RestTextTests {
    @Test("secondi leggibili")
    func format() {
        #expect(RestText.format(seconds: 45) == "45 s")
        #expect(RestText.format(seconds: 120) == "2 min")
        #expect(RestText.format(seconds: 90) == "1 min 30 s")
    }
}
