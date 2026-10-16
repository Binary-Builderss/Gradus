import Foundation

/// Il giorno «aaaa-mm-gg» come testo: per esteso nel titolo della schermata, abbreviato nell'elenco («ven 16 ott»).
enum MacroDayTitle {
    static func text(_ day: String, abbreviated: Bool = false) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else {
            return day
        }
        return abbreviated
            ? date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            : date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
