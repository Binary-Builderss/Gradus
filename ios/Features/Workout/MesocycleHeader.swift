import Domain
import GRDB
import SwiftUI

struct MesocycleHeader: View {
    let mesocycle: MesocycleRecord
    let coach: String?
    let selected: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mesocycle.name).font(.title2.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            if !MesocycleCalendar.hasStarted(startDate: mesocycle.startDate, today: .now) {
                Text("Inizia il \(MesocycleCalendar.label(startDate: mesocycle.startDate))")
                    .font(.subheadline).foregroundStyle(.orange)
            }
            if mesocycle.deloadWeeks.contains(selected) {
                Label("Settimana di scarico", systemImage: "arrow.down.right.circle")
                    .font(.subheadline).foregroundStyle(.orange)
            }
        }
    }

    private var subtitle: String {
        let weeks = mesocycle.weeks == 1 ? "1 settimana" : "\(mesocycle.weeks) settimane"
        return [weeks, coach.map { "con \($0)" }].compactMap { $0 }.joined(separator: " · ")
    }
}
