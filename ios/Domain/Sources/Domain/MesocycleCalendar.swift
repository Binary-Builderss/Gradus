import Foundation

public enum MesocycleCalendar {
    /// La settimana del mesociclo in cui cade `today`, da 1 a `weeks`. Prima della data di inizio è la 1, dopo la
    /// fine è l'ultima: l'app apre sempre su una settimana che esiste.
    ///
    /// - Parameter startDate: la data di inizio come la dà il database (`yyyy-MM-dd`).
    public static func currentWeek(startDate: String, weeks: Int, today: Date, calendar: Calendar = .current) -> Int {
        guard let start = date(startDate, calendar: calendar), weeks > 0 else { return 1 }
        let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: today)).day ?? 0
        return min(max(days / 7 + 1, 1), weeks)
    }

    /// Il mesociclo non è ancora iniziato.
    public static func hasStarted(startDate: String, today: Date, calendar: Calendar = .current) -> Bool {
        guard let start = date(startDate, calendar: calendar) else { return true }
        return calendar.startOfDay(for: today) >= start
    }

    /// «5 ott 2026» per l'intestazione.
    public static func label(startDate: String, calendar: Calendar = .current) -> String {
        guard let start = date(startDate, calendar: calendar) else { return startDate }
        return start.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "it_IT")))
    }

    private static func date(_ iso: String, calendar: Calendar) -> Date? {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
