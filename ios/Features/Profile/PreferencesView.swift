import SwiftUI

/// Preferenze dell'allenamento. La scala dello sforzo non si sceglie: la decide il coach nella prescrizione.
struct PreferencesView: View {
    @AppStorage(RestTimerModel.soundKey) private var timerSound = true
    @AppStorage(RestTimerModel.hapticKey) private var timerHaptic = true

    var body: some View {
        List {
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
    }
}
