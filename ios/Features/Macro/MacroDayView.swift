import Domain
import SwiftUI

/// Un giorno di macro: «Rispettati» / «Non rispettati» e, se vuoi, i numeri. Si salva da solo, senza «Salva».
struct MacroDayView: View {
    let environment: AppEnvironment
    let userID: UUID
    let entry: DayEntry
    let onClose: () -> Void
    @State private var model: MacroDayModel?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let model { form(model) } else { ProgressView() }
            }
            .navigationTitle(model.map { MacroDayTitle.text($0.day) } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") {
                        Task {
                            await model?.flush()
                            onClose()
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Chiudi tastiera") { focused = false }
                }
            }
        }
        .task {
            model = MacroDayModel(
                entry: entry, athleteID: userID, store: NutritionStore(database: environment.database, remote: environment.remote),
                onSaved: {
                    environment.sync.requestSync()
                    Task { await environment.reminders.refresh() }
                })
        }
        .presentationDetents([.large])
    }

    private func form(_ model: MacroDayModel) -> some View {
        Form {
            if let target = entry.target {
                Section {
                    Text("\(target.kcal) kcal · P \(target.proteinG) g · C \(target.carbsG) g · G \(target.fatG) g")
                        .font(.subheadline.monospacedDigit())
                } header: {
                    Text("Obiettivo")
                }
            }
            Section("Com'è andata?") {
                HStack(spacing: 10) {
                    choice("Rispettati", .respected, model, color: .green)
                    choice("Non rispettati", .notRespected, model, color: .red)
                }
            }
            if model.status != nil {
                Section {
                    field("Calorie", unit: "kcal", text: Bindable(model).kcal, model: model)
                    field("Proteine", unit: "g", text: Bindable(model).protein, model: model)
                    field("Carboidrati", unit: "g", text: Bindable(model).carbs, model: model)
                    field("Grassi", unit: "g", text: Bindable(model).fat, model: model)
                    field("Fibre", unit: "g", text: Bindable(model).fiber, model: model)
                } header: {
                    Text("Quanto hai assunto")
                } footer: {
                    Text("Facoltativo: inseriscili solo se li sai. Puoi modificarli quando vuoi.")
                }
                Section {
                    Button("Togli questo giorno", role: .destructive) {
                        Task {
                            await model.remove()
                        }
                    }
                }
            }
            if let error = model.error {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func choice(_ title: String, _ status: MacroDayStatus, _ model: MacroDayModel, color: Color) -> some View {
        let selected = model.status == status
        return Button {
            model.setStatus(status)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? color : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func field(_ title: String, unit: String, text: Binding<String>, model: MacroDayModel) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", text: text)  // vuoto: nessun valore (nemmeno grigio)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(maxWidth: 110)
                .focused($focused)
                .onChange(of: text.wrappedValue) { _, _ in model.numbersChanged() }
                .accessibilityLabel(title)
            Text(unit).font(.footnote).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
        }
    }
}
