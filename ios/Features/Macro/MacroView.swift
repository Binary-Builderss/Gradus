import Domain
import SwiftUI

/// Macro: l'obiettivo di oggi (lo scrive il coach) e gli ultimi giorni (li registra l'atleta, con il suo consenso).
struct MacroView: View {
    let environment: AppEnvironment
    let userID: UUID
    @State private var model = MacroModel()
    @State private var editing: DayEntry?
    @State private var askingNumbers: DayEntry?
    @State private var consenting = false

    var body: some View {
        NavigationStack {
            List {
                if let snapshot = model.snapshot {
                    targetSection(snapshot)
                    if !snapshot.consent { consentSection }
                    daysSection(snapshot)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Macro")
            .refreshable { await environment.sync.sync() }
            .sheet(item: $editing) { entry in
                MacroDayView(environment: environment, userID: userID, entry: entry) { editing = nil }
            }
            .sheet(isPresented: $consenting) {
                MacroConsentView(environment: environment, userID: userID) { consenting = false }
            }
            .confirmationDialog(
                "Vuoi inserire quanto hai assunto?",
                isPresented: Binding(get: { askingNumbers != nil }, set: { if !$0 { askingNumbers = nil } }),
                titleVisibility: .visible
            ) {
                Button("Inserisci i numeri") { editing = askingNumbers }
                Button("Non ora", role: .cancel) {}
            } message: {
                Text("Ho segnato i macro di oggi come non rispettati. Puoi aggiungere calorie e macro, o lasciarlo così.")
            }
            // Un promemoria serale: «Sì»/«No» registrano da soli; «No» chiede se inserire i numeri, il tocco apre il giorno.
            .onChange(of: model.snapshot) { _, _ in routeReminder() }
            .onChange(of: environment.reminders.coordinator.openDay) { _, _ in routeReminder() }
            .onChange(of: environment.reminders.coordinator.askManualEntry) { _, _ in routeReminder() }
        }
        .task { await model.watch(database: environment.database, userID: userID) }
    }

    private func routeReminder() {
        let coordinator = environment.reminders.coordinator
        guard let snapshot = model.snapshot else { return }
        if let day = coordinator.openDay, let entry = snapshot.days.first(where: { $0.day == day }) {
            coordinator.openDay = nil
            if snapshot.consent { editing = entry } else { consenting = true }
        }
        if let day = coordinator.askManualEntry, let entry = snapshot.days.first(where: { $0.day == day }) {
            coordinator.askManualEntry = nil
            if snapshot.consent { askingNumbers = entry }
        }
    }

    private func targetSection(_ snapshot: NutritionSnapshot) -> some View {
        Section {
            if let plan = snapshot.today {
                let t = plan.targets
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(t.kcal) kcal").font(.title2.bold())
                    HStack(spacing: 16) {
                        stat("Proteine", t.proteinG)
                        stat("Carboidrati", t.carbsG)
                        stat("Grassi", t.fatG)
                        if let fiber = t.fiberG { stat("Fibre", fiber) }
                    }
                    Text("Tolleranza ±\(plan.tolerancePct)%").font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .tourTarget("macro-target")
            } else {
                Text("Il tuo coach non ha ancora impostato i macro.").foregroundStyle(.secondary)
                    .tourTarget("macro-target")
            }
        } header: {
            Text("Obiettivo di oggi")
        }
    }

    private func stat(_ name: String, _ grams: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(grams) g").font(.headline.monospacedDigit())
            Text(name).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var consentSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Condividi i tuoi macro con il coach").font(.headline)
                Text("Per registrare come vanno i tuoi macro serve il tuo consenso: sono dati sulla tua salute e li vede anche il tuo coach.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Continua") { consenting = true }.buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 4)
        }
    }

    private func daysSection(_ snapshot: NutritionSnapshot) -> some View {
        Section("Ultimi giorni") {
            ForEach(snapshot.days) { entry in
                Button {
                    if snapshot.consent { editing = entry } else { consenting = true }
                } label: {
                    DayRow(entry: entry)
                        .tourTarget("macro-days", if: entry.day == snapshot.days.first?.day)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct DayRow: View {
    let entry: DayEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.title(entry.day)).font(.headline)
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

    /// «Ven 16 ott».
    static func title(_ day: String) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else {
            return day
        }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
