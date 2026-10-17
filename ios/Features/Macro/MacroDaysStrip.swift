import Domain
import SwiftUI

/// Gli ultimi giorni come una griglia di quadratini, una settimana per riga (oggi in basso a destra): verde rispettati,
/// rosso no, vuoto non registrato. Un tocco apre il giorno.
struct MacroDaysStrip: View {
    @Environment(\.palette) private var palette
    /// Il più recente per primo, come li dà `NutritionSnapshot`.
    let days: [DayEntry]
    let onOpen: (DayEntry) -> Void

    var body: some View {
        let ordered = Array(days.reversed())
        // La prima riga può essere più corta: si allinea a destra, così le colonne restano i giorni della settimana.
        let pad = (7 - ordered.count % 7) % 7
        let cells: [DayEntry?] = Array(repeating: nil, count: pad) + ordered.map { $0 }
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(summary).font(.subheadline).foregroundStyle(.secondary)
            VStack(spacing: Theme.Space.xs) {
                ForEach(Array(stride(from: 0, to: cells.count, by: 7)), id: \.self) { start in
                    HStack(spacing: Theme.Space.xs) {
                        ForEach(start..<min(start + 7, cells.count), id: \.self) { index in
                            if let entry = cells[index] {
                                cell(entry, isToday: entry.day == days.first?.day)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 52)
                            }
                        }
                    }
                }
            }
        }
    }

    private var summary: String {
        let yes = days.filter { $0.status == .respected }.count
        let no = days.filter { $0.status == .notRespected }.count
        let open = days.count - yes - no
        return "\(yes) rispettati · \(no) no · \(open) da segnare"
    }

    private func cell(_ entry: DayEntry, isToday: Bool) -> some View {
        let fill: Color = switch entry.status {
        case .respected: .green
        case .notRespected: .red
        case nil: .clear
        }
        return Button {
            onOpen(entry)
        } label: {
            VStack(spacing: 0) {
                Text(Self.weekday(entry.day)).font(.footnote)
                Text(Self.dayNumber(entry.day)).font(.headline.monospacedDigit())
            }
            .foregroundStyle(entry.status == nil ? palette.ink : Color.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(fill, in: .rect(cornerRadius: Theme.Radius.s))
            .overlay {
                if entry.status == nil || isToday {
                    RoundedRectangle(cornerRadius: Theme.Radius.s)
                        .stroke(isToday ? palette.accent : palette.ink.opacity(0.2), lineWidth: isToday ? 2 : 1)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.spoken(entry, isToday: isToday))
    }

    /// «L», «M»… per la colonna.
    private static func weekday(_ day: String) -> String {
        date(day)?.formatted(.dateTime.weekday(.narrow)) ?? ""
    }

    private static func dayNumber(_ day: String) -> String {
        day.split(separator: "-").last.map { String(Int($0) ?? 0) } ?? day
    }

    private static func date(_ day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Per VoiceOver: «oggi, venerdì 17 ottobre, rispettati, 2790 kcal».
    private static func spoken(_ entry: DayEntry, isToday: Bool) -> String {
        let state =
            switch entry.status {
            case .respected: "rispettati"
            case .notRespected: "non rispettati"
            case nil: "non registrato"
            }
        let kcal = entry.intake.kcal.map { ", \(NumberInput.text($0)) kcal" } ?? ""
        return "\(isToday ? "oggi, " : "")\(MacroDayTitle.text(entry.day)), \(state)\(kcal)"
    }
}
