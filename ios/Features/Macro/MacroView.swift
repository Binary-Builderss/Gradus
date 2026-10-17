import Domain
import SwiftUI

/// Macro: l'obiettivo di oggi (lo scrive il coach) e gli ultimi giorni (li registra l'atleta, con il suo consenso).
struct MacroView: View {
    @Environment(\.palette) private var palette
    let environment: AppEnvironment
    let userID: UUID
    @State private var model = MacroModel()
    @State private var editing: DayEntry?
    @State private var askingNumbers: DayEntry?
    @State private var consenting = false
    /// Le calorie in cifre grandi seguono la dimensione del testo di iOS, con un tetto.
    @ScaledMetric(relativeTo: .largeTitle) private var digits = 64.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    if let snapshot = model.snapshot {
                        targetCard(snapshot)
                        if !snapshot.consent { consentCard }
                        daysCard(snapshot)
                    } else if model.readFailed {
                        ReadFailedView()
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, Theme.Space.xl)
                    }
                }
                .padding(Theme.Space.m)
            }
            .background(palette.background)
            .navigationTitle("Macro")
            .refreshable { await environment.sync.sync() }
            .sheet(item: $editing) { entry in
                MacroDayView(environment: environment, userID: userID, entry: entry) { editing = nil }
            }
            .sheet(isPresented: $consenting) {
                MacroConsentView(environment: environment, userID: userID) { consenting = false }
            }
            .confirmationDialog("Vuoi inserire quanto hai assunto?", item: $askingNumbers, titleVisibility: .visible) { entry in
                Button("Inserisci i numeri") { editing = entry }
                Button("Non ora", role: .cancel) {}
            } message: { _ in
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

    /// L'obiettivo di oggi (lo scrive il coach): le calorie in cifre grandi, sotto i grammi di ogni macro.
    private func targetCard(_ snapshot: NutritionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("Obiettivo di oggi").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            if let plan = snapshot.today {
                let t = plan.targets
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
                    Text("\(t.kcal)").font(.system(size: min(digits, 96), weight: .heavy).monospacedDigit())
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text("kcal").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                HStack(alignment: .top, spacing: Theme.Space.l) {
                    stat("Proteine", t.proteinG)
                    stat("Carboidrati", t.carbsG)
                    stat("Grassi", t.fatG)
                    if let fiber = t.fiberG { stat("Fibre", fiber) }
                }
                Text("Tolleranza ±\(plan.tolerancePct)%, decisa dal tuo coach").font(.footnote).foregroundStyle(.secondary)
                    .padding(.top, Theme.Space.xs)
            } else {
                Text("Il tuo coach non ha ancora impostato i macro.").foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(palette.ink)
        .card()
        .tourTarget("macro-target")
    }

    private func stat(_ name: String, _ grams: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(grams)").font(.title3.bold().monospacedDigit())
                Text("g").font(.footnote).foregroundStyle(.secondary)
            }
            Text(name).font(.footnote).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var consentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Condividi i tuoi macro con il coach").font(.headline)
            Text("Per registrare come vanno i tuoi macro serve il tuo consenso: sono dati sulla tua salute e li vede anche il tuo coach.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Continua") { consenting = true }.modifier(ProminentActionStyle())
        }
        .card()
    }

    /// Gli ultimi 14 giorni in una griglia: un tocco apre il giorno (o il consenso, se manca).
    private func daysCard(_ snapshot: NutritionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("Ultimi \(snapshot.days.count) giorni").font(.headline)
            MacroDaysStrip(days: snapshot.days) { entry in
                if snapshot.consent { editing = entry } else { consenting = true }
            }
            Text("Tocca un giorno per segnarlo o correggerlo, anche con calorie e macro.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .card()
        .tourTarget("macro-days")
    }
}
