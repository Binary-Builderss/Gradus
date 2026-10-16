import Domain
import Foundation
import GRDB
import Observation

/// Lo stato della schermata dei macro, letto dal database locale.
@MainActor
@Observable
final class MacroModel {
    private(set) var snapshot: NutritionSnapshot?
    private(set) var readFailed = false

    func watch(database: AppDatabase, userID: UUID) async {
        readFailed = await !database.watch({ db in try NutritionStore.snapshot(db, athleteID: userID) }) { snapshot = $0 }
    }
}

/// Un giorno aperto per correggerlo: lo stato (rispettato o no) e i numeri, che si salvano da soli. I campi partono vuoti;
/// senza numeri il giorno è una semplice conferma.
@MainActor
@Observable
final class MacroDayModel {
    static let debounce: Duration = .milliseconds(300)

    let day: String
    private(set) var status: MacroDayStatus?
    var kcal = ""
    var protein = ""
    var carbs = ""
    var fat = ""
    var fiber = ""
    private(set) var error: String?

    private let athleteID: UUID
    private let store: NutritionStore
    private let onSaved: @MainActor () -> Void
    private let debounce: Duration
    private var pending: Task<Void, Never>?

    init(
        entry: DayEntry, athleteID: UUID, store: NutritionStore, debounce: Duration = MacroDayModel.debounce,
        onSaved: @escaping @MainActor () -> Void = {}
    ) {
        day = entry.day
        status = entry.status
        self.athleteID = athleteID
        self.store = store
        self.debounce = debounce
        self.onSaved = onSaved
        kcal = entry.intake.kcal.map(NumberInput.text) ?? ""
        protein = entry.intake.proteinG.map(NumberInput.text) ?? ""
        carbs = entry.intake.carbsG.map(NumberInput.text) ?? ""
        fat = entry.intake.fatG.map(NumberInput.text) ?? ""
        fiber = entry.intake.fiberG.map(NumberInput.text) ?? ""
    }

    var intake: MacroIntake {
        MacroIntake(
            kcal: NumberInput.decimal(kcal), proteinG: NumberInput.decimal(protein), carbsG: NumberInput.decimal(carbs),
            fatG: NumberInput.decimal(fat), fiberG: NumberInput.decimal(fiber))
    }

    /// «Rispettato» / «Non rispettato»: il giorno esiste da qui, e si salva subito.
    func setStatus(_ new: MacroDayStatus) {
        status = new
        Task { await save() }
    }

    /// I numeri si salvano 300 ms dopo l'ultimo tasto.
    func numbersChanged() {
        guard status != nil else { return }
        pending?.cancel()
        pending = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await self.save()
        }
    }

    func flush() async {
        guard pending != nil else { return }
        pending?.cancel()
        await save()
    }

    /// Torna «non registrato».
    func remove() async {
        pending?.cancel()
        pending = nil
        do {
            try await store.clear(athleteID: athleteID, day: day)
            status = nil
            kcal = ""; protein = ""; carbs = ""; fat = ""; fiber = ""
            error = nil
            onSaved()
        } catch {
            self.error = Self.message(for: error)
        }
    }

    private func save() async {
        pending = nil
        guard let status else { return }
        do {
            try await store.save(DayEdit(athleteID: athleteID, day: day, status: status, intake: intake))
            error = nil
            onSaved()
        } catch {
            self.error = Self.message(for: error)
        }
    }

    static func message(for error: Error) -> String {
        switch error as? NutritionStore.StoreError {
        case .noConsent: "Per registrare i macro serve il tuo consenso."
        case .notEditable: "Questo giorno non si può più modificare."
        case nil: "Non sono riuscito a salvare. Riprova."
        }
    }
}
