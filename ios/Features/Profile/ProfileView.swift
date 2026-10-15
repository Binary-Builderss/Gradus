import SwiftUI

/// Profilo: nome, coach collegato, impostazioni, stato della sincronizzazione, esci. Per ora solo la struttura.
struct ProfileView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("profile.account") {
                    Text("profile.notSignedIn")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("tab.profile")
        }
    }
}

#Preview {
    ProfileView()
}
