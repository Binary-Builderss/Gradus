import Domain
import SwiftUI

struct DayRow: View {
    let entry: DayEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(MacroDayTitle.text(entry.day, abbreviated: true)).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch entry.status {
        case .respected: "checkmark.circle.fill"
        case .notRespected: "xmark.circle.fill"
        case nil: "minus.circle"
        }
    }

    private var color: Color {
        switch entry.status {
        case .respected: .green
        case .notRespected: .red
        case nil: .secondary
        }
    }

    private var subtitle: String {
        let state =
            switch entry.status {
            case .respected: "Rispettati"
            case .notRespected: "Non rispettati"
            case nil: "Non registrato"
            }
        guard let kcal = entry.intake.kcal else { return state }
        return "\(state) · \(NumberInput.text(kcal)) kcal"
    }
}
