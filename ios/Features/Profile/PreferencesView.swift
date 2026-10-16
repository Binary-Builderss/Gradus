import GRDB
import SwiftUI

/// Preferenze: promemoria serale dei macro e timer di recupero. La scala dello sforzo non si sceglie: la decide il coach.
struct PreferencesView: View {
    let environment: AppEnvironment
    let userID: UUID
    @AppStorage(RestTimerModel.soundKey) private var timerSound = true
    @AppStorage(RestTimerModel.hapticKey) private var timerHaptic = true
    @AppStorage(MacroReminderCenter.enabledKey) private var reminderOn = true
    @AppStorage(MacroReminderCenter.minutesKey) private var reminderMinutes = 22 * 60
    @State private var consent = false

    var body: some View {
        List {
            Section {
                Toggle("Ricordamelo ogni sera", isOn: $reminderOn)
                    .disabled(!consent)
                DatePicker("Orario", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .disabled(!consent || !reminderOn)
            } header: {
                Text("Promemoria dei macro")
            } footer: {
                Text(
                    consent
                        ? "La sera ti chiedo «Hai rispettato i macro di oggi?» e rispondi con un tocco. Non ti disturbo se hai già registrato la giornata."
                        : "Per attivarlo serve dare il consenso dalla scheda Macro.")
            }
            Section {
                Toggle("Suono a fine recupero", isOn: $timerSound)
                Toggle("Vibrazione a fine recupero", isOn: $timerHaptic)
            } header: {
                Text("Timer di recupero")
            } footer: {
                Text("Se l'app è in background il recupero te lo dice una notifica.")
            }
        }
        .navigationTitle("Preferenze")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: reminderOn) { _, _ in Task { await environment.reminders.refresh() } }
        .onChange(of: reminderMinutes) { _, _ in Task { await environment.reminders.refresh() } }
        .task {
            let id = userID
            let observation = ValueObservation.tracking { db in try NutritionStore.hasConsent(db, userID: id) }
            do {
                for try await value in observation.values(in: environment.database.writer) { consent = value }
            } catch {}
        }
    }

    /// L'orario come data di oggi (il selettore lavora su `Date`), salvato come minuti dalla mezzanotte.
    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderMinutes = (parts.hour ?? 22) * 60 + (parts.minute ?? 0)
            })
    }
}
