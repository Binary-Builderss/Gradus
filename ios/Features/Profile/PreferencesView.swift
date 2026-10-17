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
    @State private var readFailed = false

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
                    readFailed
                        ? "Non riesco a leggere i dati sul telefono. Chiudi e riapri l'app."
                        : consent
                        ? "La sera ti chiedo «Hai rispettato i macro di oggi?» e rispondi con un tocco. Non ti disturbo se hai già registrato la giornata."
                        : "Per attivarlo serve dare il consenso dalla scheda Macro.")
            }
            Section {
                Toggle("Suono a fine recupero", isOn: $timerSound)
                Toggle("Vibrazione a fine recupero", isOn: $timerHaptic)
                Button("Prova suono e vibrazione") {
                    environment.restTimer.preview(sound: timerSound, haptic: timerHaptic)
                }
                .disabled(!timerSound && !timerHaptic)
            } header: {
                Text("Timer di recupero")
            } footer: {
                Text("A fine recupero arriva anche una notifica, pure a schermo bloccato o con l'app chiusa (se le notifiche di Gradus Atleta sono attive nelle Impostazioni di iOS). Il suono si sente sopra la musica, anche con l'iPhone in silenzioso.")
            }
        }
        .navigationTitle("Preferenze")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: reminderOn) { _, _ in Task { await environment.reminders.refresh() } }
        .onChange(of: reminderMinutes) { _, _ in Task { await environment.reminders.refresh() } }
        .task {
            let id = userID
            readFailed = await !environment.database.watch({ db in try NutritionStore.hasConsent(db, userID: id) }) { consent = $0 }
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
